import UIKit
import Combine
import Factory

/// Public entry point for the TestimonialKit SDK.
///
/// This type exposes a small static API surface for initializing the SDK,
/// tracking app events, and conditionally presenting the in‑app feedback prompt.
/// All methods are `@MainActor` to keep UI‑adjacent work on the main thread.
@MainActor
public class TestimonialKit {

  /// Disallow direct instantiation; use the static methods on `TestimonialKit` instead.
  private init() {}

  /// Initializes the SDK and configures logging.
  /// - Parameters:
  ///   - apiKey: Your project’s API key used to authenticate requests.
  ///   - logLevel: Minimum log level printed to the console (default is `.info`).
  /// - Important: Call this early in app launch (e.g., in `application(_:didFinishLaunchingWithOptions:)`).
  public static func setup(withKey apiKey: String, logLevel: LogLevel = .info) {
    Logger.shared.currentLevel = logLevel
    let manager = resolve(\.testimonialKitManager)
    manager.setup(with: apiKey)
  }

  /// Records an application event that can influence prompt eligibility and analytics.
  /// - Parameters:
  ///   - name: A domain‑specific identifier for the event (e.g., `onboarding_completed`).
  ///   - score: A numeric score representing the event impact (e.g., 1–100).
  ///   - type: Qualifier for the event’s sentiment (positive/neutral/negative). Defaults to `.positive`.
  ///   - metadata: Optional custom key–value pairs to attach to this event.
  /// - Note: Events are queued and sent reliably; they may be retried if the device is offline.
  public static func trackEvent(
    name: String,
    score: Int,
    type: AppEventType = .positive,
    metadata: [String: String]? = nil
  ) {
    let manager = resolve(\.testimonialKitManager)
    manager.trackEvent(name: name, score: score, type: type, metadata: metadata)
  }

  /// Checks backend eligibility and, if allowed, presents the in‑app feedback prompt.
  /// - Parameters:
  ///   - metadata: Optional key–value pairs attached to all logs for this prompt session.
  ///   - promptConfig: Appearance and text configuration for the prompt UI (defaults provided).
  ///   - completion: Optional closure called with the final `PromptResult` after the prompt is dismissed.
  /// - Discussion: This method is safe to call multiple times; the SDK will avoid showing the prompt
  ///   if the user is not eligible at the moment of the call.
  public static func promptIfPossible(
    metadata: [String: String]? = nil,
    promptConfig: PromptConfig = PromptConfig(),
    completion: (@Sendable (PromptResult) -> Void)? = nil
  ) {
    let manager = resolve(\.testimonialKitManager)
    manager.promptIfPossible(
      metadata: metadata,
      promptConfig: promptConfig,
      completion: completion
    )
  }
}
