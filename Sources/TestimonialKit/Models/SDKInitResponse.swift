import Foundation

struct SDKInitResponse: Decodable, Sendable {
  let userId: String
  let requestCommentOnPositiveRating: Bool
  let environment: AppEnvironment
}
