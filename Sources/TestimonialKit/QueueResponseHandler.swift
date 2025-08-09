import Foundation
import Combine
import Factory

final class QueueResponseHandler {
  @Injected(\.requestQueue) var requestQueue
  private var cancellables = Set<AnyCancellable>()

  init() {
    requestQueue.eventPublisher
      .receive(on: DispatchQueue.main) // or background if needed
      .sink { responseEvent in
        Self.handle(responseEvent)
      }
      .store(in: &cancellables)
  }

  private static func handle(_ event: QueuedRequestResult) {
    switch event.result {
    case .success(let data):
      handleSuccess(data: data, type: event.eventType)
    case .failure(let error):
      print("[TestimonialKit] Request failed:", error)
    }
  }

  private static func handleSuccess(data: Data, type: APIEventType) {
    switch type {
    case .initSdk:
      if let response = try? JSONDecoder().decode(SDKInitResponse.self, from: data) {
        Task { @MainActor in
          let manager = resolve(\.testimonialKitManager)
          let config = resolve(\.configuration)
          Storage.internalUserId = response.userId
          Storage.requestCommentOnPositiveRating = response.requestCommentOnPositiveRating
          config.userId = response.userId
          print("★ TestimonialKit initialized successfully ★")
        }
      }
    case .sendEvent:
      if let response = try? JSONDecoder().decode(AppEventLogResponse.self, from: data) {
        print("★ Event sent:", response.message, "★")
      }
    default:
      break
    }
  }
}
