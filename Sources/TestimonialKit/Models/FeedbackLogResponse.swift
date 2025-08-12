import Foundation

struct FeedbackLogResponse: Decodable, Equatable, Sendable {
  let message: String
  let eventId: String
  let redirectMode: StoreRedirectMode
  let redirectAutomatically: Bool
  let isPositiveRating: Bool
  let requestComment: Bool
  let appStoreId: String?
  let hasComment: Bool

  var hasAppStoreId: Bool {
    appStoreId != nil && appStoreId?.isEmpty == false
  }
}

enum StoreRedirectMode: String, Codable, Equatable {
  case none = "none"
  case positiveOnly = "positive_only"
  case always = "always"
}
