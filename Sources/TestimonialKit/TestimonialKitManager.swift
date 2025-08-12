import SwiftUI
import Factory

/// Defines the public interface for managing TestimonialKit SDK operations.
///
/// Implementations coordinate setup, event tracking, and presentation of the
/// in‑app feedback prompt, all on the main actor.
@MainActor
protocol TestimonialKitManagerProtocol: AnyObject {
  /// Initializes the manager with the given API key and triggers any necessary configuration.
  /// - Parameter apiKey: The project API key used to authenticate requests.
  func setup(with apiKey: String)
  /// Enqueues an application event to be sent to the backend.
  /// - Parameters:
  ///   - name: A domain‑specific name for the event.
  ///   - score: A numeric score representing the event’s significance.
  ///   - type: The sentiment or category of the event (positive/negative/etc.).
  ///   - metadata: Optional custom key–value pairs providing additional context.
  func trackEvent(
    name: String,
    score: Int,
    type: AppEventType,
    metadata: [String: String]?
  )
  /// Checks eligibility and, if allowed, presents the in‑app feedback prompt.
  /// - Parameters:
  ///   - metadata: Optional metadata to associate with the prompt session.
  ///   - promptConfig: UI and text configuration for the prompt.
  ///   - completion: Optional closure invoked with the result after dismissal.
  func promptIfPossible(
    metadata: [String: String]?,
    promptConfig: PromptConfig,
    completion: (@Sendable (PromptResult) -> Void)?
  )
}

@MainActor
/// Default implementation of `TestimonialKitManagerProtocol`.
///
/// Coordinates API requests, manages the prompt lifecycle via `PromptManagerProtocol`,
/// and interacts with a `RequestQueue` to ensure reliable delivery of events.
class TestimonialKitManager: TestimonialKitManagerProtocol {
  /// Injected API client used to build and send backend requests.
  @Injected(\.apiClient) var apiClient
  /// Component responsible for handling prompt presentation and related state.
  private let promptManager: PromptManagerProtocol
  /// Queue that serializes and retries API requests until successful.
  private let requestQueue: RequestQueue
  /// Shared SDK configuration containing API key, user info, and environment details.
  private let config: TestimonialKitConfig
  /// Handles decoding and applying results emitted by the `RequestQueue`.
  private let responseHandler = QueueResponseHandler()

  /// Creates a new `TestimonialKitManager`.
  /// - Parameters:
  ///   - promptManager: Manager responsible for feedback prompt presentation.
  ///   - requestQueue: Queue for enqueuing and processing API requests.
  ///   - configuration: SDK configuration object.
  init(
    promptManager: PromptManagerProtocol,
    requestQueue: RequestQueue,
    configuration: TestimonialKitConfig
  ) {
    self.promptManager = promptManager
    self.requestQueue = requestQueue
    self.config = configuration
  }

  /// Stores the API key in configuration and triggers SDK configuration.
  /// - Parameter apiKey: The project API key.
  func setup(with apiKey: String) {
    config.apiKey = apiKey
    configure()
  }

  /// Asynchronously enqueues an application event for backend processing.
  /// Builds the request, logs it, and adds it to the `requestQueue`.
  /// - Parameters:
  ///   - name: The event name.
  ///   - score: The event score.
  ///   - type: Sentiment/category of the event (default `.positive`).
  ///   - metadata: Optional metadata.
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

  /// Forwards the prompt request to `promptManager` to check eligibility and possibly present the prompt.
  /// - Parameters:
  ///   - metadata: Optional session metadata.
  ///   - promptConfig: Prompt appearance/text configuration.
  ///   - completion: Optional callback with the prompt result.
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

  /// Configures the request queue and enqueues the SDK initialization request.
  private func configure() {
    Task { [weak self] in
      await self?.requestQueue.configure()
      guard let request = self?.apiClient.initSdk() else { return }
      await self?.requestQueue.enqueue(request)
    }
  }
}
