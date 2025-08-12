import Foundation
@preconcurrency import Combine
import Factory

/// Listens to the `RequestQueue` event stream, decodes raw results off the main thread,
/// and applies side effects on the main actor (updating storage, config and logging).
///
/// The handler spins up a long‑lived task that consumes an `AsyncStream` of
/// `QueuedRequestResult` values. Each event is decoded on a background queue using
/// `withCheckedContinuation`, then forwarded back to the main actor for processing.
@MainActor
final class QueueResponseHandler {
  /// Injected request queue that publishes results from enqueued API calls.
  @Injected(\.requestQueue) var requestQueue
  /// Retains Combine subscriptions created by this handler.
  private var cancellables = Set<AnyCancellable>()
  /// Long‑lived task that consumes the queue's async event stream.
  private var listenerTask: Task<Void, Never>?

  /// Starts the background listener task which subscribes to the queue stream,
  /// decodes events on a background queue, and applies them on the main actor.
  init() {
    listenerTask = Task {
      let stream = await self.requestQueue.subscribe()
      for await event in stream {
        /// Decode the raw queue result on a background utility queue using `withCheckedContinuation`.
        let decoded: DecodedQueueEvent = await withCheckedContinuation { cont in
          DispatchQueue.global(qos: .utility).async {
            cont.resume(returning: self.decode(event))
          }
        }
        /// Switch back to the main actor (this type is `@MainActor`) to perform UI‑adjacent side effects.
        await self.apply(decoded)
      }
    }
  }

  /// Transforms a raw `QueuedRequestResult` into a typed `DecodedQueueEvent`.
  ///
  /// This method is marked `nonisolated` so it can safely run off the main actor; it does not
  /// access actor‑isolated state. JSON decoding failures are captured inside `QueueResult`.
  /// - Parameter event: The raw result emitted by `RequestQueue`.
  /// - Returns: A typed `DecodedQueueEvent` representing the decoded payload or failure.
  private nonisolated func decode(_ event: QueuedRequestResult) -> DecodedQueueEvent {
    /// SDK initialization response (sets up user/session state on success).
    switch event.eventType {
    case .initSdk:
      switch event.result {
      case .success(let data):
        let result = QueueResult { try JSONDecoder().decode(SDKInitResponse.self, from: data) }
        return .initSdk(result)
      case .failure(let error):
        return .initSdk(.failure(error))
      }
    /// App/client event logging response.
    case .sendEvent:
      switch event.result {
      case .success(let data):
        let result = QueueResult { try JSONDecoder().decode(AppEventLogResponse.self, from: data) }
        return .sendEvent(result)
      case .failure(let error):
        return .sendEvent(.failure(error))
      }
    /// Any event types not explicitly handled are forwarded as `.unhadnledEvent`.
    default:
      return .unhadnledEvent(event.eventType.rawValue)
    }
  }

  /// Applies a decoded queue event on the main actor: updates in‑memory storage, configuration,
  /// and emits logs. Errors are logged with a concise description.
  /// - Parameter event: A previously decoded queue event.
  private func apply(_ event: DecodedQueueEvent) {
    /// Handle SDK initialization lifecycle.
    switch event {
    case .initSdk(let result):
      switch result {
      case .success(let success):
        let manager = resolve(\.testimonialKitManager)
        let config = resolve(\.configuration)
        Storage.internalUserId = success.userId
        Storage.requestCommentOnPositiveRating = success.requestCommentOnPositiveRating
        config.userId = success.userId
        config.hasActiveSubscription = success.hasActiveSubscription
        Logger.shared.info("★ Initialized successfully ★")
      case .failure(let queueFailure):
        Logger.shared.warning("Failed to initialize: \(queueFailure.errorDescription ?? "unknown error")")
      }
    /// Handle responses for client/app events pushed to the backend.
    case .sendEvent(let result):
      switch result {
      case .success(let success):
        Logger.shared.debug("Event sent: \(success.message)")
      case .failure(let queueFailure):
        Logger.shared.debug("Faith to send event: \(queueFailure.errorDescription ?? "unknown error")")
      }
    default:
      break
    }
  }

  /// Cancels the long‑lived listener task on deallocation to stop consuming the stream.
  deinit { listenerTask?.cancel() }
}
