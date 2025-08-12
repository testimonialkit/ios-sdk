import SwiftUI
import Combine
import Factory

enum PromptViewState: Equatable, Sendable {
  case rating
  case comment(data: FeedbackLogResponse)
  case thankYou(data: FeedbackLogResponse?)
  case storeReview(redirected: Bool, data: FeedbackLogResponse)
}

@MainActor
class PromptViewModel: ObservableObject {
  private var cancellables = Set<AnyCancellable>()
  private let promptManager: PromptManagerProtocol
  private let sdkConfig: TestimonialKitConfig
  @Published var rating: Int = 0
  @Published var comment: String = ""
  @Published var state: PromptViewState = .rating
  @Published var isLoading = false

  var showBranding: Bool {
    !sdkConfig.hasActiveSubscription
  }

  // Re-entrancy guard for dismiss
  private var didRequestDismiss = false

  init(promptManager: PromptManagerProtocol, sdkConfig: TestimonialKitConfig) {
    self.promptManager = promptManager
    self.sdkConfig = sdkConfig
    promptManager.feedbackEventPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] (event) in
        guard let self else { return }

        switch event {
        case .rating(let data):
          if !data.isPositiveRating || data.requestComment {
            setStateDeferred(.comment(data: data))
          } else if data.isPositiveRating && data.redirectAutomatically && data.hasAppStoreId {
            self.redirectToAppStoreReview(data: data)
          } else if data.isPositiveRating && data.hasAppStoreId {
            setStateDeferred(.storeReview(redirected: false, data: data))
          } else {
            setStateDeferred(.thankYou(data: data))
          }

        case .comment(let data):
          if data.isPositiveRating && data.redirectAutomatically && data.hasAppStoreId {
            self.redirectToAppStoreReview(data: data)
          } else if data.isPositiveRating && data.hasAppStoreId {
            setStateDeferred(.storeReview(redirected: false, data: data))
          } else {
            setStateDeferred(.thankYou(data: data))
          }

        case .error:
          setStateDeferred(.thankYou(data: nil))
        }

        defer { self.isLoading = false }
      }
      .store(in: &cancellables)
  }

  func handleSubmit() {
    switch state {
    case .rating:
      handleSubmitRating()
    case .comment:
      handleSubmitComment()
    case .storeReview(_, let data):
      redirectToAppStoreReview(data: data)
    case .thankYou(let data):
      requestDismiss(as: .thankYou(data: data))
    }
  }

  func handleSubmitRating() {
    if rating == 0 { return }
    isLoading = true
    Task { [weak self] in
      guard let self else { return }
      await promptManager.logUserFeedback(rating: rating, comment: comment.isEmpty ? nil : comment)
    }
  }

  func handleSubmitComment() {
    isLoading = true
    dismissKeyboard()
    Task { [weak self] in
      guard let self else { return }
      await promptManager.logUserComment(comment: comment.isEmpty ? nil : comment)
    }
  }

  func handleDismiss() {
    if case .comment(let data) = state {
      if data.isPositiveRating && data.hasAppStoreId {
        setStateDeferred(.storeReview(redirected: false, data: data))
      } else {
        setStateDeferred(.thankYou(data: data))
      }
    } else {
      requestDismiss(as: state)
    }
  }

  func handleOnDisappear() {
    Task { [weak self] in
      guard let self else { return }
      await promptManager.handlePromptDismissAction(on: state)
    }
  }

  func redirectToAppStoreReview(data: FeedbackLogResponse) {
    let appStoreID = data.appStoreId ?? ""

    if appStoreID.isEmpty {
      Logger.shared.debug("Invalid app identifier")
      requestDismiss(as: .storeReview(redirected: false, data: data))
      return
    }

    guard let url = URL(string: "itms-apps://itunes.apple.com/app/\(appStoreID)?action=write-review") else {
      Logger.shared.debug("Invalid store URL")
      requestDismiss(as: .storeReview(redirected: false, data: data))
      return
    }

    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url, options: [:]) { [weak self] success in
        if !success {
          Logger.shared.debug("Failed to open AppStore")
          self?.requestDismiss(as: .storeReview(redirected: false, data: data))
        } else {
          self?.requestDismiss(as: .storeReview(redirected: true, data: data))
        }
      }
    } else {
      Logger.shared.debug("Can not open URL")
      requestDismiss(as: .storeReview(redirected: false, data: data))
    }
  }

  private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
  }

  private func setStateDeferred(_ newState: PromptViewState) {
    guard state != newState else { return }
    DispatchQueue.main.async { [weak self] in
      self?.state = newState
    }
  }

  private func requestDismiss(as finalState: PromptViewState) {
    guard !didRequestDismiss else { return }
    didRequestDismiss = true

    // Reflect final state for UI immediately (safe), then defer external dismiss
    state = finalState
    Task { [weak self] in
      guard let self else { return }
      await promptManager.dismissPrompt(on: finalState)
    }
  }
}
