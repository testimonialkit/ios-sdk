import Foundation

struct PromptEligibilityResponse: Decodable {
  let eligible: Bool
  let reason: String?
  let eventId: String
  let status: String?
}
