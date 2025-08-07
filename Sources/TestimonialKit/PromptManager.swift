import SwiftUI
import Combine

final class PromptManager: @unchecked Sendable {
  static let shared = PromptManager()

  private var promptMetadata: [String: String]?
  private var cancellables = Set<AnyCancellable>()
  private var currentEligibility: PromptEligibilityResponse?
  private var currentPromptEvent: PromptEventLogResponse?
  private var currentFeedbackResponse: FeedbackLogResponse?
  private weak var presentedPromptVC: UIViewController?

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

    guard let config = TestimonialKit.shared.config else {
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

    if currentFeedbackResponse != nil {
      logPromptDismissedAfterRating()
      return
    }

    guard let config = TestimonialKit.shared.config else {
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
    guard let currentPromptEvent else { return }

    guard let config = TestimonialKit.shared.config else {
      print("[Prompt] SDK is not configured.")
      return
    }

    RequestQueue.shared.enqueue(
      APIClient.shared.sendPromptEvent(
        type: .promptDismissedAfterRating,
        previousEventId: currentPromptEvent.eventId,
        config: config,
        metadata: promptMetadata
      )
    )
  }

  func logRedirectedToStore() {
    guard let currentPromptEvent else { return }

    guard let config = TestimonialKit.shared.config else {
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

    guard let config = TestimonialKit.shared.config else {
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

  func logUserFeedback(rating: Int, comment: String?) {
    guard let currentPromptEvent else { return }

    guard let config = TestimonialKit.shared.config else {
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
  }

  func promptForReviewIfPossible(metadata: [String: String]? = nil) {
    self.promptMetadata = metadata

    guard let config = TestimonialKit.shared.config else {
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

      if response.status == .promptDismissedAfterRating {
        currentFeedbackResponse = nil
      }

      print("[PromptManager] Prompt event logged", response.status.rawValue)
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
    case .failure(let error):
      print("[PromptManager] Feedback request failed:", error)
    }
  }

  @MainActor
  func dismissPrompt(afterRating: Bool = false) {
    presentedPromptVC?.dismiss(animated: true)
    presentedPromptVC = nil
  }

  @MainActor
  func showPrompt() {
    guard let presenter = UIViewController.topMost else {
      print("[PromptManager] No presenter available")
      return
    }

    let swiftUIView = PromptView(promptText: "Some prompt text") { [weak self] rating, comment in
      self?.logUserFeedback(rating: rating, comment: (comment?.isEmpty ?? true) ? nil : comment)
      self?.dismissPrompt(afterRating: true)
    }

    let hostingVC = UIHostingController(rootView: swiftUIView)
    hostingVC.modalPresentationStyle = .pageSheet
    presenter.present(hostingVC, animated: true)
    presentedPromptVC = hostingVC
  }
}
