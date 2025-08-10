import Foundation
@preconcurrency import Combine
import Factory

@MainActor
final class QueueResponseHandler {
  @Injected(\.requestQueue) var requestQueue
  private var cancellables = Set<AnyCancellable>()

  init() {
    startListening()
  }

  private func startListening() {
    requestQueue.publisher
      .receive(on: requestQueue.decodingQueue) // or background if needed
      .compactMap { event -> DecodedQueueEvent? in
        switch event.eventType {
        case .initSdk:
          switch event.result {
          case .success(let data):
            if let response = try? JSONDecoder().decode(SDKInitResponse.self, from: data) {
              return .initSdk(.success(response))
            } else {
              return .initSdk(.failure(TestimonialKitError.parsingError("Failed to parse SDK init response")))
            }
          case .failure(let error):
            return .initSdk(.failure(error))
          }
        case .sendEvent:
          switch event.result {
          case .success(let data):
            if let response = try? JSONDecoder().decode(AppEventLogResponse.self, from: data) {
              return .sendEvent(.success(response))
            } else {
              return .sendEvent(.failure(TestimonialKitError.parsingError("Faield to parse event response")))
            }
          case .failure(let error):
            return .sendEvent(.failure(error))
          }
        default:
          return .none
        }
      }
      .sink { [weak self] decoded in
        guard let self else { return }
        Task { @MainActor in
          self.apply(decoded)
        }
      }
      .store(in: &cancellables)
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
}
