import Foundation

/// Represents the response received after logging an application event to the backend.
///
/// Contains a status message and the unique identifier of the logged event.
/// Conforms to `Decodable` for JSON decoding and `Sendable` for concurrency safety.
struct AppEventLogResponse: Decodable, Sendable {
  /// A status message returned by the backend indicating the result of the log request.
  let message: String
  /// The unique identifier assigned to the logged event by the backend.
  let eventId: String
}
