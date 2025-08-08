import Foundation

struct FeedbackEvent {
  let type: FeedbackEventType
  let response: FeedbackLogResponse?
}

enum FeedbackEventType {
  case rating, comment
}
