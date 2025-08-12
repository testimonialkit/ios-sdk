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
  func promptIfPossible(
    metadata: [String: String]?,
    promptConfig: PromptConfig,
    completion: (@Sendable (PromptResult) -> Void)?
  )
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
    Task { [weak self] in
      let req = self?.apiClient.sendAppEvent(
        name: name,
        score: score,
        type: type,
        metadata: metadata
      )

      guard let req else { return }

      let logMessage = "About to enqueue on \(await self?.requestQueue.debugId) event: \(APIEventType.sendEvent)"
      Logger.shared.verbose(logMessage)
      await self?.requestQueue.enqueue(req)
    }
  }

  func promptIfPossible(
    metadata: [String: String]? = nil,
    promptConfig: PromptConfig,
    completion: (@Sendable (PromptResult) -> Void)? = nil
  ) {
    Task { [weak self] in
      await self?.promptManager.promptForReviewIfPossible(
        metadata: metadata,
        config: promptConfig,
        completion: completion
      )
    }
  }

  private func configure() {
    Task { [weak self] in
      await self?.requestQueue.configure()
      guard let request = self?.apiClient.initSdk() else { return }
      await self?.requestQueue.enqueue(request)
    }
  }
}
