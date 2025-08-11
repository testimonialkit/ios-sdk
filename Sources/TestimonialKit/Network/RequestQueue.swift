import Foundation
@preconcurrency import Combine

actor RequestQueue {
  nonisolated var debugId: String { String(UInt(bitPattern: ObjectIdentifier(self))) }
  private var queue: [QueuedRequest] = []
  private var isProcessing = false
  private let saveURL: URL
  private let maxRetries = 3
  private let baseBackoff: TimeInterval = 0.8

  private var subs: [UUID: AsyncStream<QueuedRequestResult>.Continuation] = [:]

  init(filename: String = "queued_requests.json") {
    self.saveURL = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(filename)

    if let data = try? Data(contentsOf: saveURL),
       let loaded = try? JSONDecoder().decode([QueuedRequest].self, from: data) {
      self.queue = loaded
    }
  }

  func configure() async {
    await processNextIfNeeded()
  }

  // Each caller gets their own stream
  func subscribe() -> AsyncStream<QueuedRequestResult> {
    let id = UUID()
    let (stream, cont) = AsyncStream<QueuedRequestResult>.makeStream(bufferingPolicy: .unbounded)

    subs[id] = cont
    cont.onTermination = { [weak self] _ in
      Task { await self?.removeSub(id) } // hop back to actor to mutate subs
    }

    return stream
  }

  private func removeSub(_ id: UUID) {
    subs.removeValue(forKey: id)
  }

  func enqueue(_ request: QueuedRequest) async {
    print("RequestQueue \(debugId) enqueue:", request.eventType)
    await queue.append(request)
    await saveQueue()
    await processNextIfNeeded()
  }

  func enqueue(_ builder: @escaping @Sendable () -> QueuedRequest) async {
    await self.enqueue(builder())
  }

  // MARK: Internals

  private func emit(_ value: QueuedRequestResult) {
    for (_, cont) in subs {
      cont.yield(value)
    }
  }

  private func processNextIfNeeded(isRetrying: Bool = false) async {
    guard !isProcessing, !queue.isEmpty else { return }

    isProcessing = true
    let next = queue.removeFirst()
    await saveQueue()

    do {
      let data = try await next.execute()
      if !isRetrying {
        await emit(.init(eventType: next.eventType, result: .success(data)))
      }
      await finish(next: next, error: nil)
    } catch {
      if !isRetrying {
        if let error = error as? QueueFailure {
          await emit(.init(eventType: next.eventType, result: .failure(error)))
        } else {
          await emit(.init(eventType: next.eventType, result: .failure(.init(error))))
        }
      }
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
    await processNextIfNeeded(isRetrying: true) // IMPORTANT: restart processing after delayed insert
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
