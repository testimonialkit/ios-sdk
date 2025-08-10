import Foundation
@preconcurrency import Combine

actor RequestQueue {
  private var queue: [QueuedRequest] = []
  private var isProcessing = false
  private let saveURL: URL
  private let maxRetries = 3
  private let baseBackoff: TimeInterval = 0.8

  let decodingQueue = DispatchQueue(label: "dev.testimonialkit.prompt.manager.decoding", qos: .utility)
  private let subject = PassthroughSubject<QueuedRequestResult, Never>()
  nonisolated let publisher: AnyPublisher<QueuedRequestResult, Never>

  init(filename: String = "queued_requests.json") {
    self.saveURL = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(filename)

    self.publisher = subject.eraseToAnyPublisher()

    if let data = try? Data(contentsOf: saveURL),
       let loaded = try? JSONDecoder().decode([QueuedRequest].self, from: data) {
      self.queue = loaded
    }
  }

  func configure() async {
    await processNextIfNeeded()
  }

  func enqueue(_ request: QueuedRequest) async {
    queue.append(request)
    await saveQueue()
    await processNextIfNeeded()
  }

  // MARK: Internals

  private func emit(_ value: QueuedRequestResult) {
    self.subject.send(value)
  }

  private func processNextIfNeeded() async {
    guard !isProcessing, !queue.isEmpty else { return }

    isProcessing = true
    let next = queue.removeFirst()
    await saveQueue()

    do {
      let data = try await next.execute()
      emit(.init(eventType: next.eventType, result: .success(data), metadata: next.metadata))
      await finish(next: next, error: nil)
    } catch {
      emit(.init(eventType: next.eventType, result: .failure(error), metadata: next.metadata))
      await finish(next: next, error: error)
    }
  }

  private func finish(next: QueuedRequest, error: Error?) async {
    if let _ = error, next.retryCount < maxRetries {
      let attempt = next.retryCount + 1
      let delay = backoff(for: attempt)
      let retry = next.copy(retryCount: attempt)

      // Schedule the retry later so other queued items can run meanwhile.
      Task {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        await self.enqueueFrontAndKick(retry)
      }
    }

    isProcessing = false
    await processNextIfNeeded()
  }

  private func enqueueFrontAndKick(_ request: QueuedRequest) async {
    queue.insert(request, at: 0)
    await saveQueue()
    await processNextIfNeeded() // IMPORTANT: restart processing after delayed insert
  }

  private func backoff(for attempt: Int) -> TimeInterval {
    let expo = pow(2.0, Double(attempt - 1)) * baseBackoff
    let jitter = Double.random(in: 0...(baseBackoff / 2))
    return min(expo + jitter, 20.0)
  }

  private func saveQueue() async {
    let snapshot = self.queue
    let url = self.saveURL
    Task.detached {
      if let data = try? JSONEncoder().encode(snapshot) {
        try? data.write(to: url)
      }
    }
  }
}
