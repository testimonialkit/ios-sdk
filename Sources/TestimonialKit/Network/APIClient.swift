import Foundation

protocol APIClientProtocol: AnyObject {
  func initSdk() -> QueuedRequest

  func checkPromptEligibility() -> QueuedRequest

  func sendAppEvent(
    name: String,
    score: Int,
    type: AppEventType,
    metadata: [String: String]?
  ) -> QueuedRequest

  func sendPromptEvent(
    type: PromptEventType,
    previousEventId: String,
    feedbackEventId: String?,
    metadata: [String: String]?
  ) -> QueuedRequest

  func sendFeedbackEvent(
    promptEventId: String,
    rating: Int,
    comment: String?,
    metadata: [String: String]?
  ) -> QueuedRequest

  func sendFeedbackComment(comment: String?, feedbackEventId: String) -> QueuedRequest

  func execute(queuedRequest: QueuedRequest) async throws -> Data
}

class APIClient: APIClientProtocol {
  private let config: TestimonialKitConfig

  init(
    config: TestimonialKitConfig
  ) {
    self.config = config
  }

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
        Headers.contentType.rawValue: "application/json"
      ],
      body: try? JSONSerialization.data(withJSONObject: body, options: [])
    )
  }

  func checkPromptEligibility() -> QueuedRequest {
    var body: [String: Any] = [
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
        Headers.contentType.rawValue: "application/json"
      ],
      body: try? JSONSerialization.data(withJSONObject: body, options: [])
    )
  }

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
        Headers.contentType.rawValue: "application/json"
      ],
      body: try? JSONSerialization.data(withJSONObject: body, options: [])
    )
  }

  func sendPromptEvent(
    type: PromptEventType,
    previousEventId: String,
    feedbackEventId: String? = nil,
    metadata: [String: String]? = nil
  ) -> QueuedRequest {
    var body: [String: Any] = [
      "userId": config.userId,
      "status": type.rawValue,
      "previousEventId": previousEventId,
      "appVersion": config.appVersion,
      "feedbackEventId": feedbackEventId
    ]

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
        Headers.contentType.rawValue: "application/json"
      ],
      body: try? JSONSerialization.data(withJSONObject: body, options: []),
      metadata: [
        "eventType": type.rawValue
      ]
    )
  }

  func sendFeedbackEvent(
    promptEventId: String,
    rating: Int,
    comment: String? = nil,
    metadata: [String: String]? = nil
  ) -> QueuedRequest {
    var body: [String: Any] = [
      "userId": config.userId,
      "rating": rating,
      "promptEventId": promptEventId,
      "comment": comment,
      "appVersion": config.appVersion
    ]

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
        Headers.contentType.rawValue: "application/json"
      ],
      body: try? JSONSerialization.data(withJSONObject: body, options: [])
    )
  }

  func sendFeedbackComment(comment: String?, feedbackEventId: String) -> QueuedRequest {
    var body: [String: Any] = [
      "comment": comment,
      "feedbackEventId": feedbackEventId
    ]

    return QueuedRequest(
      eventType: .sendFeedbackComment,
      method: "PUT",
      path: Endpoints.feedback,
      headers: [
        Headers.apiKey.rawValue: config.apiKey,
        Headers.bundleId.rawValue: config.bundleId,
        Headers.platform.rawValue: config.platform,
        Headers.contentType.rawValue: "application/json"
      ],
      body: try? JSONSerialization.data(withJSONObject: body, options: [])
    )
  }

  func execute(queuedRequest: QueuedRequest) async throws -> Data {
    var request = buildRequest(to: queuedRequest.path)
    request.httpMethod = queuedRequest.method
    queuedRequest.headers.forEach { key, value in
      request.addValue(value, forHTTPHeaderField: key)
    }

    if let body = queuedRequest.body {
      request.httpBody = body
    }

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw TestimonialKitError.networkError("Invalid response type")
    }

    if (200...299).contains(httpResponse.statusCode) {
      return data
    } else {
      do {
        let errorResponse = try JSONDecoder().decode(SDKErrorResponse.self, from: data)
        throw TestimonialKitError.networkError(errorResponse.message)
      } catch {
        // fallback to status code if error response cannot be parsed
        throw TestimonialKitError.networkError("Request failed with status code \(httpResponse.statusCode)")
      }
    }
  }

  func buildRequest(to path: String) -> URLRequest {
    let url = Constants
      .baseUrl
      .appendingPathComponent("/api")
      .appendingPathComponent("/\(Constants.apiVersion)")
      .appendingPathComponent(path)

    return buildRequest(to: url)
  }

  func buildRequest(to url: URL) -> URLRequest {
    return URLRequest(url: url)
  }

  func buildComponents(with path: String) -> URLComponents {
    let url = Constants
      .baseUrl
      .appendingPathComponent("/api")
      .appendingPathComponent("/\(Constants.apiVersion)")
      .appendingPathComponent(path)

    return URLComponents(url: url, resolvingAgainstBaseURL: false)!
  }

  private func mondayZeroWeekdayIndex(for date: Date) -> Int {
    let iso = Calendar(identifier: .iso8601)
    return iso.component(.weekday, from: date) - 1
  }
}
