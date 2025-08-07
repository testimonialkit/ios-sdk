import Foundation

struct QueuedRequest: Codable {
  let method: String
  let path: String
  let headers: [String: String]
  let body: Data?
  let eventType: APIEventType
  let metadata: [String: String]?

  init(eventType: APIEventType,
       method: String,
       path: String,
       headers: [String : String] = [:],
       body: Data? = nil,
       metadata: [String: String]? = nil) {
    self.method = method
    self.path = path
    self.headers = headers
    self.body = body
    self.eventType = eventType
    self.metadata = metadata
  }

  func execute() async throws -> Data {
    try await APIClient.shared.execute(queuedRequest: self)
  }
}
