import Foundation

/// Represents a feedback-related event within the SDK.
///
/// Encapsulates the event type and an optional response from the backend.
/// Conforms to `Sendable` for concurrency safety.
struct FeedbackEvent: Sendable {
  /// The type of feedback event, indicating whether it's a rating, comment, or error.
  let type: FeedbackEventType
  /// Optional backend response data associated with the feedback event.
  /// Defaults to `nil` until a response is received.
  var response: FeedbackLogResponse? = nil
}

/// Defines the different types of feedback events that can occur.
///
/// Conforms to `Sendable` for safe use across concurrency domains.
enum FeedbackEventType: Sendable {
  /// A rating event, including the backend response data.
  /// Typically triggered when a user submits a rating.
  case rating(data: FeedbackLogResponse)
  /// A comment event, including the backend response data.
  /// Typically triggered when a user submits written feedback.
  case comment(data: FeedbackLogResponse)
  /// An error event indicating that feedback processing failed.
  /// Contains no associated data.
  case error
}
