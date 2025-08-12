import UIKit
import Combine
import Factory

@MainActor
public class TestimonialKit {

  private init() {}

  public static func setup(withKey apiKey: String, logLevel: LogLevel = .info) {
    Logger.shared.currentLevel = logLevel
    let manager = resolve(\.testimonialKitManager)
    manager.setup(with: apiKey)
  }

  public static func trackEvent(
    name: String,
    score: Int,
    type: AppEventType = .positive,
    metadata: [String: String]? = nil
  ) {
    let manager = resolve(\.testimonialKitManager)
    manager.trackEvent(name: name, score: score, type: type, metadata: metadata)
  }

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
