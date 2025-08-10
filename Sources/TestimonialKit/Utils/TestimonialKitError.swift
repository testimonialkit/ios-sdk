import Foundation

public enum TestimonialKitError: Error, LocalizedError {
  case notInitialized
  case missingUserId
  case invalidAPIKey
  case networkError(String)
  case storageError(String)
  case parsingError(String)
  case unknown

  public var errorDescription: String? {
    switch self {
    case .notInitialized:
      return "TestimonialKit SDK has not been initialized. Call setup() first."
    case .missingUserId:
      return "User ID is missing. Make sure to call setUser(id:) before tracking events."
    case .invalidAPIKey:
      return "API key is invalid. Check your setup."
    case .networkError(let message):
      return "Network error: \(message)"
    case .storageError(let message):
      return "Storage error: \(message)"
    case .parsingError(let message):
      return "Parsing error: \(message)"
    case .unknown:
      return "An unknown error occurred."
    }
  }
}
