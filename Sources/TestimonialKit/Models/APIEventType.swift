enum APIEventType: String, Codable {
  case initSdk, sendEvent, checkPromptEligibility, sendPromptEvent, sendFeedbackEvent, sendFeedbackComment
}
