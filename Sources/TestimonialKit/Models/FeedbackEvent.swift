import Foundation

struct FeedbackEvent {
  let type: FeedbackEventType
  var response: FeedbackLogResponse? = nil
}

enum FeedbackEventType {
  case rating(data: FeedbackLogResponse)
  case comment(data: FeedbackLogResponse)
  case error
}
