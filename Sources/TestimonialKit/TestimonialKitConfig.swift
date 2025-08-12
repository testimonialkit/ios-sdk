import Foundation

/// Holds runtime configuration for the TestimonialKit SDK.
///
/// Contains immutable app/environment information and mutable fields such as the API key,
/// user ID, and subscription status. Marked `@unchecked Sendable` for safe passing across
/// concurrency boundaries, but callers must ensure thread safety when mutating properties.
final class TestimonialKitConfig: @unchecked Sendable {
  /// API key used to authenticate requests to the TestimonialKit backend.
  var apiKey: String
  /// The bundle identifier of the host application.
  let bundleId: String
  /// Unique identifier for the current user.
  var userId: String
  /// Human‑readable application version string.
  let appVersion: String
  /// ISO country code for the device/user locale.
  let countryCode: String
  /// Static string identifying the platform (always `"ios"`).
  let platform: String = "ios"
  /// Current version of the TestimonialKit SDK.
  let sdkVersion: String = "1.0.0"
  /// Indicates whether the current user has an active subscription.
  var hasActiveSubscription: Bool = false

  /// Creates a new `TestimonialKitConfig` instance.
  /// - Parameters:
  ///   - apiKey: API key used to authenticate requests.
  ///   - bundleId: Bundle identifier of the host app.
  ///   - userId: Unique user identifier.
  ///   - appVersion: Human‑readable app version.
  ///   - countryCode: ISO country code for the user/device locale.
  ///   - hasActiveSubscription: Whether the current user has an active subscription (default `false`).
  init(
    apiKey: String,
    bundleId: String,
    userId: String,
    appVersion: String,
    countryCode: String,
    hasActiveSubscription: Bool = false
  ) {
    self.apiKey = apiKey
    self.bundleId = bundleId
    self.userId = userId
    self.appVersion = appVersion
    self.countryCode = countryCode
    self.hasActiveSubscription = hasActiveSubscription
  }
}
