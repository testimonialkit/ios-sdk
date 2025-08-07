import Foundation

enum Endpoints {
  static let initialization = "/sdk/init"
}

enum Headers: String {
  case apiKey = "x-api-key"
  case bundleId = "x-bundle-id"
  case platform = "x-app-platform"
  case contentType = "Content-Type"
}
