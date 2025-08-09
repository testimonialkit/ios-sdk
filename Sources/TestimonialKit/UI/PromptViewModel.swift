import SwiftUI
import Combine
import Factory

enum PromptViewState {
  case rating, comment, storeReview
}

@MainActor
class PromptViewModel: ObservableObject {
  private var cancellables = Set<AnyCancellable>()
  @Injected(\.promptManager) private var promptManager
  @Published var rating: Int = 0
  @Published var comment: String = ""
  @Published var state: PromptViewState = .rating
  @Published var isLoading = false

  init() {
    promptManager.feedbackEventPublisher.sink { [weak self] (event) in
      switch event.type {
      case .rating:
        if let response = event.response {
          if !response.isPositiveRating || response.requestComment {
            self?.state = .comment
          } else if response.redirectAutomatically {
            self?.promptManager.dismissPrompt()
          } else {
            self?.state = .storeReview
            print("State changed to store review")
          }
        }

        self?.isLoading = false
      case .comment:
        print("Comment submitted")
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
      print("redirect to store")
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
    promptManager.dismissPrompt()
  }

  func handleDismiss() {
    promptManager.dismissPrompt()
  }
}
