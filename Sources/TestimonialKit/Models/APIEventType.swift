enum APIEventType: String, Codable, Sendable {
  case initSdk, sendEvent, checkPromptEligibility, sendPromptEvent, sendFeedbackEvent, sendFeedbackComment
}
