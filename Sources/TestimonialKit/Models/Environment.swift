import Foundation

/// Represents the runtime environment configuration for the application.
///
/// Used to distinguish between production, staging, and development environments.
/// Conforms to `Codable` for persistence and `Sendable` for concurrency safety.
public enum AppEnvironment: String, Codable, Sendable {
  /// The production environment, used for live deployments with real users.
  case production
  /// The staging environment, typically used for pre-production testing and QA.
  case staging
  /// The development environment, used for local development and testing.
  case development
}
