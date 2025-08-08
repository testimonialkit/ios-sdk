import SwiftUI
import Combine

final class PromptManager: @unchecked Sendable {
  static let shared = PromptManager()

  private var promptMetadata: [String: String]?
  private var cancellables = Set<AnyCancellable>()
  private var currentEligibility: PromptEligibilityResponse?
  private var currentPromptEvent: PromptEventLogResponse?
  private var currentFeedbackResponse: FeedbackLogResponse?
  private var feedbackEventRegistered: Bool = false
  private weak var presentedPromptVC: UIViewController?
  private var currentPromptConfig: PromptConfig = PromptConfig()
  let feedbackEventPublisher = PassthroughSubject<FeedbackEvent, Never>()

  private init() {
    RequestQueue.shared.eventPublisher
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

    guard let config = TestimonialKitManager.shared.config else {
      print("[Prompt] SDK is not configured.")
      return
    }

    RequestQueue.shared.enqueue(
      APIClient.shared.sendPromptEvent(
        type: .promptShown,
        previousEventId: currentEligibility.eventId,
        config: config,
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

    guard let config = TestimonialKitManager.shared.config else {
      print("[Prompt] SDK is not configured.")
      return
    }

    RequestQueue.shared.enqueue(
      APIClient.shared.sendPromptEvent(
        type: .promptDismissed,
        previousEventId: currentPromptEvent.eventId,
        config: config,
        metadata: promptMetadata
      )
    )
  }

  func logPromptDismissedAfterRating() {
    guard let currentFeedbackResponse, let currentPromptEvent, feedbackEventRegistered else { return }

    guard let config = TestimonialKitManager.shared.config else {
      print("[Prompt] SDK is not configured.")
      return
    }

    RequestQueue.shared.enqueue(
      APIClient.shared.sendPromptEvent(
        type: .promptDismissedAfterRating,
        previousEventId: currentPromptEvent.eventId,
        feedbackEventId: currentFeedbackResponse.eventId,
        config: config,
        metadata: promptMetadata
      )
    )

    feedbackEventRegistered = false
  }

  func logRedirectedToStore() {
    guard let currentPromptEvent else { return }

    guard let config = TestimonialKitManager.shared.config else {
      print("[Prompt] SDK is not configured.")
      return
    }

    RequestQueue.shared.enqueue(
      APIClient.shared.sendPromptEvent(
        type: .redirectedToStore,
        previousEventId: currentPromptEvent.eventId,
        config: config,
        metadata: promptMetadata
      )
    )
  }

  func logStoreReviewSkipped() {
    guard let currentPromptEvent else { return }

    guard let config = TestimonialKitManager.shared.config else {
      print("[Prompt] SDK is not configured.")
      return
    }

    RequestQueue.shared.enqueue(
      APIClient.shared.sendPromptEvent(
        type: .storeReviewSkipped,
        previousEventId: currentPromptEvent.eventId,
        config: config,
        metadata: promptMetadata
      )
    )
  }

  func logUserFeedback(rating: Int, comment: String? = nil) {
    guard let currentPromptEvent else { return }

    guard let config = TestimonialKitManager.shared.config else {
      print("[Prompt] SDK is not configured.")
      return
    }

    RequestQueue.shared.enqueue(
      APIClient.shared.sendFeedbackEvent(
        promptEventId: currentPromptEvent.eventId,
        rating: rating,
        comment: comment,
        config: config
      )
    )

    feedbackEventRegistered = true
  }

  func logUserComment(comment: String?) {
    guard let currentFeedbackResponse else { return }

    guard let config = TestimonialKitManager.shared.config else {
      print("[Prompt] SDK is not configured.")
      return
    }

    RequestQueue.shared.enqueue(
      APIClient.shared.sendFeedbackComment(
        comment: comment,
        feedbackEventId: currentFeedbackResponse.eventId,
        config: config
      )
    )
  }

  func promptForReviewIfPossible(metadata: [String: String]? = nil, config: PromptConfig) {
    self.currentPromptConfig = config
    self.promptMetadata = metadata

    guard let config = TestimonialKitManager.shared.config else {
      print("[Prompt] SDK is not configured.")
      return
    }

    RequestQueue.shared.enqueue(
      APIClient.shared.checkPromptEligibility(config: config)
    )
  }

  private func handle(_ event: QueuedRequestResult) {
    handleEligibilityResult(event)
    handlePromptEventResult(event)
    handleFeedbackEventResult(event)
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
        Task {
          await MainActor.run {
            showPrompt()
          }
        }
        print("[PromptManager] User eligible for prompt")
      } else {
        print("[PromptManager] User not eligible for prompt:", response.reason ?? "Unknown reason")
      }

    case .failure(let error):
      print("[PromptManager] Eligibility request failed:", error)
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
      print("[PromptManager] Comment request failed:", error)
    }
  }

  @MainActor
  func dismissPrompt() {
    logPromptDismissed()
    presentedPromptVC?.dismiss(animated: true)
    presentedPromptVC = nil
  }

  @MainActor
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
}
