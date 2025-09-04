import Foundation

/// Centralized constants used throughout the SDK/demo app.
///
/// Includes the base API URL and current API version string.
/// Modify `baseUrl` for local development/testing as needed.
enum Constants {
  /// The base URL for API requests.
  ///
  /// Defaults to the production endpoint. Uncomment the localhost URL for local development.
//  static let baseUrl = URL(string: "https://app.testimonialkit.dev")!
  static let baseUrl = URL(string: "http://localhost:3000")!
  /// The version string for the API, appended to request paths.
  static let apiVersion = "v1"
}
