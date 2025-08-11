import SwiftUI
@preconcurrency import Combine
import Factory

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
  func promptForReviewIfPossible(metadata: [String: String]?, config: PromptConfig)
  func dismissPrompt(on state: PromptViewState)
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
        currentEligibility = response
        currentFeedbackResponse = nil

        if response.eligible {
          showPrompt()
          print("[PromptManager] User eligible for prompt")
        } else {
          print("[PromptManager] User not eligible for prompt:", response.reason ?? "Unknown reason")
        }
      case .failure(let error):
        feedbackEventPublisher.send(.error)
        print("[PromptManager] Eligibility request failed:", error.errorDescription)
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
        print("[PromptManager] Prompt event logged:", response.status.rawValue)
      case .failure(let error):
        currentEligibility = nil
        currentPromptEvent = nil
        promptMetadata = nil
        print("[PromptManager] Prompt event failed:", error.errorDescription)
      }

    case .feedbackEvent(let result):
      switch result {
      case .success(let response):
        currentFeedbackResponse = response
        print("[PromptManager] Feedback event logged")
        feedbackEventPublisher.send(.rating(data: response))
      case .failure(let error):
        feedbackEventPublisher.send(.error)
        print("[PromptManager] Feedback request failed:", error.errorDescription)
      }

    case .feedbackComment(let result):
      switch result {
      case .success(let response):
        print("[PromptManager] Comment saved successfully")
        if let currentFeedbackResponse {
          feedbackEventPublisher.send(.comment(data: currentFeedbackResponse))
        } else {
          feedbackEventPublisher.send(.error)
        }
      case .failure(let error):
        feedbackEventPublisher.send(.error)
        print("[PromptManager] Comment request failed:", error.errorDescription)
      }
    default:
      break
    }
  }


  func logPromptShown() {
    guard let currentEligibility else {
      print("[Prompt] No eligibility data available.")
      return
    }

    Task { [requestQueue, currentEligibility, apiClient, promptMetadata] in
      let req = apiClient.sendPromptEvent(
        type: .promptShown,
        previousEventId: currentEligibility.eventId,
        feedbackEventId: nil,
        metadata: promptMetadata
      )
      print("About to enqueue on", await requestQueue.debugId, "event:", PromptEventType.promptShown)
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

      print("About to enqueue on", await requestQueue.debugId, "event:", PromptEventType.promptDismissed)
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
      print("About to enqueue on", await requestQueue.debugId, "event:", PromptEventType.promptDismissedAfterRating)
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

      print("About to enqueue on", await requestQueue.debugId, "event:", PromptEventType.redirectedToStore)
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

      print("About to enqueue on", await requestQueue.debugId, "event:", PromptEventType.storeReviewSkipped)
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
      print("About to enqueue on", await requestQueue.debugId, "event:", req.eventType)
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

      print("About to enqueue on", await requestQueue.debugId, "event:", APIEventType.sendFeedbackComment)
      await requestQueue.enqueue(req)
    }
  }

  func promptForReviewIfPossible(metadata: [String: String]? = nil, config: PromptConfig) {
    self.currentPromptConfig = config
    self.promptMetadata = metadata

    Task { [requestQueue, apiClient] in
      let req = apiClient.checkPromptEligibility()

      print("About to enqueue on", await requestQueue.debugId, "event:", APIEventType.checkPromptEligibility)
      await requestQueue.enqueue(req)
    }
  }

  func dismissPrompt(on state: PromptViewState) {
    switch state {
    case .rating, .comment, .thankYou:
      logPromptDismissed()
    case .storeReview(let redirected):
      if redirected {
        logRedirectedToStore()
      } else {
        logStoreReviewSkipped()
      }

      logPromptDismissed()
    }
    presentedPromptVC?.dismiss(animated: true)
    presentedPromptVC = nil
  }

  func showPrompt() {
    guard let presenter = UIViewController.topMost else {
      print("[PromptManager] No presenter available")
      return
    }

    let swiftUIView = PromptView(config: currentPromptConfig)
    let hostingVC = PromptViewController(rootView: swiftUIView)
    presenter.present(hostingVC, animated: true)
    presentedPromptVC = hostingVC
  }

  deinit {
    listenerTask?.cancel() // optional, just to be tidy
  }
}
