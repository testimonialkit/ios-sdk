import Foundation

enum Endpoints {
  static let initialization = "/sdk/init"
  static let promptEligibility = "/sdk/should-prompt"
  static let projectEvents = "/sdk/project-events"
  static let promptEvents = "/sdk/prompt-events"
  static let feedback = "/sdk/feedback"
}

enum Headers: String {
  case apiKey = "x-api-key"
  case bundleId = "x-bundle-id"
  case platform = "x-app-platform"
  case contentType = "Content-Type"
}
