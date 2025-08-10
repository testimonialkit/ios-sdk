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

enum DecodedQueueEvent {
  case initSdk(Result<SDKInitResponse, Error>)
  case sendEvent(Result<AppEventLogResponse, Error>)
  case checkEligibility(Result<PromptEligibilityResponse, Error>)
  case promptEvent(Result<PromptEventLogResponse, Error>)
  case feedbackEvent(Result<FeedbackLogResponse, Error>)
  case feedbackComment(Result<FeedbackLogResponse, Error>)
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

  init(config: TestimonialKitConfig) {
    self.testimonialKitConfig = config

    // Decode off-main, then hop to main for state/UI updates.
    requestQueue.publisher
      .receive(on: requestQueue.decodingQueue)
      .compactMap { event -> DecodedQueueEvent? in
        switch event.eventType {
        case .checkPromptEligibility:
          switch event.result {
          case .success(let data):
            let decoded = Result { try JSONDecoder().decode(PromptEligibilityResponse.self, from: data) }
            return .checkEligibility(decoded)
          case .failure(let error):
            return .checkEligibility(.failure(error))
          }

        case .sendPromptEvent:
          switch event.result {
          case .success(let data):
            let decoded = Result { try JSONDecoder().decode(PromptEventLogResponse.self, from: data) }
            return .promptEvent(decoded)
          case .failure(let error):
            return .promptEvent(.failure(error))
          }

        case .sendFeedbackEvent:
          switch event.result {
          case .success(let data):
            let decoded = Result { try JSONDecoder().decode(FeedbackLogResponse.self, from: data) }
            return .feedbackEvent(decoded)
          case .failure(let error):
            return .feedbackEvent(.failure(error))
          }

        case .sendFeedbackComment:
          switch event.result {
          case .success(let data):
            let decoded = Result { try JSONDecoder().decode(FeedbackLogResponse.self, from: data) }
            return .feedbackComment(decoded)
          case .failure(let error):
            return .feedbackComment(.failure(error))
          }
        case .initSdk, .sendEvent:
          return .none
        }
      }
      .sink { [weak self] decoded in
        guard let self else { return }
        Task { @MainActor in
          self.apply(decoded)
        }
      }
      .store(in: &cancellables)
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
        print("[PromptManager] Eligibility request failed:", error.localizedDescription)
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
        print("[PromptManager] Prompt event failed:", error.localizedDescription)
      }

    case .feedbackEvent(let result):
      switch result {
      case .success(let response):
        currentFeedbackResponse = response
        print("[PromptManager] Feedback event logged")
        feedbackEventPublisher.send(.rating(data: response))
      case .failure(let error):
        feedbackEventPublisher.send(.error)
        print("[PromptManager] Feedback request failed:", error.localizedDescription)
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
        print("[PromptManager] Comment request failed:", error.localizedDescription)
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

    Task {
      await requestQueue.enqueue(
        apiClient.sendPromptEvent(
          type: .promptShown,
          previousEventId: currentEligibility.eventId,
          feedbackEventId: nil,
          metadata: promptMetadata
        )
      )
    }
  }

  func logPromptDismissed() {
    guard let currentPromptEvent else { return }

    if currentFeedbackResponse != nil || feedbackEventRegistered  {
      logPromptDismissedAfterRating()
      return
    }

    Task {
      await requestQueue.enqueue(
        apiClient.sendPromptEvent(
          type: .promptDismissed,
          previousEventId: currentPromptEvent.eventId,
          feedbackEventId: nil,
          metadata: promptMetadata
        )
      )
    }
  }

  func logPromptDismissedAfterRating() {
    guard let currentFeedbackResponse, let currentPromptEvent, feedbackEventRegistered else { return }

    Task {
      await requestQueue.enqueue(
        apiClient.sendPromptEvent(
          type: .promptDismissedAfterRating,
          previousEventId: currentPromptEvent.eventId,
          feedbackEventId: currentFeedbackResponse.eventId,
          metadata: promptMetadata
        )
      )
    }

    feedbackEventRegistered = false
  }

  func logRedirectedToStore() {
    guard let currentPromptEvent else { return }

    Task {
      await requestQueue.enqueue(
        apiClient.sendPromptEvent(
          type: .redirectedToStore,
          previousEventId: currentPromptEvent.eventId,
          feedbackEventId: nil,
          metadata: promptMetadata
        )
      )
    }
  }

  func logStoreReviewSkipped() {
    guard let currentPromptEvent else { return }

    Task {
      await requestQueue.enqueue(
        apiClient.sendPromptEvent(
          type: .storeReviewSkipped,
          previousEventId: currentPromptEvent.eventId,
          feedbackEventId: nil,
          metadata: promptMetadata
        )
      )
    }
  }

  func logUserFeedback(rating: Int, comment: String? = nil) {
    guard let currentPromptEvent else { return }

    Task {
      await requestQueue.enqueue(
        apiClient.sendFeedbackEvent(
          promptEventId: currentPromptEvent.eventId,
          rating: rating,
          comment: comment,
          metadata: promptMetadata
        )
      )
    }

    feedbackEventRegistered = true
  }

  func logUserComment(comment: String?) {
    guard let currentFeedbackResponse else { return }

    Task {
      await requestQueue.enqueue(
        apiClient.sendFeedbackComment(
          comment: comment,
          feedbackEventId: currentFeedbackResponse.eventId
        )
      )
    }
  }

  func promptForReviewIfPossible(metadata: [String: String]? = nil, config: PromptConfig) {
    self.currentPromptConfig = config
    self.promptMetadata = metadata

    Task {
      await requestQueue.enqueue(
        apiClient.checkPromptEligibility()
      )
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
}
