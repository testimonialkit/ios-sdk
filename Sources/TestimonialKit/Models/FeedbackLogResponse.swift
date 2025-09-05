import Foundation

/// Represents the response returned by the backend after logging user feedback.
///
/// Contains metadata about the feedback event, redirection behavior, and app store information.
/// Conforms to `Decodable` for JSON parsing, `Equatable` for comparison, and `Sendable` for concurrency safety.
struct FeedbackLogResponse: Decodable, Equatable, Sendable {
  /// A message from the backend indicating the status or result of the feedback logging.
  let message: String
  /// The unique identifier assigned to the feedback event by the backend.
  let eventId: String
  /// The unique identifier of the app in the AppStore
  let appstoreId: String?
  /// The app bundle ID
  let bundleId: String
  /// Indicates whether the app is released to the store
  let isAppReleased: Bool
}
