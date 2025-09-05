import Foundation

/// Represents the possible outcomes after a user interacts with a prompt.
///
/// Used to track and handle user actions such as dismissing, completing,
/// or skipping different steps in the prompt flow.
/// Conforms to `Sendable` for concurrency safety.
public enum PromptResult: Sendable {
  /// The user dismissed the prompt without submitting a rating.
  case cancelled

  /// The user submitted both a rating and a comment (if applicable).
  case completed

  /// The user was redirected to the app store after submitting a rating, with or without a comment.
  case redirectedToStore

  /// The user skipped the store review process and dismissed the prompt.
  case storeReviewSkipped
}
