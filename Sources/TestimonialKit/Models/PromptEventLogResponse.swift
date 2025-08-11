import Foundation

struct PromptEventLogResponse: Decodable, Sendable {
  let message: String
  let eventId: String
  let status: PromptEventType
}
