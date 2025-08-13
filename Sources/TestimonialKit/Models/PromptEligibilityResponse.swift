import Foundation

/// Represents the backend response for a prompt eligibility check.
///
/// Contains information about whether the user is eligible to see a prompt,
/// an optional reason for ineligibility, the event ID related to the check,
/// and the current status of the eligibility request.
/// Conforms to `Decodable` for JSON parsing and `Sendable` for concurrency safety.
struct PromptEligibilityResponse: Decodable, Sendable {
  /// Indicates whether the user is eligible to be shown a prompt.
  let eligible: Bool
  /// Optional reason explaining why the user is not eligible for the prompt, if applicable.
  let reason: String?
  /// The unique identifier associated with this eligibility check event.
  let eventId: String
  /// Optional status string providing additional context or state for the eligibility result.
  let status: String?
}
