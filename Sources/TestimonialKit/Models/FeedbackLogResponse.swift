
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
  /// Determines under what conditions the user should be redirected to the app store.
  let redirectMode: StoreRedirectMode
  /// Indicates whether the redirection to the app store should occur automatically without user interaction.
  let redirectAutomatically: Bool
  /// Indicates whether the feedback rating was considered positive.
  let isPositiveRating: Bool
  /// Indicates whether the backend is requesting an additional text comment from the user.
  let requestComment: Bool
  /// Optional App Store identifier to use for redirection, if applicable.
  let appStoreId: String?
  /// Indicates whether the feedback event already contains a user comment.
  let hasComment: Bool

  /// Returns `true` if a non-empty App Store ID is present, otherwise `false`.
  var hasAppStoreId: Bool {
    appStoreId != nil && appStoreId?.isEmpty == false
  }
}

/// Defines the possible modes for redirecting the user to the App Store after feedback.
///
/// Conforms to `Codable` for serialization and `Equatable` for comparison.
enum StoreRedirectMode: String, Codable, Equatable, Sendable {
  /// Never redirect the user to the App Store.
  case none = "none"
  /// Redirect the user only if the feedback rating is positive.
  case positiveOnly = "positive_only"
  /// Always redirect the user to the App Store, regardless of rating.
  case always = "always"
}
