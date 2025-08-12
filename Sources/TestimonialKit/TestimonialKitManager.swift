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
  private let requestQueue: RequestQueue
  private let config: TestimonialKitConfig
  private let responseHandler = QueueResponseHandler()

  init(
    promptManager: PromptManagerProtocol,
    requestQueue: RequestQueue,
    configuration: TestimonialKitConfig
  ) {
    self.promptManager = promptManager
    self.requestQueue = requestQueue
    self.config = configuration
  }

  func setup(with apiKey: String) {
    config.apiKey = apiKey
    configure()
  }

  func trackEvent(
    name: String,
    score: Int,
    type: AppEventType = .positive,
    metadata: [String: String]? = nil
  ) {
    Task {
      let req = apiClient.sendAppEvent(
          name: name,
          score: score,
          type: type,
          metadata: metadata
        )

      let logMessage = "About to enqueue on \(await requestQueue.debugId) event: \(APIEventType.sendEvent)"
      Logger.shared.verbose(logMessage)
      await requestQueue.enqueue(req)
    }
  }

  func promptIfPossible(metadata: [String: String]? = nil, promptConfig: PromptConfig) {
    promptManager.promptForReviewIfPossible(metadata: metadata, config: promptConfig)
  }

  private func configure() {
    Task {
      await requestQueue.configure()
      await requestQueue.enqueue(
        apiClient.initSdk()
      )
    }
  }
}
