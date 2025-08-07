import Foundation

struct QueuedRequest: Codable {
  let method: String
  let path: String
  let headers: [String: String]
  let body: Data?
  let eventType: APIEventType
  let metadata: [String: String]?
  let retryCount: Int

  init(eventType: APIEventType,
       method: String,
       path: String,
       headers: [String : String] = [:],
       body: Data? = nil,
       metadata: [String: String]? = nil,
       retryCount: Int = 0) {
    self.method = method
    self.path = path
    self.headers = headers
    self.body = body
    self.eventType = eventType
    self.metadata = metadata
    self.retryCount = retryCount
  }

  func execute() async throws -> Data {
    try await APIClient.shared.execute(queuedRequest: self)
  }

  func copy(
    eventType: APIEventType? = nil,
    method: String? = nil,
    path: String? = nil,
    headers: [String: String]? = nil,
    body: Data? = nil,
    metadata: [String: String]? = nil,
    retryCount: Int? = nil
  ) -> QueuedRequest {
    QueuedRequest(
      eventType: eventType ?? self.eventType,
      method: method ?? self.method,
      path: path ?? self.path,
      headers: headers ?? self.headers,
      body: body ?? self.body,
      metadata: metadata ?? self.metadata,
      retryCount: retryCount ?? self.retryCount
    )
  }
}
