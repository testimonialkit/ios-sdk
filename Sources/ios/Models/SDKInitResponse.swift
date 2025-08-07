import Foundation

struct SDKInitResponse: Decodable {
  let userId: String
  let requestCommentOnPositiveRating: Bool
  let environment: Environment
}
