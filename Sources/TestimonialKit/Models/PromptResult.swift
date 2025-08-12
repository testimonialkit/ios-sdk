import Foundation

public enum PromptResult {
  case cancelled
  case completed
  case completedWithoutComment
  case redirectedToStore
  case storeReviewSkipped
}
