import Foundation

struct AppEventLogResponse: Decodable {
  let message: String
  let eventId: String
}
