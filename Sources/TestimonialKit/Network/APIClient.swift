import Foundation

/// Defines the interface for an API client that communicates with the TestimonialKit backend.
///
/// Provides methods for initializing the SDK, checking prompt eligibility, sending app events,
/// prompt events, feedback events, and executing queued requests.
protocol APIClientProtocol: AnyObject, Sendable {
  /// Creates a queued request to initialize the SDK with required configuration details.
  func initSdk() -> QueuedRequest

  /// Creates a queued request to check if a prompt should be displayed to the user.
  func checkPromptEligibility() -> QueuedRequest

  /// Creates a queued request to send a generic app event to the backend.
  /// - Parameters:
  ///   - name: The name of the event.
  ///   - score: A numerical score associated with the event.
  ///   - type: The type of the app event (default is `.positive`).
  ///   - metadata: Optional key-value metadata to attach to the event.
  func sendAppEvent(
    name: String,
    score: Int,
    type: AppEventType,
    metadata: [String: String]?
  ) -> QueuedRequest

  /// Creates a queued request to log a prompt-related event.
  /// - Parameters:
  ///   - type: The type of prompt event (e.g., shown, dismissed).
  ///   - previousEventId: The ID of the previous related event.
  ///   - feedbackEventId: Optional ID of a feedback event related to this prompt.
  ///   - metadata: Optional key-value metadata to attach to the event.
  func sendPromptEvent(
    eventType: PromptEventType,
    promptType: PromptType,
    previousEventId: String,
    feedbackEventId: String?,
    metadata: [String: String]?
  ) -> QueuedRequest

  /// Creates a queued request to submit feedback data with comment.
  /// - Parameters:
  ///   - promptEventId: The ID of the related prompt event.
  ///   - comment: Text comment from the user.
  ///   - metadata: Optional key-value metadata.
  func sendFeedbackEvent(
    promptEventId: String,
    comment: String?,
    metadata: [String: String]?
  ) -> QueuedRequest

  /// Executes a queued request against the backend.
  /// - Parameter queuedRequest: The request to execute.
  /// - Returns: The raw `Data` returned from the backend.
  /// - Throws: `QueueFailure` if the request fails.
  func execute(queuedRequest: QueuedRequest) async throws -> Data
}

/// Concrete implementation of `APIClientProtocol` for communicating with the TestimonialKit backend.
///
/// Handles request building, encoding, execution, and error handling.
final class APIClient: APIClientProtocol {
  /// The configuration object containing API keys, user identifiers, and other SDK settings.
  private let config: TestimonialKitConfig

  /// Creates a new API client instance.
  /// - Parameter config: The SDK configuration to use for all requests.
  init(
    config: TestimonialKitConfig
  ) {
    self.config = config
  }

  /// Concrete implementation of `initSdk()`.
  /// Creates a queued request to initialize the SDK with required configuration details.
  func initSdk() -> QueuedRequest {
    let body = [
      "userId": config.userId,
      "sdkVersion": config.sdkVersion,
      "appVersion": config.appVersion,
      "countryCode": config.countryCode
    ]

    return QueuedRequest(
      eventType: .initSdk,
      method: "POST",
      path: Endpoints.initialization,
      headers: [
        Headers.apiKey.rawValue: config.apiKey,
        Headers.bundleId.rawValue: config.bundleId,
        Headers.platform.rawValue: config.platform,
        Headers.sessionId.rawValue: config.sessionId.uuidString,
        Headers.contentType.rawValue: "application/json"
      ],
      body: try? JSONSerialization.data(withJSONObject: body, options: [])
    )
  }

  /// Concrete implementation of `checkPromptEligibility()`.
  /// Creates a queued request to check if a prompt should be displayed to the user.
  func checkPromptEligibility() -> QueuedRequest {
    let body: [String: Any] = [
      "appVersion": config.appVersion,
      "userId": config.userId,
      "locale": config.countryCode,
      "userTime": [
        "hour": Calendar.current.component(.hour, from: Date()),
        "weekday": mondayZeroWeekdayIndex(for: Date())
      ]
    ]

    return QueuedRequest(
      eventType: .checkPromptEligibility,
      method: "POST",
      path: Endpoints.promptEligibility,
      headers: [
        Headers.apiKey.rawValue: config.apiKey,
        Headers.bundleId.rawValue: config.bundleId,
        Headers.platform.rawValue: config.platform,
        Headers.sessionId.rawValue: config.sessionId.uuidString,
        Headers.contentType.rawValue: "application/json"
      ],
      body: try? JSONSerialization.data(withJSONObject: body, options: [])
    )
  }

  /// Concrete implementation of `sendAppEvent(...)`.
  /// Creates a queued request to send a generic app event to the backend.
  /// - Parameters:
  ///   - name: The name of the event.
  ///   - score: A numerical score associated with the event.
  ///   - type: The type of the app event (default is `.positive`).
  ///   - metadata: Optional key-value metadata to attach to the event.
  func sendAppEvent(
    name: String,
    score: Int,
    type: AppEventType = .positive,
    metadata: [String: String]? = nil
  ) -> QueuedRequest {
    var body: [String: Any] = [
      "appVersion": config.appVersion,
      "userId": config.userId,
      "eventName": name,
      "score": score,
      "type": type.rawValue
    ]

    if let metadata {
      body["metadata"] = metadata
    }

    return QueuedRequest(
      eventType: .sendEvent,
      method: "POST",
      path: Endpoints.projectEvents,
      headers: [
        Headers.apiKey.rawValue: config.apiKey,
        Headers.bundleId.rawValue: config.bundleId,
        Headers.platform.rawValue: config.platform,
        Headers.sessionId.rawValue: config.sessionId.uuidString,
        Headers.contentType.rawValue: "application/json"
      ],
      body: try? JSONSerialization.data(withJSONObject: body, options: [])
    )
  }

  /// Concrete implementation of `sendPromptEvent(...)`.
  /// Creates a queued request to log a prompt-related event.
  /// - Parameters:
  ///   - type: The type of prompt event (e.g., shown, dismissed).
  ///   - previousEventId: The ID of the previous related event.
  ///   - feedbackEventId: Optional ID of a feedback event related to this prompt.
  ///   - metadata: Optional key-value metadata to attach to the event.
  func sendPromptEvent(
    eventType: PromptEventType,
    promptType: PromptType,
    previousEventId: String,
    feedbackEventId: String? = nil,
    metadata: [String: String]? = nil
  ) -> QueuedRequest {
    var body: [String: Any] = [
      "userId": config.userId,
      "status": eventType.rawValue,
      "type": promptType.rawValue,
      "previousEventId": previousEventId,
      "appVersion": config.appVersion
    ]

    if let feedbackEventId {
      body["feedbackEventId"] = feedbackEventId
    }

    if let metadata {
      body["metadata"] = metadata
    }

    return QueuedRequest(
      eventType: .sendPromptEvent,
      method: "POST",
      path: Endpoints.promptEvents,
      headers: [
        Headers.apiKey.rawValue: config.apiKey,
        Headers.bundleId.rawValue: config.bundleId,
        Headers.platform.rawValue: config.platform,
        Headers.sessionId.rawValue: config.sessionId.uuidString,
        Headers.contentType.rawValue: "application/json"
      ],
      body: try? JSONSerialization.data(withJSONObject: body, options: []),
      metadata: [
        "eventType": eventType.rawValue,
        "promptType": promptType.rawValue
      ]
    )
  }

  /// Concrete implementation of `sendFeedbackEvent(...)`.
  /// Creates a queued request to submit feedback data with comment.
  /// - Parameters:
  ///   - promptEventId: The ID of the related prompt event.
  ///   - comment: Optional text comment from the user.
  ///   - metadata: Optional key-value metadata.
  func sendFeedbackEvent(
    promptEventId: String,
    comment: String? = nil,
    metadata: [String: String]? = nil
  ) -> QueuedRequest {
    var body: [String: Any] = [
      "userId": config.userId,
      "promptEventId": promptEventId,
      "appVersion": config.appVersion
    ]

    // Only include comment if it's not nil or empty
    if let comment, !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      body["comment"] = comment
    }

    if let metadata {
      body["metadata"] = metadata
    }

    return QueuedRequest(
      eventType: .sendFeedbackEvent,
      method: "POST",
      path: Endpoints.feedback,
      headers: [
        Headers.apiKey.rawValue: config.apiKey,
        Headers.bundleId.rawValue: config.bundleId,
        Headers.platform.rawValue: config.platform,
        Headers.sessionId.rawValue: config.sessionId.uuidString,
        Headers.contentType.rawValue: "application/json"
      ],
      body: try? JSONSerialization.data(withJSONObject: body, options: [])
    )
  }

  /// Concrete implementation of `execute(queuedRequest:)`.
  /// Executes a queued request against the backend.
  /// - Parameter queuedRequest: The request to execute.
  /// - Returns: The raw `Data` returned from the backend.
  /// - Throws: `QueueFailure` if the request fails.
  func execute(queuedRequest: QueuedRequest) async throws -> Data {
    var request = buildRequest(to: queuedRequest.path)
    request.httpMethod = queuedRequest.method
    queuedRequest.headers.forEach { key, value in
      request.addValue(value, forHTTPHeaderField: key)
    }

    if let body = queuedRequest.body {
      request.httpBody = body
    }

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        throw QueueFailure(NSError(domain: "HTTPError", code: http.statusCode),
                           url: response.url, status: http.statusCode, payload: data)
      }
      return data
    } catch {
      if let urlErr = error as? URLError {
        throw QueueFailure(urlErr, code: urlErr.errorCode, url: request.url)
      } else {
        throw QueueFailure(error, url: request.url)
      }
    }
  }

  /// Builds a `URLRequest` for the given API path.
  /// - Parameter path: The API endpoint path.
  /// - Returns: A `URLRequest` targeting the full API URL.
  func buildRequest(to path: String) -> URLRequest {
    let url = Constants
      .baseUrl
      .appendingPathComponent("/api")
      .appendingPathComponent("/\(Constants.apiVersion)")
      .appendingPathComponent(path)

    return buildRequest(to: url)
  }

  /// Builds a `URLRequest` for the given full URL.
  /// - Parameter url: The target URL.
  /// - Returns: A `URLRequest` for the given URL.
  func buildRequest(to url: URL) -> URLRequest {
    return URLRequest(url: url)
  }

  /// Builds `URLComponents` for the given API path.
  /// - Parameter path: The API endpoint path.
  /// - Returns: A `URLComponents` object representing the full API URL.
  func buildComponents(with path: String) -> URLComponents {
    let url = Constants
      .baseUrl
      .appendingPathComponent("/api")
      .appendingPathComponent("/\(Constants.apiVersion)")
      .appendingPathComponent(path)

    return URLComponents(url: url, resolvingAgainstBaseURL: false)!
  }

  /// Returns the weekday index for the given date, with Monday as zero.
  /// - Parameter date: The date to evaluate.
  /// - Returns: An integer from 0 (Monday) to 6 (Sunday).
  private func mondayZeroWeekdayIndex(for date: Date) -> Int {
    let iso = Calendar(identifier: .iso8601)
    return iso.component(.weekday, from: date) - 1
  }
}
