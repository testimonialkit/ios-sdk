import Foundation

/// Represents the backend response for a prompt eligibility check.
///
/// Contains information about whether the user is eligible to see a prompt,
/// an optional reason for ineligibility, the event ID related to the check,
/// and the current status of the eligibility request.
/// Conforms to `Decodable` for JSON parsing and `Sendable` for concurrency safety.
struct PromptEligibilityResponse: Decodable, Sendable, Equatable {
  /// Indicates whether the user is eligible to be shown a prompt.
  let eligible: Bool
  /// Optional reason explaining why the user is not eligible for the prompt, if applicable.
  let reason: String?
  /// The type of the prompt that user is eligible for, if `nil` the user is not eligible for any prompt
  let type: PromptType?
  /// Optional status string providing additional context or state for the eligibility result.
  let status: String?
  /// ID of the registered eligibility event
  let eventId: String
  /// The App Store identifier of the app
  let appstoreId: String?
  /// Indicates whether the app is released to appstore
  let isAppReleased: Bool
  /// The bundle identifier of the app
  let bundleId: String
}
