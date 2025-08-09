import UIKit
import Combine
import Factory

@MainActor
public class TestimonialKit {

  private init() {}

  public static func setup(with apiKey: String) {
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

  public static func promptIfPossible(metadata: [String: String]? = nil, promptConfig: PromptConfig = PromptConfig()) {
    let manager = resolve(\.testimonialKitManager)
    manager.promptIfPossible(metadata: metadata, promptConfig: promptConfig)
  }
}
