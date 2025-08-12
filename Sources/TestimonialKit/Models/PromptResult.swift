import Foundation

public enum PromptResult {
  /// User did dismiss the prompt without submitting the rating
  case cancelled

  /// User did submit the rating and the comment (when applicable)
  case completed

  /// User did submit the rating but without a comment (if the comment was not requested or left empty)
  case completedWithoutComment

  /// User was redirected to store after submitting the rating (with or without comment)
  case redirectedToStore

  /// User skipped store review and dismissed the prompt
  case storeReviewSkipped
}
