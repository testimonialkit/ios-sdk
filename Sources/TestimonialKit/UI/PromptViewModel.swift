import SwiftUI
import Combine
import Factory

enum PromptViewState: Equatable, Hashable {
  case rating, comment, thankYou
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

  init(promptManager: PromptManagerProtocol) {
    self.promptManager = promptManager
    promptManager.feedbackEventPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] (event) in
        guard let self else { return }
        defer { self.isLoading = false }

        switch event {
        case .rating(let data):
          if !data.isPositiveRating || data.requestComment {
            self.state = .comment
          } else if data.isPositiveRating && data.redirectAutomatically {
            self.promptManager.dismissPrompt(on: .storeReview(redirected: true))
          } else if data.isPositiveRating {
            self.state = .storeReview(redirected: false)
          } else {
            self.state = .thankYou
          }

        case .comment(let data):
          if data.isPositiveRating && data.redirectAutomatically {
            self.promptManager.dismissPrompt(on: .storeReview(redirected: true))
          } else if data.isPositiveRating {
            self.state = .storeReview(redirected: false)
          } else {
            self.state = .thankYou
          }

        case .error:
          self.state = .thankYou
        }
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
      promptManager.dismissPrompt(on: .storeReview(redirected: true))
    case .thankYou:
      promptManager.dismissPrompt(on: .thankYou)
    }
  }

  func handleSubmitRating() {
    if rating == 0 { return }
    isLoading = true
    promptManager.logUserFeedback(rating: rating, comment: comment.isEmpty ? nil : comment)
  }

  func handleSubmitComment() {
    isLoading = true
    promptManager.logUserComment(comment: comment.isEmpty ? nil : comment)
  }

  func handleDismiss() {
    promptManager.dismissPrompt(on: state)
  }

  func handleOnAppear() {
    promptManager.logPromptShown()
  }

  func handleOnDisappear() {
    promptManager.logPromptDismissed()
  }
}
