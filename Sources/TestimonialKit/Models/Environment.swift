import Foundation

public enum AppEnvironment: String, Codable, Sendable {
  case production, staging, development
}
