import SwiftUI
import Combine
import Factory

enum PromptViewState: Equatable {
  case rating
  case comment(data: FeedbackLogResponse)
  case thankYou(data: FeedbackLogResponse?)
  case storeReview(redirected: Bool)
}

@MainActor
class PromptViewModel: ObservableObject {
  private var cancellables = Set<AnyCancellable>()
  private let promptManager: PromptManagerProtocol
  @Published var rating: Int = 0
  @Published var comment: String = ""
  @Published var state: PromptViewState = .rating
  @Published var isLoading = false

  // Re-entrancy guard for dismiss
  private var didRequestDismiss = false

  init(promptManager: PromptManagerProtocol) {
    self.promptManager = promptManager
    promptManager.feedbackEventPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] (event) in
        guard let self else { return }

        switch event {
        case .rating(let data):
          if !data.isPositiveRating || data.requestComment {
            setStateDeferred(.comment(data: data))
          } else if data.isPositiveRating && data.redirectAutomatically && data.hasAppStoreId {
            self.promptManager.dismissPrompt(on: .storeReview(redirected: true))
          } else if data.isPositiveRating && data.hasAppStoreId {
            setStateDeferred(.storeReview(redirected: false))
          } else {
            setStateDeferred(.thankYou(data: data))
          }

        case .comment(let data):
          if data.isPositiveRating && data.redirectAutomatically && data.hasAppStoreId {
            self.promptManager.dismissPrompt(on: .storeReview(redirected: true))
          } else if data.isPositiveRating && data.hasAppStoreId {
            setStateDeferred(.storeReview(redirected: false))
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
    case .storeReview:
      requestDismiss(as: .storeReview(redirected: true))
    case .thankYou(let data):
      requestDismiss(as: .thankYou(data: data))
    }
  }

  func handleSubmitRating() {
    if rating == 0 { return }
    isLoading = true
    promptManager.logUserFeedback(rating: rating, comment: comment.isEmpty ? nil : comment)
  }

  func handleSubmitComment() {
    isLoading = true
    dismissKeyboard()
    promptManager.logUserComment(comment: comment.isEmpty ? nil : comment)
  }

  func handleDismiss() {
    if case .comment(let data) = state {
      if data.isPositiveRating && data.hasAppStoreId {
        setStateDeferred(.storeReview(redirected: false))
      } else {
        setStateDeferred(.thankYou(data: data))
      }
    } else {
      requestDismiss(as: state)
    }
  }

  func handleOnDisappear() {
    promptManager.handlePromptDismissAction(on: state)
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
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.promptManager.dismissPrompt(on: finalState)
    }
  }
}
