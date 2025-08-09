import Foundation
import Combine

protocol RequestQueueProtocol: AnyObject {
  var eventPublisher: PassthroughSubject<QueuedRequestResult, Never> { get }

  func configure(config: TestimonialKitConfig)
  func enqueue(_ request: QueuedRequest)
}

final class RequestQueue: @unchecked Sendable, RequestQueueProtocol {
  private var queue: [QueuedRequest] = []
  private var isProcessing = false
  private let lock = DispatchQueue(label: "dev.testimonialkit.queue")
  private let saveURL: URL
  private var config: TestimonialKitConfig?

  let eventPublisher = PassthroughSubject<QueuedRequestResult, Never>()

  init() {
    let filename = "queued_requests.json"
    saveURL = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(filename)
    loadQueueFromDisk()
  }

  func configure(config: TestimonialKitConfig) {
    self.config = config
    lock.async {
      self.processNextIfNeeded()
    }
  }

  func enqueue(_ request: QueuedRequest) {
    lock.async {
      self.queue.append(request)
      self.saveQueueToDisk()
      self.processNextIfNeeded()
    }
  }

  private func processNextIfNeeded() {
    guard !isProcessing, !queue.isEmpty, let config else { return }

    isProcessing = true
    let nextRequest = queue.removeFirst()
    saveQueueToDisk()

    Task { [weak self] in
      guard let self else { return }

      do {
        let result = try await nextRequest.execute()
        eventPublisher.send(
          QueuedRequestResult(
            eventType: nextRequest.eventType,
            result: .success(result),
            metadata: nextRequest.metadata
          )
        )
      } catch {
        eventPublisher.send(
          QueuedRequestResult(
            eventType: nextRequest.eventType,
            result: .failure(error),
            metadata: nextRequest.metadata
          )
        )

        // Check retry limit
        if nextRequest.retryCount < config.retryCount {
          let retryRequest = nextRequest.copy(
            retryCount: nextRequest.retryCount + 1,
          )
          self.queue.insert(retryRequest, at: 0)
          self.saveQueueToDisk()
        }
      }

      self.isProcessing = false
      self.processNextIfNeeded()
    }
  }

  private func saveQueueToDisk() {
    DispatchQueue.global(qos: .background).async { [weak self] in
      guard let self else { return }
      if let data = try? JSONEncoder().encode(self.queue) {
        try? data.write(to: self.saveURL)
      }
    }
  }

  private func loadQueueFromDisk() {
    guard let data = try? Data(contentsOf: saveURL),
          let loaded = try? JSONDecoder().decode([QueuedRequest].self, from: data)
    else { return }

    self.queue = loaded
  }
}
