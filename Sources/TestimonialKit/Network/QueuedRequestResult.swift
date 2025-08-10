import Foundation

struct QueuedRequestResult: Sendable {
  let eventType: APIEventType
  let result: Result<Data, Error> // or you can use Decodable generic if needed
  var metadata: [String: String]? = nil
}
