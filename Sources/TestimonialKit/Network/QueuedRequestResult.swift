import Foundation

struct QueuedRequestResult: Sendable {
  let eventType: APIEventType
  let result: QueueResult<Data>
}

public struct QueueFailure: Error, Sendable {
  public let code: Int?
  public let message: String
  public let url: URL?
  public let status: Int?
  public let payloadSnippet: String?

  public init(_ error: any Error,
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

  public var errorDescription: String? {
    var parts: [String] = []
    if let status { parts.append("HTTP \(status)") }
    if let url { parts.append(url.absoluteString) }
    parts.append(message)
    if let payloadSnippet, !payloadSnippet.isEmpty { parts.append("Body: \(payloadSnippet)") }
    return parts.joined(separator: " | ")
  }
}

public enum QueueResult<Success: Sendable>: Sendable {
  case success(Success)
  case failure(QueueFailure)

  /// Creates a new result by evaluating a throwing closure, capturing the
  /// returned value as a success, or any thrown error as a failure.
  ///
  /// - Parameter body: A potentially throwing closure to evaluate.
  public init(catching body: () throws -> Success) {
    do { self = .success(try body()) }
    catch { self = .failure(QueueFailure(error)) }
  }
}

enum DecodedQueueEvent: Sendable {
  case initSdk(QueueResult<SDKInitResponse>)
  case sendEvent(QueueResult<AppEventLogResponse>)
  case checkEligibility(QueueResult<PromptEligibilityResponse>)
  case promptEvent(QueueResult<PromptEventLogResponse>)
  case feedbackEvent(QueueResult<FeedbackLogResponse>)
  case feedbackComment(QueueResult<FeedbackLogResponse>)
  case unhadnledEvent(String)
}


extension JSONDecoder {
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
