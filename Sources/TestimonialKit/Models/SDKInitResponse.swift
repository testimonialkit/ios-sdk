import Foundation

/// Represents the response received from the backend after initializing the SDK.
///
/// Contains information about the current user, feedback behavior configuration,
/// environment settings, and subscription status.
/// Conforms to `Decodable` for JSON parsing and `Sendable` for concurrency safety.
struct SDKInitResponse: Decodable, Sendable {
  /// The unique identifier for the current user, assigned by the backend.
  let userId: String
  /// The current application environment, such as production, staging, or development.
  let environment: AppEnvironment
  /// Indicates whether the user currently has an active subscription.
  /// Defaults to `false` if not provided in the response.
  var hasActiveSubscription: Bool = false
}
