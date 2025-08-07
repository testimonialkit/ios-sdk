import Foundation

struct SDKErrorResponse: Decodable {
  let message: String
  let errorCode: String?
}
