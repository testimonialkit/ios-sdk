import Foundation
import Combine

final class QueueResponseHandler {
  private var cancellables = Set<AnyCancellable>()

  init() {
    RequestQueue.shared.eventPublisher
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
        Storage.internalUserId = response.userId
        Storage.requestCommentOnPositiveRating = response.requestCommentOnPositiveRating
        print("★ TestimonialKit initialized successfully ★")
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
