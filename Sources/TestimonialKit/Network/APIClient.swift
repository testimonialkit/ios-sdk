import Foundation

class APIClient: @unchecked Sendable {
  static let shared = APIClient()
  private init() {}

  func initSdk(
    config: TestimonialKitConfig
  ) -> QueuedRequest {
    let body = [
      "userId": config.userId,
      "sdkVersion": config.sdkVersion,
      "appVersion": config.appVersion,
      "countryCode": config.countryCode
    ]

    return QueuedRequest(
      eventType: .initSdk,
      method: "POST",
      path: "/sdk/init",
      headers: [
        Headers.apiKey.rawValue: config.apiKey,
        Headers.bundleId.rawValue: config.bundleId,
        Headers.platform.rawValue: config.platform,
        Headers.contentType.rawValue: "application/json"
      ],
      body: try? JSONSerialization.data(withJSONObject: body, options: [])
    )
  }

  func checkPromptEligibility(
    config: TestimonialKitConfig,
  ) -> QueuedRequest {
    var body: [String: Any] = [
      "appVersion": config.appVersion,
      "userId": config.userId,
      "locale": config.countryCode,
      "userTime": [
        "hour": Calendar.current.component(.hour, from: Date()),
        "weekday": Calendar.current.component(.weekday, from: Date())
      ]
    ]

    return QueuedRequest(
      eventType: .checkPromptEligibility,
      method: "POST",
      path: "/sdk/should-prompt",
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
    metadata: [String: String]? = nil,
    config: TestimonialKitConfig,
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
      path: "/sdk/project-events",
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
    config: TestimonialKitConfig,
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
      path: "/sdk/prompt-events",
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
    metadata: [String: String]? = nil,
    config: TestimonialKitConfig
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
      path: "/sdk/feedback",
      headers: [
        Headers.apiKey.rawValue: config.apiKey,
        Headers.bundleId.rawValue: config.bundleId,
        Headers.platform.rawValue: config.platform,
        Headers.contentType.rawValue: "application/json"
      ],
      body: try? JSONSerialization.data(withJSONObject: body, options: [])
    )
  }

  func sendFeedbackComment(comment: String?, feedbackEventId: String, config: TestimonialKitConfig) -> QueuedRequest {
    var body: [String: Any] = [
      "comment": comment,
      "feedbackEventId": feedbackEventId
    ]

    return QueuedRequest(
      eventType: .sendFeedbackComment,
      method: "PUT",
      path: "/sdk/feedback",
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
}
