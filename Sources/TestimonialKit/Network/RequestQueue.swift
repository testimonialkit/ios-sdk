import Foundation
@preconcurrency import Combine

/// An actor that manages a queue of `QueuedRequest` instances, processing them sequentially
/// with retry logic, persistence to disk, and subscriber notifications.
///
/// Supports retry with exponential backoff and jitter, persistence between app launches,
/// and multiple subscribers via `AsyncStream` to receive request results.
actor RequestQueue {
  /// A debug identifier for the request queue instance, derived from its memory address.
  /// Accessible from nonisolated contexts.
  nonisolated var debugId: String { String(UInt(bitPattern: ObjectIdentifier(self))) }

  /// In-memory queue of pending requests to be executed.
  /// Restored from disk on initialization and updated after each enqueue/dequeue.
  private var queue: [QueuedRequest] = []
  /// Flag indicating whether the queue is currently processing a request.
  private var isProcessing = false

  /// File URL where the queue is persisted as JSON.
  private let saveURL: URL

  /// Maximum number of retry attempts for failed requests.
  private let maxRetries = 3

  /// Base time interval (in seconds) used for exponential backoff between retries.
  private let baseBackoff: TimeInterval = 0.8

  /// Active subscriber continuations keyed by their UUID identifiers.
  /// Subscribers receive `QueuedRequestResult` events as requests complete.
  private var subs: [UUID: AsyncStream<QueuedRequestResult>.Continuation] = [:]

  /// Creates a new request queue and loads any previously persisted requests from disk.
  /// - Parameter filename: The filename to use for persisting queued requests.
  init(filename: String = "queued_requests.json") {
    self.saveURL = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(filename)

    if let data = try? Data(contentsOf: saveURL),
       let loaded = try? JSONDecoder().decode([QueuedRequest].self, from: data) {
      self.queue = loaded
    }
  }

  /// Prepares the queue for processing by attempting to process the next request if available.
  func configure() async {
    await processNextIfNeeded()
  }

  /// Creates a new asynchronous stream for receiving request results from the queue.
  /// - Returns: An `AsyncStream` of `QueuedRequestResult` values.
  /// Each subscriber is independent and receives results for all processed requests.
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

  /// Removes a subscriber from the active list.
  /// - Parameter id: The UUID of the subscriber to remove.
  private func removeSub(_ id: UUID) {
    subs.removeValue(forKey: id)
  }

  /// Adds a request to the queue and begins processing if not already running.
  /// - Parameter request: The request to enqueue.
  func enqueue(_ request: QueuedRequest) async {
    Logger.shared.verbose("RequestQueue \(debugId) enqueue: \(request.eventType)")
    await queue.append(request)
    await saveQueue()
    await processNextIfNeeded()
  }

  /// Adds a request to the queue using a builder closure, then begins processing.
  /// - Parameter builder: Closure that returns a `QueuedRequest`.
  func enqueue(_ builder: @escaping @Sendable () -> QueuedRequest) async {
    await self.enqueue(builder())
  }

  // MARK: Internals

  /// Sends a request result to all active subscribers.
  /// - Parameter value: The result to send.
  private func emit(_ value: QueuedRequestResult) {
    for (_, cont) in subs {
      cont.yield(value)
    }
  }

  /// Processes the next request in the queue if not already processing.
  /// - Parameter isRetrying: Whether this processing pass is due to a retry.
  /// Emits results to subscribers and calls `finish` upon completion.
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

  /// Handles the completion of a request, scheduling a retry if needed.
  /// - Parameters:
  ///   - next: The request that just finished.
  ///   - error: An optional error if the request failed.
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

  /// Inserts a request at the front of the queue and triggers processing.
  /// - Parameter request: The request to insert.
  private func enqueueFrontAndKick(_ request: QueuedRequest) async {
    queue.insert(request, at: 0)
    await saveQueue()
    await processNextIfNeeded(isRetrying: true) // IMPORTANT: restart processing after delayed insert
  }

  /// Calculates the delay before retrying a failed request.
  /// - Parameter attempt: The retry attempt number (starting at 1).
  /// - Returns: The delay in seconds, capped at 20 seconds.
  private func backoff(for attempt: Int) -> TimeInterval {
    let expo = pow(2.0, Double(attempt - 1)) * baseBackoff
    let jitter = Double.random(in: 0...(baseBackoff / 2))
    return min(expo + jitter, 20.0)
  }

  /// Persists the current state of the queue to disk as JSON.
  /// This is called after modifications to the queue.
  private func saveQueue() async {
    let snapshot = self.queue
    let url = self.saveURL
    if let data = try? JSONEncoder().encode(snapshot) {
      try? data.write(to: url)
    }
  }
}
