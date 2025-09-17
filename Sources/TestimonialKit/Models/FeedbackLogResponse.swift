import Foundation

/// Represents the response returned by the backend after logging user feedback.
///
/// Contains metadata about the feedback event, redirection behavior, and app store information.
/// Conforms to `Decodable` for JSON parsing, `Equatable` for comparison, and `Sendable` for concurrency safety.
struct FeedbackLogResponse: Decodable, Equatable, Sendable {
  /// A message from the backend indicating the status or result of the feedback logging.
  let message: String
  /// The unique identifier assigned to the feedback event by the backend.
  let eventId: String
  /// The unique identifier of the app in the AppStore
  let appstoreId: String?
  /// The app bundle ID
  let bundleId: String
  /// Indicates whether the app is released to the store
  let isAppReleased: Bool
  /// The unique identifier of the prompt that triggered the feedback
  let promptEventId: String
  /// The type of the prompt from which the event was logged
  let type: PromptType

  init(message: String = "",
       eventId: String = "",
       appstoreId: String? = nil,
       bundleId: String = "",
       isAppReleased: Bool = false,
       promptEventId: String = "",
       type: PromptType = .feedback) {
    self.message = message
    self.eventId = eventId
    self.appstoreId = appstoreId
    self.bundleId = bundleId
    self.isAppReleased = isAppReleased
    self.promptEventId = promptEventId
    self.type = type
  }
}
