import SwiftUI
@preconcurrency import Combine
import Factory

enum PromptState {
  case iddle
  case checkingForEligibility
  case eligible
  case showing
  case shown
  case dismissing
}

// Protocol updated to be Sendable
protocol PromptManagerProtocol: AnyObject, Sendable {
  // Publisher will need to be accessed from outside the actor
  nonisolated var feedbackEventPublisher: PassthroughSubject<FeedbackEventType, Never> { get }

  // All methods now return Task or Void since they're asynchronous across actor boundaries
  func logPromptShown() async
  func logPromptDismissed() async
  func logPromptDismissedAfterRating() async
  func logRedirectedToStore() async
  func logStoreReviewSkipped() async
  func logUserFeedback(rating: Int, comment: String?) async
  func logUserComment(comment: String?) async
  func promptForReviewIfPossible(
    metadata: [String: String]?,
    config: PromptConfig,
    completion: (@Sendable (PromptResult) -> Void)?
  ) async
  func dismissPrompt(on state: PromptViewState) async
  func handlePromptDismissAction(on state: PromptViewState) async
  func showPrompt() async
}

// Actor implementation of PromptManager
actor PromptManager: PromptManagerProtocol {
  private let requestQueue: RequestQueue
  private let apiClient: APIClientProtocol
  private let testimonialKitConfig: TestimonialKitConfig
  private var promptMetadata: [String: String]?
  private var currentEligibility: PromptEligibilityResponse?
  private var currentPromptEvent: PromptEventLogResponse?
  private var currentFeedbackResponse: FeedbackLogResponse?
  private var feedbackEventRegistered: Bool = false
  private var promptState: PromptState = .iddle {
    didSet {
      Logger.shared.verbose("Prompt state changed: \(promptState)")
    }
  }
  private var completionHandlers: [UUID: ((PromptResult) -> Void)] = [:]
  // This needs to be accessed from the main thread, so we use nonisolated
  private nonisolated(unsafe) var _presentedPromptVC: UIViewController?
  private var currentPromptConfig: PromptConfig = PromptConfig()

  // Publishers need to be nonisolated so they can be observed from outside the actor
  nonisolated let feedbackEventPublisher = PassthroughSubject<FeedbackEventType, Never>()
  private var listenerTask: Task<Void, Never>?

  init(config: TestimonialKitConfig, requestQueue: RequestQueue, apiClient: APIClientProtocol) {
    self.testimonialKitConfig = config
    self.requestQueue = requestQueue
    self.apiClient = apiClient

    // Capture weak self to avoid retain cycles
    Task { [weak self] in
      await self?.startListening()
    }
  }

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

  // Decode can be nonisolated since it doesn't access actor state
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

  private func apply(_ event: DecodedQueueEvent) {
    switch event {
    case .checkEligibility(let result):
      switch result {
      case .success(let response):
        if response.eligible {
          currentEligibility = response
          currentFeedbackResponse = nil
          promptState = .eligible

          // Need to run on main thread when showing UI
          Task { @MainActor in
            await self.showPrompt()
          }
          Logger.shared.debug("User eligible for prompt")
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
        if response.status == .promptDismissed || response.status == .promptDismissedAfterRating {
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
          self.feedbackEventPublisher.send(.rating(data: response))
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

    let logMessage = "About to enqueue on \(await requestQueue.debugId) event: \(PromptEventType.promptShown)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)
  }

  func logPromptDismissed() async {
    guard let currentPromptEvent else { return }

    if currentFeedbackResponse != nil || feedbackEventRegistered {
      await logPromptDismissedAfterRating()
      return
    }

    let req = apiClient.sendPromptEvent(
      type: .promptDismissed,
      previousEventId: currentPromptEvent.eventId,
      feedbackEventId: nil,
      metadata: promptMetadata
    )

    let logMessage = "About to enqueue on \(await requestQueue.debugId) event: \(PromptEventType.promptDismissed)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)
  }

  func logPromptDismissedAfterRating() async {
    guard let currentFeedbackResponse, let currentPromptEvent, feedbackEventRegistered else { return }

    let req = apiClient.sendPromptEvent(
      type: .promptDismissedAfterRating,
      previousEventId: currentPromptEvent.eventId,
      feedbackEventId: currentFeedbackResponse.eventId,
      metadata: promptMetadata
    )

    let logMessage = "About to enqueue on \(await requestQueue.debugId) event: \(PromptEventType.promptDismissedAfterRating)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)

    feedbackEventRegistered = false
  }

  func logRedirectedToStore() async {
    guard let currentPromptEvent else { return }

    let req = apiClient.sendPromptEvent(
      type: .redirectedToStore,
      previousEventId: currentPromptEvent.eventId,
      feedbackEventId: nil,
      metadata: promptMetadata
    )

    let logMessage = "About to enqueue on \(await requestQueue.debugId) event: \(PromptEventType.redirectedToStore)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)
  }

  func logStoreReviewSkipped() async {
    guard let currentPromptEvent else { return }

    let req = apiClient.sendPromptEvent(
      type: .storeReviewSkipped,
      previousEventId: currentPromptEvent.eventId,
      feedbackEventId: nil,
      metadata: promptMetadata
    )

    let logMessage = "About to enqueue on \(await requestQueue.debugId) event: \(PromptEventType.storeReviewSkipped)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)
  }

  func logUserFeedback(rating: Int, comment: String? = nil) async {
    guard let currentPromptEvent else { return }

    let req = apiClient.sendFeedbackEvent(
      promptEventId: currentPromptEvent.eventId,
      rating: rating,
      comment: comment,
      metadata: promptMetadata
    )

    let logMessage = "About to enqueue on \(await requestQueue.debugId) event: \(req.eventType)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)

    feedbackEventRegistered = true
  }

  func logUserComment(comment: String?) async {
    guard let currentFeedbackResponse else { return }

    let req = apiClient.sendFeedbackComment(
      comment: comment,
      feedbackEventId: currentFeedbackResponse.eventId
    )

    let logMessage = "About to enqueue on \(await requestQueue.debugId) event: \(APIEventType.sendFeedbackComment)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)
  }

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

    let logMessage = "About to enqueue on \(await requestQueue.debugId) event: \(APIEventType.checkPromptEligibility)"
    Logger.shared.verbose(logMessage)
    await requestQueue.enqueue(req)
  }

  func dismissPrompt(on state: PromptViewState) async {
    promptState = .dismissing

    // UI operations must run on main thread
    await MainActor.run {
      self._presentedPromptVC?.dismiss(animated: true) {
        // Hop back to actor for state handling
        Task {
          await self.handlePromptDismissAction(on: state)
        }
      }
      self._presentedPromptVC = nil
    }
  }

  // This must be called on the main thread
  func showPrompt() async {
    guard await promptState == .eligible else {
      Logger.shared.warning("Prompt state is not eligible")
      return
    }

    guard let presenter = await UIViewController.topMost else {
      Logger.shared.warning("No presenter available")
      return
    }

    promptState = .showing
    await MainActor.run { [currentPromptConfig] in
      let swiftUIView = PromptView(config: currentPromptConfig)
      let hostingVC = PromptViewController(rootView: swiftUIView)
      presenter.present(hostingVC, animated: true) {
        // We need to hop back to the actor context
        Task {
          await self.promptWasShown()
        }
      }
      _presentedPromptVC = hostingVC
    }
  }

  private func promptWasShown() async {
    promptState = .shown
    await logPromptShown()
  }

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

  private func triggerCompletionHandlers(on state: PromptViewState) async {
    // Execute completion handlers on main thread
    switch state {
    case .rating, .comment, .thankYou:
      if let currentFeedbackResponse {
        if currentFeedbackResponse.hasComment {
          completionHandlers.forEach { $1(.completed) }
        } else {
          completionHandlers.forEach { $1(.completedWithoutComment) }
        }
      } else {
        completionHandlers.forEach { $1(.cancelled) }
      }
    case .storeReview(let redirected, _):
      if redirected {
        completionHandlers.forEach { $1(.redirectedToStore) }
      } else {
        completionHandlers.forEach { $1(.storeReviewSkipped) }
      }
    }

    completionHandlers.removeAll()
  }

  private func clearCurrentState() {
    promptState = .iddle
    currentEligibility = nil
    currentPromptEvent = nil
    currentFeedbackResponse = nil
  }

  deinit {
    listenerTask?.cancel()
  }
}
