import Foundation

extension PromptManager: PromptViewControllerDelegate {
  func promptDidDismiss() {
    logPromptDismissed()
  }

  func didSubmitFeedback(rating: Int, comment: String?) {
    logUserFeedback(rating: rating, comment: comment)
  }
}
