import SwiftUI
import Factory

@MainActor
protocol TestimonialKitManagerProtocol: AnyObject {
  func setup(with apiKey: String)
  func trackEvent(
    name: String,
    score: Int,
    type: AppEventType,
    metadata: [String: String]?
  )
  func promptIfPossible(metadata: [String: String]?, promptConfig: PromptConfig)
}

@MainActor
class TestimonialKitManager: TestimonialKitManagerProtocol {
  @Injected(\.apiClient) var apiClient
  private let promptManager: PromptManagerProtocol
  private let requestQueue: RequestQueueProtocol
  private let config: TestimonialKitConfig
  private let responseHandler = QueueResponseHandler()

  init(
    promptManager: PromptManagerProtocol,
    requestQueue: RequestQueueProtocol,
    configuration: TestimonialKitConfig
  ) {
    self.promptManager = promptManager
    self.requestQueue = requestQueue
    self.config = configuration
  }

  func setup(with apiKey: String) {
    config.apiKey = apiKey
    configure(config: config)
    requestQueue.enqueue(
      apiClient.initSdk()
    )
  }

  func trackEvent(
    name: String,
    score: Int,
    type: AppEventType = .positive,
    metadata: [String: String]? = nil
  ) {
    requestQueue.enqueue(
      apiClient.sendAppEvent(
        name: name,
        score: score,
        type: type,
        metadata: metadata
      )
    )
  }

  func promptIfPossible(metadata: [String: String]? = nil, promptConfig: PromptConfig) {
    promptManager.promptForReviewIfPossible(metadata: metadata, config: promptConfig)
  }

  private func configure(config: TestimonialKitConfig) {
    requestQueue.configure(config: config)
  }
}
