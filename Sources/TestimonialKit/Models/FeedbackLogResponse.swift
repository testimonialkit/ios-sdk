import Foundation

struct FeedbackLogResponse: Decodable, Sendable {
  let message: String
  let eventId: String
  let redirectMode: StoreRedirectMode
  let redirectAutomatically: Bool
  let isPositiveRating: Bool
  let requestComment: Bool
  let appStoreId: String?

  var hasAppStoreId: Bool {
    appStoreId != nil && appStoreId?.isEmpty == false
  }
}

enum StoreRedirectMode: String, Codable {
  case none = "none"
  case positiveOnly = "positive_only"
  case always = "always"
}
