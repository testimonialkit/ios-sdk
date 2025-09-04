import SwiftUI
@preconcurrency import Combine
import Factory

#if canImport(UIKit)
import UIKit
typealias PlatformViewController = UIViewController
#elseif canImport(AppKit)
import AppKit
typealias PlatformViewController = NSViewController
#endif

/// Represents the lifecycle of the in-app feedback prompt.
/// The state machine is advanced by network results (via the RequestQueue stream)
/// and by user interactions with the presented UI.
enum PromptState {
  /// Idle state; no prompt activity is in progress. (Typo preserved intentionally: `iddle`)
  case iddle
  /// A background check is running to determine whether the user is eligible to see a prompt.
  case checkingForEligibility
  /// The user is eligible; the prompt can be shown next.
  case eligible
  /// The prompt UI is being presented.
  case showing
  /// The prompt UI is visible on screen.
  case shown
  /// The prompt UI is being dismissed.
  case dismissing
}

/// Public API for coordinating when to show the feedback prompt and how to log
/// related analytics events. Conforming types must be `Sendable` because the
/// implementation is actor-isolated but observed from other contexts.
protocol PromptManagerProtocol: AnyObject, Sendable {
  /// Emits high-level feedback events (rating, comment, error) to observers on the main thread.
  nonisolated var feedbackEventPublisher: PassthroughSubject<FeedbackEventType, Never> { get }

  /// Logs that the prompt became visible to the user.
  func logPromptShown() async
  /// Logs that the prompt was dismissed without a recorded rating/comment.
  func logPromptDismissed() async
  /// Logs that the prompt was dismissed after a rating/comment had been recorded.
  func logPromptDismissedWithResult() async
  /// Logs that the user was redirected to the App Store from the prompt.
  func logRedirectedToStore() async
  /// Logs that the user chose to skip the App Store review flow.
  func logStoreReviewSkipped() async
  /// Logs the user's feedback comment (no rating anymore).
  /// - Parameter comment: Free-form text feedback from the user.
  func logUserFeedback(comment: String?) async
  /// Asynchronously checks eligibility and, if allowed, proceeds to show the prompt.
  /// - Parameters:
  ///   - metadata: Arbitrary key–value pairs attached to all logged events in this session.
  ///   - config: Runtime configuration for how the prompt behaves and looks.
  ///   - completion: Optional callback invoked with the final `PromptResult` after dismissal.
  func promptForReviewIfPossible(
    metadata: [String: String]?,
    config: PromptConfig,
    completion: (@Sendable (PromptResult) -> Void)?
  ) async
  /// Dismisses the prompt UI and triggers the appropriate logging for the given UI state.
  /// - Parameter state: The destination UI state driving post-dismissal logging & completion.
  func dismissPrompt(on state: PromptViewState) async
  /// Internal: Handles side effects that occur once the prompt has been dismissed.
  /// - Parameter state: The dismissal outcome to evaluate.
  func handlePromptDismissAction(on state: PromptViewState) async
  /// Presents the prompt UI on the top-most view controller (main thread only).
  func showPrompt(of type: PromptType) async
}

/// Actor-backed implementation of `PromptManagerProtocol`.
///
/// Responsibilities:
/// 1. Subscribes to the `RequestQueue` stream and decodes server responses.
/// 2. Drives the prompt state machine and presents/dismisses the UI on the main actor.
/// 3. Logs prompt and feedback events through `APIClientProtocol` with optional metadata.
actor PromptManager: PromptManagerProtocol {
  /// Queue responsible for scheduling and retrying API requests.
  private let requestQueue: RequestQueue
  /// Client used to build `QueuedRequest` payloads for the backend.
  private let apiClient: APIClientProtocol
  /// Global SDK configuration injected at initialization.
  private let testimonialKitConfig: TestimonialKitConfig
  /// Key–value pairs attached to all prompt/feedback logs for the current session.
  private var promptMetadata: [String: String]?
  /// Last successful eligibility response; cleared after the flow completes.
  private var currentEligibility: PromptEligibilityResponse?
  /// The most recent prompt event returned by the backend.
  private var currentPromptEvent: PromptEventLogResponse?
  /// The most recent feedback event (comment) returned by the backend.
  private var currentFeedbackResponse: FeedbackLogResponse?
  /// Indicates that a feedback event has been enqueued/acknowledged during this session.
  private var feedbackEventRegistered: Bool = false
  /// Current position in the prompt lifecycle state machine.
  private var promptState: PromptState = .iddle {
    didSet {
      Logger.shared.verbose("Prompt state changed: \(promptState)")
    }
  }
  /// Completion callbacks to invoke once the prompt flow finishes. Indexed by UUID.
  private var completionHandlers: [UUID: ((PromptResult) -> Void)] = [:]
  /// Weak reference to the currently presented prompt view controller (main-actor only).
  private nonisolated(unsafe) var _presentedPromptVC: PlatformViewController?
  /// The runtime configuration used when presenting the current prompt.
  private var currentPromptConfig: PromptConfig = PromptConfig()

  /// Public publisher that emits feedback-related events to the UI layer.
  /// Guaranteed to be sent on the main thread.
  nonisolated let feedbackEventPublisher = PassthroughSubject<FeedbackEventType, Never>()
  /// Task that continuously listens to `RequestQueue` results and applies side effects.
  private var listenerTask: Task<Void, Never>?

  /// Creates a new `PromptManager`.
  /// - Parameters:
  ///   - config: SDK-wide configuration.
  ///   - requestQueue: Queue used for enqueueing API requests.
  ///   - apiClient: Factory for API request payloads.
  init(config: TestimonialKitConfig, requestQueue: RequestQueue, apiClient: APIClientProtocol) {
    self.testimonialKitConfig = config
    self.requestQueue = requestQueue
    self.apiClient = apiClient

    // Capture weak self to avoid retain cycles
    Task { [weak self] in
      await self?.startListening()
    }
  }

  /// Starts consuming events from `requestQueue` and routing them through the local state machine.
  func startListening() {
    listenerTask = Task { [weak self] in
      guard let self = self else { return }
      let stream = await self.requestQueue.subscribe()
      for await event in stream {
        let decoded: DecodedQueueEvent = await withCheckedContinuation { cont in
          DispatchQueue.global(qos: .utility).async {
            cont.resume(returning: self.decode(event))
          }
        }
        await self.apply(decoded)
      }
    }
  }

  /// Decodes raw queue results into typed domain events that can be safely handled by this actor.
  /// - Parameter event: The raw result from `RequestQueue`.
  /// - Returns: A `DecodedQueueEvent` variant representing the payload or failure.
  private nonisolated func decode(_ event: QueuedRequestResult) -> DecodedQueueEvent {
    switch event.eventType {
    case .checkPromptEligibility:
      switch event.result {
      case .success(let data):
        let decoded = QueueResult { try JSONDecoder().decode(PromptEligibilityResponse.self, from: data) }
        return .checkEligibility(decoded)
      case .failure(let error):
        return .checkEligibility(.failure(error))
      }

    case .sendPromptEvent:
      switch event.result {
      case .success(let data):
        let decoded = QueueResult { try JSONDecoder().decode(PromptEventLogResponse.self, from: data) }
        return .promptEvent(decoded)
      case .failure(let error):
        return .promptEvent(.failure(error))
      }

    case .sendFeedbackEvent:
      switch event.result {
      case .success(let data):
        let decoded = QueueResult { try JSONDecoder().decode(FeedbackLogResponse.self, from: data) }
        return .feedbackEvent(decoded)
      case .failure(let error):
        return .feedbackEvent(.failure(error))
      }

    case .sendFeedbackComment:
      switch event.result {
      case .success(let data):
        let decoded = QueueResult { try JSONDecoder().decode(FeedbackLogResponse.self, from: data) }
        return .feedbackComment(decoded)
      case .failure(let error):
        return .feedbackComment(.failure(error))
      }
    default:
      return .unhadnledEvent(event.eventType.rawValue)
    }
  }

  /// Applies a decoded event to the state machine, possibly presenting or dismissing the prompt
  /// and sending notifications to observers via `feedbackEventPublisher`.
  /// - Parameter event: The decoded event to handle.
  private func apply(_ event: DecodedQueueEvent) {
    switch event {
    case .checkEligibility(let result):
      switch result {
      case .success(let response):
        if response.eligible, let promptType = response.type {
          currentEligibility = response
          currentFeedbackResponse = nil
          promptState = .eligible

          // Need to run on main thread when showing UI
          Task { @MainActor in
            await self.showPrompt(of: promptType)
          }
          Logger.shared.debug("User eligible for \(promptType.rawValue) prompt")
        } else {
          promptState = .iddle
          Logger.shared.debug("User not eligible for prompt: \(response.reason ?? "Unknown reason")")
        }
      case .failure(let error):
        promptState = .iddle
        // We need to use MainActor to send to the publisher from a background context
        Task { @MainActor in
          self.feedbackEventPublisher.send(.error)
        }
        Logger.shared.debug("Eligibility request failed: \(error.errorDescription ?? "")")
      }

    case .promptEvent(let result):
      switch result {
      case .success(let response):
        currentPromptEvent = response
        if response.status == .promptDismissed || response.status == .promptDismissedWithResult {
          currentEligibility = nil
          currentPromptEvent = nil
          promptMetadata = nil
        }
        Logger.shared.debug("Prompt event logged: \(response.status.rawValue)")
      case .failure(let error):
        currentEligibility = nil
        currentPromptEvent = nil
        promptMetadata = nil
        Logger.shared.debug("Prompt event failed: \(error.errorDescription ?? "")")
      }

    case .feedbackEvent(let result):
      switch result {
      case .success(let response):
        currentFeedbackResponse = response
        // Publishing needs to be on the main thread
        Task { @MainActor in
          self.feedbackEventPublisher.send(.comment(data: response))
        }
        Logger.shared.debug("Feedback event logged")
      case .failure(let error):
        Task { @MainActor in
          self.feedbackEventPublisher.send(.error)
        }
        Logger.shared.debug("Feedback request failed: \(error.errorDescription ?? "")")
      }

    case .feedbackComment(let result):
      switch result {
      case .success(let response):
        currentFeedbackResponse = response
        Task { @MainActor in
          self.feedbackEventPublisher.send(.comment(data: response))
        }
        Logger.shared.debug("Comment saved successfully")
      case .failure(let error):
        Task { @MainActor in
          self.feedbackEventPublisher.send(.error)
        }
        Logger.shared.debug("Comment request failed: \(error.errorDescription ?? "")")
      }
    default:
      break
    }
  }

  /// Enqueues a `promptShown` event for the current eligibility session.
  func logPromptShown() async {
    guard let currentEligibility else {
      Logger.shared.debug("No eligibility data available.")
      return
    }

    let req = apiClient.sendPromptEvent(
      type: .promptShown,
      previousEventId: currentEligibility.eventId,
      feedbackEventId: nil,
      metadata: promptMetadata
    )

    let logMessage = "About to enqueue on \(requestQueue.debugId) event: \(PromptEventType.promptShown)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)
  }

  /// Enqueues a `promptDismissed` event unless a feedback event was already registered.
  func logPromptDismissed() async {
    guard let currentPromptEvent else { return }

    if currentFeedbackResponse != nil || feedbackEventRegistered {
      await logPromptDismissedWithResult()
      return
    }

    let req = apiClient.sendPromptEvent(
      type: .promptDismissed,
      previousEventId: currentPromptEvent.eventId,
      feedbackEventId: nil,
      metadata: promptMetadata
    )

    let logMessage = "About to enqueue on \(requestQueue.debugId) event: \(PromptEventType.promptDismissed)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)
  }

  /// Enqueues a `promptDismissedWithResult` event tying the dismissal to the feedback event.
  func logPromptDismissedWithResult() async {
    guard let currentFeedbackResponse, let currentPromptEvent, feedbackEventRegistered else { return }

    let req = apiClient.sendPromptEvent(
      type: .promptDismissedWithResult,
      previousEventId: currentPromptEvent.eventId,
      feedbackEventId: currentFeedbackResponse.eventId,
      metadata: promptMetadata
    )

    let logMessage = "About to enqueue on \(requestQueue.debugId) event: \(PromptEventType.promptDismissedWithResult)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)

    feedbackEventRegistered = false
  }

  /// Enqueues a `redirectedToStore` event for analytics attribution.
  func logRedirectedToStore() async {
    guard let currentPromptEvent else { return }

    let req = apiClient.sendPromptEvent(
      type: .redirectedToStore,
      previousEventId: currentPromptEvent.eventId,
      feedbackEventId: nil,
      metadata: promptMetadata
    )

    let logMessage = "About to enqueue on \(requestQueue.debugId) event: \(PromptEventType.redirectedToStore)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)
  }

  /// Enqueues a `storeReviewSkipped` event when the user declines the App Store flow.
  func logStoreReviewSkipped() async {
    guard let currentPromptEvent else { return }

    let req = apiClient.sendPromptEvent(
      type: .storeReviewSkipped,
      previousEventId: currentPromptEvent.eventId,
      feedbackEventId: nil,
      metadata: promptMetadata
    )

    let logMessage = "About to enqueue on \(requestQueue.debugId) event: \(PromptEventType.storeReviewSkipped)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)
  }

  /// Enqueues a feedback event for the given comment (no rating anymore).
  /// - Parameter comment: Optional free-form text feedback from the user.
  func logUserFeedback(comment: String? = nil) async {
    guard let currentPromptEvent else { return }

    let req = apiClient.sendFeedbackEvent(
      promptEventId: currentPromptEvent.eventId,
      comment: comment,
      metadata: promptMetadata
    )

    let logMessage = "About to enqueue on \(requestQueue.debugId) event: \(req.eventType)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)

    feedbackEventRegistered = true
  }

  /// Entry point for the prompt flow. Checks eligibility via the API, stores metadata and
  /// configuration, and upon success proceeds towards presenting the prompt UI.
  /// - Parameters:
  ///   - metadata: Arbitrary key–value pairs attached to all subsequent logs.
  ///   - config: Runtime configuration for the prompt.
  ///   - completion: Optional callback invoked with the final `PromptResult`.
  func promptForReviewIfPossible(
    metadata: [String: String]? = nil,
    config: PromptConfig,
    completion: (@Sendable (PromptResult) -> Void)? = nil
  ) async {
    if promptState != .iddle {
      Logger.shared.warning("Invalid state to call promptForReviewIfPossible: \(promptState)")
      return
    }

    self.currentPromptConfig = config
    self.promptMetadata = metadata
    let uuid = UUID()
    self.completionHandlers[uuid] = completion

    promptState = .checkingForEligibility
    let req = apiClient.checkPromptEligibility()

    let logMessage = "About to enqueue on \(requestQueue.debugId) event: \(APIEventType.checkPromptEligibility)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)
  }

  /// Dismisses the current prompt UI on the main actor and then handles post-dismissal effects.
  /// - Parameter state: The outcome state that determines which events to log.
  func dismissPrompt(on state: PromptViewState) async {
    promptState = .dismissing

    // UI operations must run on main thread
    await MainActor.run {
      #if canImport(UIKit)
      self._presentedPromptVC?.dismiss(animated: true) {
        Task { await self.handlePromptDismissAction(on: state) }
      }
      #elseif canImport(AppKit)
      self._presentedPromptVC?.dismiss(nil)
      Task { await self.handlePromptDismissAction(on: state) }
      #endif
      self._presentedPromptVC = nil
    }
  }

  /// Presents the prompt modally from the top-most view controller on the current platform.
  /// On iOS it uses a sheet; on macOS it presents as a sheet from the top-most NSViewController.
  func showPrompt(of type: PromptType) async {
    guard promptState == .eligible else {
      Logger.shared.warning("Prompt state is not eligible")
      return
    }

    #if canImport(UIKit)
    guard let presenter = await UIViewController.topMost else {
      Logger.shared.warning("No presenter available")
      return
    }
    #elseif canImport(AppKit)
    guard let presenter = await NSViewController.topMost else {
      Logger.shared.warning("No presenter available (macOS)")
      return
    }
    #endif

    promptState = .showing
    await MainActor.run { [currentPromptConfig] in
      let swiftUIView = PromptView(config: currentPromptConfig, type: type)
      let hostingVC = PromptViewController(rootView: swiftUIView)

      #if canImport(UIKit)
      presenter.present(hostingVC, animated: true) {
        Task { await self.promptWasShown() }
      }
      #elseif canImport(AppKit)
      presenter.presentAsSheet(hostingVC)
      Task { await self.promptWasShown() }
      #endif

      _presentedPromptVC = hostingVC
    }
  }

  /// Marks the prompt as shown and emits the corresponding analytics event.
  private func promptWasShown() async {
    promptState = .shown
    await logPromptShown()
  }

  /// Based on the final `PromptViewState`, logs the correct event (redirected/skipped) and then
  /// triggers completion and resets internal state.
  /// - Parameter state: The resulting view state at dismissal time.
  func handlePromptDismissAction(on state: PromptViewState) async {
    switch state {
    case .storeReview(let redirected, _):
      if redirected {
        await logRedirectedToStore()
      } else {
        await logStoreReviewSkipped()
      }
    default:
      Logger.shared.debug("Ignored PromptViewState: \(state)")
    }

    await logPromptDismissed()
    await triggerCompletionHandlers(on: state)
    clearCurrentState()
  }

  /// Invokes and clears all pending completion handlers with a derived `PromptResult`.
  /// - Parameter state: The view state used to map to a `PromptResult` value.
  private func triggerCompletionHandlers(on state: PromptViewState) async {
    // Execute completion handlers on main thread
    switch state {
    case .comment, .thankYou:
      // For feedback prompts
      if let currentFeedbackResponse {
        completionHandlers.forEach { $1(.completed) }
      } else {
        completionHandlers.forEach { $1(.cancelled) }
      }
    case .storeReview(let redirected, _):
      // For review prompts - just redirect to store and close
      if redirected {
        completionHandlers.forEach { $1(.redirectedToStore) }
      } else {
        completionHandlers.forEach { $1(.storeReviewSkipped) }
      }
    default:
      completionHandlers.forEach { $1(.cancelled) }
    }

    completionHandlers.removeAll()
  }

  /// Resets transient state accumulated during a prompt session so the flow can start fresh.
  private func clearCurrentState() {
    promptState = .iddle
    currentEligibility = nil
    currentPromptEvent = nil
    currentFeedbackResponse = nil
  }

  /// Cancels the listener task when the manager is deallocated.
  deinit {
    listenerTask?.cancel()
  }
}
