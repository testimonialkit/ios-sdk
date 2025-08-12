import Foundation

struct FeedbackEvent: Sendable {
  let type: FeedbackEventType
  var response: FeedbackLogResponse? = nil
}

enum FeedbackEventType: Sendable {
  case rating(data: FeedbackLogResponse)
  case comment(data: FeedbackLogResponse)
  case error
}
