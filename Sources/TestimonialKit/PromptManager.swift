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

@MainActor
protocol PromptManagerProtocol: AnyObject {
  var feedbackEventPublisher: PassthroughSubject<FeedbackEventType, Never> { get }
  func logPromptShown()
  func logPromptDismissed()
  func logPromptDismissedAfterRating()
  func logRedirectedToStore()
  func logStoreReviewSkipped()
  func logUserFeedback(rating: Int, comment: String?)
  func logUserComment(comment: String?)
  func promptForReviewIfPossible(
    metadata: [String: String]?,
    config: PromptConfig,
    completion: ((PromptResult) -> Void)?
  )
  func dismissPrompt(on state: PromptViewState)
  func handlePromptDismissAction(on state: PromptViewState)
  func showPrompt()
}

@MainActor
final class PromptManager: PromptManagerProtocol {
  @Injected(\.requestQueue) var requestQueue
  @Injected(\.apiClient) var apiClient
  private let testimonialKitConfig: TestimonialKitConfig
  private var promptMetadata: [String: String]?
  private var cancellables = Set<AnyCancellable>()
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
  private weak var presentedPromptVC: UIViewController?
  private var currentPromptConfig: PromptConfig = PromptConfig()
  let feedbackEventPublisher = PassthroughSubject<FeedbackEventType, Never>()
  private var listenerTask: Task<Void, Never>?

  init(config: TestimonialKitConfig) {
    self.testimonialKitConfig = config

    listenerTask = Task { [weak self] in
      guard let self else { return }
      let stream = await self.requestQueue.subscribe()   // await actor to fetch the single stream
      for await event in stream {
        // decode on background if you want
        let decoded: DecodedQueueEvent = await withCheckedContinuation { cont in
          DispatchQueue.global(qos: .utility).async {
            cont.resume(returning: self.decode(event))
          }
        }
        await self.apply(decoded)  // hop back to @MainActor (self is @MainActor)
      }
    }
  }

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
          showPrompt()
          Logger.shared.debug("User eligible for prompt")
        } else {
          promptState = .iddle
          Logger.shared.debug("User not eligible for prompt: \(response.reason ?? "Unknown reason")")
        }
      case .failure(let error):
        promptState = .iddle
        feedbackEventPublisher.send(.error)
        Logger.shared.debug("Eligibility request failed: \(error.errorDescription)")
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
        Logger.shared.debug("Prompt event failed: \(error.errorDescription)")
      }

    case .feedbackEvent(let result):
      switch result {
      case .success(let response):
        currentFeedbackResponse = response
        feedbackEventPublisher.send(.rating(data: response))
        Logger.shared.debug("Feedback event logged")
      case .failure(let error):
        feedbackEventPublisher.send(.error)
        Logger.shared.debug("Feedback request failed: \(error.errorDescription)")
      }

    case .feedbackComment(let result):
      switch result {
      case .success(let response):
        currentFeedbackResponse = response
        feedbackEventPublisher.send(.comment(data: response))
        Logger.shared.debug("Comment saved successfully")
      case .failure(let error):
        feedbackEventPublisher.send(.error)
        Logger.shared.debug("Comment request failed: \(error.errorDescription)")
      }
    default:
      break
    }
  }


  func logPromptShown() {
    guard let currentEligibility else {
      Logger.shared.debug("No eligibility data available.")
      return
    }

    Task { [requestQueue, currentEligibility, apiClient, promptMetadata] in
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
  }

  func logPromptDismissed() {
    guard let currentPromptEvent else { return }

    if currentFeedbackResponse != nil || feedbackEventRegistered  {
      logPromptDismissedAfterRating()
      return
    }

    Task { [requestQueue, currentPromptEvent, apiClient, promptMetadata] in
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
  }

  func logPromptDismissedAfterRating() {
    guard let currentFeedbackResponse, let currentPromptEvent, feedbackEventRegistered else { return }

    Task { [requestQueue, currentFeedbackResponse, currentPromptEvent, apiClient, promptMetadata] in
      let req = apiClient.sendPromptEvent(
        type: .promptDismissedAfterRating,
        previousEventId: currentPromptEvent.eventId,
        feedbackEventId: currentFeedbackResponse.eventId,
        metadata: promptMetadata
      )

      let logMessage = "About to enqueue on \(await requestQueue.debugId) event: \(PromptEventType.promptDismissedAfterRating)"
      Logger.shared.verbose(logMessage)
      await requestQueue.enqueue(req)
    }

    feedbackEventRegistered = false
  }

  func logRedirectedToStore() {
    guard let currentPromptEvent else { return }

    Task { [requestQueue, currentPromptEvent, apiClient, promptMetadata] in
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
  }

  func logStoreReviewSkipped() {
    guard let currentPromptEvent else { return }

    Task { [requestQueue, currentPromptEvent, apiClient, promptMetadata] in
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
  }

  func logUserFeedback(rating: Int, comment: String? = nil) {
    guard let currentPromptEvent else { return }

    Task { [requestQueue, currentPromptEvent, apiClient, promptMetadata] in
      let req = apiClient.sendFeedbackEvent(
        promptEventId: currentPromptEvent.eventId,
        rating: rating,
        comment: comment,
        metadata: promptMetadata
      )

      let logMessage = "About to enqueue on \(await requestQueue.debugId) event: \(req.eventType)"
      Logger.shared.verbose(logMessage)
      await requestQueue.enqueue(req)
    }

    feedbackEventRegistered = true
  }

  func logUserComment(comment: String?) {
    guard let currentFeedbackResponse else { return }

    Task { [requestQueue, currentFeedbackResponse, apiClient] in
      let req = apiClient.sendFeedbackComment(
        comment: comment,
        feedbackEventId: currentFeedbackResponse.eventId
      )

      let logMessage = "About to enqueue on \(await requestQueue.debugId) event: \(APIEventType.sendFeedbackComment)"
      Logger.shared.verbose(logMessage)
      await requestQueue.enqueue(req)
    }
  }

  func promptForReviewIfPossible(
    metadata: [String: String]? = nil,
    config: PromptConfig,
    completion: ((PromptResult) -> Void)? = nil
  ) {
    if promptState != .iddle {
      Logger.shared.warning("Invalid state to call promptForReviewIfPossible: \(promptState)")
      return
    }

    self.currentPromptConfig = config
    self.promptMetadata = metadata
    self.completionHandlers[UUID()] = completion

    promptState = .checkingForEligibility
    Task { [requestQueue, apiClient] in
      let req = apiClient.checkPromptEligibility()

      let logMessage = "About to enqueue on \(await requestQueue.debugId) event: \(APIEventType.checkPromptEligibility)"
      Logger.shared.verbose(logMessage)
      await requestQueue.enqueue(req)
    }
  }

  func dismissPrompt(on state: PromptViewState) {
    promptState = .dismissing
    presentedPromptVC?.dismiss(animated: true) { [weak self] in
      guard let self else { return }
      self.handlePromptDismissAction(on: state)
    }
    presentedPromptVC = nil
  }

  func showPrompt() {
    guard promptState == .eligible else {
      Logger.shared.warning("Prompt state is not eligible")
      return
    }

    guard let presenter = UIViewController.topMost else {
      Logger.shared.warning("No presenter available")
      return
    }

    promptState = .showing
    let swiftUIView = PromptView(config: currentPromptConfig)
    let hostingVC = PromptViewController(rootView: swiftUIView)
    presenter.present(hostingVC, animated: true) { [weak self] in
      guard let self else { return }
      self.promptState = .shown
      self.logPromptShown()
    }
    presentedPromptVC = hostingVC
  }

  func handlePromptDismissAction(on state: PromptViewState) {
    switch state {
    case .storeReview(let redirected, _):
      if redirected {
        logRedirectedToStore()
      } else {
        logStoreReviewSkipped()
      }
    default:
      Logger.shared.debug("Ignored PromptViewState: \(state)")
    }

    logPromptDismissed()
    triggerCompletionHandlers(on: state)
    clearCurrentState()
  }

  private func triggerCompletionHandlers(on state: PromptViewState) {
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

    completionHandlers = [:]
  }

  private func clearCurrentState() {
    promptState = .iddle
    currentEligibility = nil
    currentPromptEvent = nil
    currentFeedbackResponse = nil
  }

  deinit {
    listenerTask?.cancel() // optional, just to be tidy
  }
}
