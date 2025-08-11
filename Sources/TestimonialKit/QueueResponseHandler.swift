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
      if case .success(let success) = result {
        let manager = resolve(\.testimonialKitManager)
        let config = resolve(\.configuration)
        Storage.internalUserId = success.userId
        Storage.requestCommentOnPositiveRating = success.requestCommentOnPositiveRating
        config.userId = success.userId
        print("★ TestimonialKit initialized successfully ★")
      } else {
        print("★ Failed to initialize TestimonialKit ★")
      }
    case .sendEvent(let result):
      if case .success(let success) = result {
        print("★ Event sent:", success.message, "★")
      } else {
        print("Faith to send event: unknown error")
      }
    default:
      break
    }
  }

  deinit { listenerTask?.cancel() }
}
