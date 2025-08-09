import SwiftUI
import Combine
import Factory

@MainActor
protocol PromptManagerProtocol: AnyObject {
  var feedbackEventPublisher: PassthroughSubject<FeedbackEvent, Never> { get }
  func logPromptShown()
  func logPromptDismissed()
  func logPromptDismissedAfterRating()
  func logRedirectedToStore()
  func logStoreReviewSkipped()
  func logUserFeedback(rating: Int, comment: String?)
  func logUserComment(comment: String?)
  func promptForReviewIfPossible(metadata: [String: String]?, config: PromptConfig)
  func dismissPrompt()
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
  let feedbackEventPublisher = PassthroughSubject<FeedbackEvent, Never>()

  init(config: TestimonialKitConfig) {
    self.testimonialKitConfig = config
    requestQueue.eventPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] result in
        self?.handle(result)
      }
      .store(in: &cancellables)
  }

  func logPromptShown() {
    guard let currentEligibility else {
      print("[Prompt] No eligibility data available.")
      return
    }

    requestQueue.enqueue(
      apiClient.sendPromptEvent(
        type: .promptShown,
        previousEventId: currentEligibility.eventId,
        feedbackEventId: nil,
        metadata: promptMetadata
      )
    )
  }

  func logPromptDismissed() {
    guard let currentPromptEvent else { return }

    if currentFeedbackResponse != nil || feedbackEventRegistered  {
      logPromptDismissedAfterRating()
      return
    }

    requestQueue.enqueue(
      apiClient.sendPromptEvent(
        type: .promptDismissed,
        previousEventId: currentPromptEvent.eventId,
        feedbackEventId: nil,
        metadata: promptMetadata
      )
    )
  }

  func logPromptDismissedAfterRating() {
    guard let currentFeedbackResponse, let currentPromptEvent, feedbackEventRegistered else { return }

    requestQueue.enqueue(
      apiClient.sendPromptEvent(
        type: .promptDismissedAfterRating,
        previousEventId: currentPromptEvent.eventId,
        feedbackEventId: currentFeedbackResponse.eventId,
        metadata: promptMetadata
      )
    )

    feedbackEventRegistered = false
  }

  func logRedirectedToStore() {
    guard let currentPromptEvent else { return }

    requestQueue.enqueue(
      apiClient.sendPromptEvent(
        type: .redirectedToStore,
        previousEventId: currentPromptEvent.eventId,
        feedbackEventId: nil,
        metadata: promptMetadata
      )
    )
  }

  func logStoreReviewSkipped() {
    guard let currentPromptEvent else { return }

    requestQueue.enqueue(
      apiClient.sendPromptEvent(
        type: .storeReviewSkipped,
        previousEventId: currentPromptEvent.eventId,
        feedbackEventId: nil,
        metadata: promptMetadata
      )
    )
  }

  func logUserFeedback(rating: Int, comment: String? = nil) {
    guard let currentPromptEvent else { return }

    requestQueue.enqueue(
      apiClient.sendFeedbackEvent(
        promptEventId: currentPromptEvent.eventId,
        rating: rating,
        comment: comment,
        metadata: promptMetadata
      )
    )

    feedbackEventRegistered = true
  }

  func logUserComment(comment: String?) {
    guard let currentFeedbackResponse else { return }

    requestQueue.enqueue(
      apiClient.sendFeedbackComment(
        comment: comment,
        feedbackEventId: currentFeedbackResponse.eventId
      )
    )
  }

  func promptForReviewIfPossible(metadata: [String: String]? = nil, config: PromptConfig) {
    self.currentPromptConfig = config
    self.promptMetadata = metadata

    requestQueue.enqueue(
      apiClient.checkPromptEligibility()
    )
  }

  func dismissPrompt() {
    logPromptDismissed()
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

  private func handle(_ event: QueuedRequestResult) {
    if event.eventType == .checkPromptEligibility {
      handleEligibilityResult(event)
    } else if event.eventType == .sendFeedbackEvent {
      handleFeedbackEventResult(event)
    } else if event.eventType == .sendPromptEvent {
      handlePromptEventResult(event)
    }
  }

  private func handleEligibilityResult(_ event: QueuedRequestResult) {
    guard event.eventType == .checkPromptEligibility else { return }

    switch event.result {
    case .success(let data):
      guard let response = try? JSONDecoder().decode(PromptEligibilityResponse.self, from: data) else {
        print("[PromptManager] Failed to decode eligibility")
        return
      }

      currentEligibility = response
      currentFeedbackResponse = nil

      if response.eligible {
        showPrompt()
        print("[PromptManager] User eligible for prompt")
      } else {
        print("[PromptManager] User not eligible for prompt:", response.reason ?? "Unknown reason")
      }

    case .failure(let error):
      print("[PromptManager] Eligibility request failed:", error.localizedDescription)
    }
  }

  private func handlePromptEventResult(_ event: QueuedRequestResult) {
    guard event.eventType == .sendPromptEvent else { return }

    switch event.result {
    case .success(let data):
      guard let response = try? JSONDecoder().decode(PromptEventLogResponse.self, from: data) else {
        print("[PromptManager] Failed to decode event result")
        return
      }

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
      print("[PromptManager] Eligibility request failed:", error)
    }
  }

  private func handleFeedbackEventResult(_ event: QueuedRequestResult) {
    guard event.eventType == .sendFeedbackEvent else { return }

    switch event.result {
    case .success(let result):
      guard let response = try? JSONDecoder().decode(FeedbackLogResponse.self, from: result) else {
        print("[PromptManager] Failed to decode event result")
        return
      }

      currentFeedbackResponse = response

      print("[PromptManager] Feedback event logged")

      feedbackEventPublisher.send(
        FeedbackEvent(type: .rating, response: response)
      )
    case .failure(let error):
      feedbackEventPublisher.send(
        FeedbackEvent(type: .rating, response: nil)
      )
      print("[PromptManager] Feedback request failed:", error)
    }
  }

  private func handleCommentEventResult(_ event: QueuedRequestResult) {
    guard event.eventType == .sendFeedbackComment else { return }

    switch event.result {
    case .success(let result):
      guard let response = try? JSONDecoder().decode(FeedbackLogResponse.self, from: result) else {
        print("[PromptManager] Failed to decode event result")
        return
      }

      print("[PromptManager] Comment saved successfully")
      
      if let currentFeedbackResponse {
        feedbackEventPublisher.send(
          FeedbackEvent(type: .comment, response: currentFeedbackResponse)
        )
      }
    case .failure(let error):
      feedbackEventPublisher.send(
        FeedbackEvent(type: .comment, response: nil)
      )
      print("[PromptManager] Comment request failed:", error)
    }
  }
}
