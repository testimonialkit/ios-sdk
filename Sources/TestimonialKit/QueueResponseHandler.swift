import Foundation
@preconcurrency import Combine
import Factory

@MainActor
final class QueueResponseHandler {
  @Injected(\.requestQueue) var requestQueue
  private var cancellables = Set<AnyCancellable>()
  private var listenerTask: Task<Void, Never>?

  init() {
    listenerTask = Task {
      let stream = await self.requestQueue.subscribe()
      for await event in stream {
        // decode on background if you want
        let decoded: DecodedQueueEvent = await withCheckedContinuation { cont in
          DispatchQueue.global(qos: .utility).async {
            cont.resume(returning: self.decode(event))
          }
        }
        await self.apply(decoded)  // hop back to @MainActor (self is @MainActor)
      }
    }
  }

  private nonisolated func decode(_ event: QueuedRequestResult) -> DecodedQueueEvent {
    switch event.eventType {
    case .initSdk:
      switch event.result {
      case .success(let data):
        let result = QueueResult { try JSONDecoder().decode(SDKInitResponse.self, from: data) }
        return .initSdk(result)
      case .failure(let error):
        return .initSdk(.failure(error))
      }
    case .sendEvent:
      switch event.result {
      case .success(let data):
        let result = QueueResult { try JSONDecoder().decode(AppEventLogResponse.self, from: data) }
        return .sendEvent(result)
      case .failure(let error):
        return .sendEvent(.failure(error))
      }
    default:
      return .unhadnledEvent(event.eventType.rawValue)
    }
  }

  private func apply(_ event: DecodedQueueEvent) {
    switch event {
    case .initSdk(let result):
      switch result {
      case .success(let success):
        let manager = resolve(\.testimonialKitManager)
        let config = resolve(\.configuration)
        Storage.internalUserId = success.userId
        Storage.requestCommentOnPositiveRating = success.requestCommentOnPositiveRating
        config.userId = success.userId
        Logger.shared.info("★ Initialized successfully ★")
      case .failure(let queueFailure):
        Logger.shared.warning("Failed to initialize: \(queueFailure.errorDescription ?? "unknown error")")
      }
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

  deinit { listenerTask?.cancel() }
}
