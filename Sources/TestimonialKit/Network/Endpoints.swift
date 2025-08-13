import Foundation

/// Defines API endpoint paths used by the SDK.
///
/// These endpoints correspond to various backend routes for initialization, prompt eligibility checks,
/// project events, prompt events, and feedback submission.
enum Endpoints {
  /// API path for initializing the SDK.
  static let initialization = "/sdk/init"
  /// API path for checking whether a prompt should be displayed.
  static let promptEligibility = "/sdk/should-prompt"
  /// API path for sending project-level events.
  static let projectEvents = "/sdk/project-events"
  /// API path for sending prompt interaction events.
  static let promptEvents = "/sdk/prompt-events"
  /// API path for submitting user feedback.
  static let feedback = "/sdk/feedback"
}

/// Defines common HTTP header field keys used in SDK requests.
///
/// Keys are represented as raw string values matching their HTTP header names.
enum Headers: String {
  /// Header key for the API key used to authenticate requests.
  case apiKey = "x-api-key"
  /// Header key for the app's bundle identifier.
  case bundleId = "x-bundle-id"
  /// Header key for the app platform (e.g., iOS, macOS).
  case platform = "x-app-platform"
  /// Header key for specifying the content type of the request body.
  case contentType = "Content-Type"
}
