import Foundation

struct PromptEligibilityResponse: Decodable, Sendable {
  let eligible: Bool
  let reason: String?
  let eventId: String
  let status: String?
}
