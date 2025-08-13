import Foundation

/// Represents the various types of API events that can be sent by the SDK.
///
/// Each case corresponds to a specific backend endpoint or operation,
/// and is used for identifying and categorizing queued requests and results.
/// Conforms to `Codable` for persistence and `Sendable` for concurrency safety.
enum APIEventType: String, Codable, Sendable {
  /// Event type for SDK initialization.
  /// Typically used when the SDK first starts and needs to register or configure itself with the backend.
  case initSdk
  
  /// Event type for sending a generic application event to the backend.
  /// Can be used for analytics or logging important app activities.
  case sendEvent
  
  /// Event type for checking whether the user is eligible to be shown a prompt.
  /// This could depend on backend-defined targeting rules or thresholds.
  case checkPromptEligibility
  
  /// Event type for sending an event related to a displayed prompt.
  /// Examples include prompt shown, dismissed, or interacted with.
  case sendPromptEvent
  
  /// Event type for submitting feedback data in response to a prompt.
  /// May include ratings, choices, or structured survey answers.
  case sendFeedbackEvent
  
  /// Event type for submitting a textual comment as part of user feedback.
  case sendFeedbackComment
}
