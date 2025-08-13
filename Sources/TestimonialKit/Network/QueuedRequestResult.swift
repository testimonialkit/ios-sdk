import Foundation

/// Represents the result of a queued API request, including its event type and outcome.
///
/// Contains the originating `APIEventType` and a `QueueResult` wrapping either success data or a failure.
struct QueuedRequestResult: Sendable {
  /// The type of API event that was processed.
  let eventType: APIEventType
  /// The outcome of the request, containing either raw `Data` on success or a `QueueFailure` on failure.
  let result: QueueResult<Data>
}

/// Represents an error that occurred while processing a queued request.
///
/// Includes optional metadata such as HTTP status, URL, error code, and a snippet of the response payload.
struct QueueFailure: Error, Sendable {
  /// Optional error code associated with the failure.
  let code: Int?
  /// A human-readable description of the error.
  let message: String
  /// The URL of the request that caused the failure, if available.
  let url: URL?
  /// Optional HTTP status code returned by the server.
  let status: Int?
  /// A snippet of the response payload body (up to 512 characters) for debugging.
  let payloadSnippet: String?
  
  /// Creates a new `QueueFailure` from an error and optional metadata.
  ///
  /// - Parameters:
  ///   - error: The underlying error that caused the failure.
  ///   - code: Optional error code.
  ///   - url: Optional URL of the failed request.
  ///   - status: Optional HTTP status code.
  ///   - payload: Optional raw payload data, from which a snippet will be extracted.
  init(_ error: any Error,
       code: Int? = nil,
       url: URL? = nil,
       status: Int? = nil,
       payload: Data? = nil) {
    self.code = code
    self.message = String(describing: error)
    self.url = url
    self.status = status
    self.payloadSnippet = payload.flatMap { String(data: $0, encoding: .utf8) }?.prefix(512).description
  }
  
  /// A concatenated string describing the error, including HTTP status, URL, message, and payload snippet.
  public var errorDescription: String? {
    var parts: [String] = []
    if let status { parts.append("HTTP \(status)") }
    if let url { parts.append(url.absoluteString) }
    parts.append(message)
    if let payloadSnippet, !payloadSnippet.isEmpty { parts.append("Body: \(payloadSnippet)") }
    return parts.joined(separator: " | ")
  }
}

/// Represents the result of a queued operation, containing either a success value or a `QueueFailure`.
///
/// This is similar to Swift's `Result` type but specialized for queued request handling.
enum QueueResult<Success: Sendable>: Sendable {
  /// Indicates that the operation completed successfully with the given value.
  case success(Success)
  /// Indicates that the operation failed with the given `QueueFailure`.
  case failure(QueueFailure)
  
  /// Executes a throwing closure and wraps its outcome in a `QueueResult`.
  ///
  /// - Parameter body: A closure that may throw an error.
  ///   If it returns a value, `.success` is created; if it throws, `.failure` is created with the error.
  init(catching body: () throws -> Success) {
    do { self = .success(try body()) }
    catch { self = .failure(QueueFailure(error)) }
  }
}

/// Represents different decoded events from the request queue, each with its associated result type.
enum DecodedQueueEvent: Sendable {
  /// Event for SDK initialization result.
  case initSdk(QueueResult<SDKInitResponse>)
  /// Event for sending an app event log result.
  case sendEvent(QueueResult<AppEventLogResponse>)
  /// Event for checking prompt eligibility result.
  case checkEligibility(QueueResult<PromptEligibilityResponse>)
  /// Event for logging a prompt display or interaction result.
  case promptEvent(QueueResult<PromptEventLogResponse>)
  /// Event for logging feedback submission result.
  case feedbackEvent(QueueResult<FeedbackLogResponse>)
  /// Event for logging a feedback comment submission result.
  case feedbackComment(QueueResult<FeedbackLogResponse>)
  /// Event type that could not be recognized, with its raw string.
  case unhadnledEvent(String)
}

/// Extension adding convenience decoding with `QueueFailure` error wrapping.
extension JSONDecoder {
  /// Decodes data into the specified Decodable type, or throws a `QueueFailure` if decoding fails.
  ///
  /// - Parameters:
  ///   - type: The type to decode into.
  ///   - data: The raw JSON data to decode.
  /// - Throws: `QueueFailure` if decoding fails or if the error is already a `QueueFailure`.
  /// - Returns: The decoded value of the specified type.
  func decodeOrThrowQueueFailure<T: Decodable>(
    _ type: T.Type,
    from data: Data
  ) throws(QueueFailure) -> T {
    do {
      return try decode(type, from: data)
    } catch let failure as QueueFailure {
      // already the right type
      throw failure
    } catch {
      // wrap DecodingError (or anything else) into QueueFailure
      throw QueueFailure(error)
    }
  }
}
