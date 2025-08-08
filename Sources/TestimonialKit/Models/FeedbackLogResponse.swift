import Foundation

struct FeedbackLogResponse: Decodable {
  let message: String
  let eventId: String
  let redirectMode: StoreRedirectMode
  let redirectAutomatically: Bool
  let isPositiveRating: Bool
  let requestComment: Bool
}

enum StoreRedirectMode: String, Codable {
  case none = "none"
  case positiveOnly = "positive_only"
  case always = "always"
}
