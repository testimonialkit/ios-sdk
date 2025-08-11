import Foundation

struct AppEventLogResponse: Decodable, Sendable {
  let message: String
  let eventId: String
}
