import Foundation

enum PromptEventType: String, Codable {
  case promptShown = "prompt_shown"
  case promptDismissed = "prompt_dismissed"
  case promptDismissedAfterRating = "prompt_dismissed_after_rating"
  case redirectedToStore = "redirected_to_store"
  case storeReviewSkipped = "store_review_skipped"
}
