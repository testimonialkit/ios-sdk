import Foundation

struct PromptEventLogResponse: Decodable {
  let message: String
  let eventId: String
  let status: PromptEventType
}
