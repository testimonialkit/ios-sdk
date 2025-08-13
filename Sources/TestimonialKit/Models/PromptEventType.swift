import Foundation

/// Represents the different types of events that can occur during the prompt lifecycle.
///
/// These events are used to track user interactions with prompts, including display, dismissal,
/// rating submission, redirection to the store, and skipped store reviews.
/// Conforms to `Codable` for serialization and `Sendable` for concurrency safety.
enum PromptEventType: String, Codable, Sendable {
  /// The prompt was displayed to the user.
  case promptShown = "prompt_shown"
  /// The prompt was dismissed by the user without providing a rating.
  case promptDismissed = "prompt_dismissed"
  /// The prompt was dismissed by the user after they submitted a rating.
  case promptDismissedAfterRating = "prompt_dismissed_after_rating"
  /// The user was redirected to the app store after interacting with the prompt.
  case redirectedToStore = "redirected_to_store"
  /// The store review step was skipped by the user.
  case storeReviewSkipped = "store_review_skipped"
}
