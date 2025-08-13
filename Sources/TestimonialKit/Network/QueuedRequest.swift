import Foundation
import Factory

/// Represents a request that is queued for later execution.
///
/// Contains HTTP method, path, headers, body, and metadata, along with retry count and event type.
/// Conforms to `Codable` for persistence and `Sendable` for safe use across concurrency domains.
struct QueuedRequest: Codable, Sendable {
  /// The HTTP method for the request (e.g., "GET", "POST").
  let method: String
  /// The relative path or endpoint for the request.
  let path: String
  /// HTTP headers to include with the request.
  let headers: [String: String]
  /// Optional HTTP request body as raw data.
  let body: Data?
  /// The type of API event associated with this request.
  let eventType: APIEventType
  /// Optional metadata key-value pairs associated with this request.
  let metadata: [String: String]?
  /// The number of retry attempts that have been made for this request.
  let retryCount: Int

  /// Creates a new queued request.
  ///
  /// - Parameters:
  ///   - eventType: The type of API event associated with this request.
  ///   - method: The HTTP method for the request.
  ///   - path: The relative path or endpoint for the request.
  ///   - headers: HTTP headers to include with the request (default is empty).
  ///   - body: Optional HTTP request body as raw data.
  ///   - metadata: Optional metadata key-value pairs.
  ///   - retryCount: The number of retry attempts so far (default is 0).
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

  /// Executes the queued request using the resolved API client.
  ///
  /// - Returns: The raw `Data` response from the API.
  /// - Throws: An error if the request fails.
  func execute() async throws -> Data {
    let apiClient = resolve(\.apiClient)
    return try await apiClient.execute(queuedRequest: self)
  }

  /// Creates a copy of the queued request, optionally overriding specific properties.
  ///
  /// - Parameters:
  ///   - eventType: Optional new event type.
  ///   - method: Optional new HTTP method.
  ///   - path: Optional new endpoint path.
  ///   - headers: Optional new HTTP headers.
  ///   - body: Optional new request body data.
  ///   - metadata: Optional new metadata key-value pairs.
  ///   - retryCount: Optional new retry count.
  /// - Returns: A new `QueuedRequest` instance with the specified overrides applied.
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
