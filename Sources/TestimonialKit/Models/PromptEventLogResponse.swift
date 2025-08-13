import Foundation

/// Represents the backend response received after logging a prompt-related event.
///
/// Contains a message describing the result, the unique event ID, and the type of the prompt event.
/// Conforms to `Decodable` for JSON parsing and `Sendable` for concurrency safety.
struct PromptEventLogResponse: Decodable, Sendable {
  /// A descriptive message from the backend indicating the result of the prompt event logging.
  let message: String
  /// The unique identifier assigned to the prompt event by the backend.
  let eventId: String
  /// The type or status of the prompt event as defined by `PromptEventType`.
  let status: PromptEventType
}
