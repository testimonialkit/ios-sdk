import UIKit
import Combine

public class TestimonialKit {
  private init() {}

  public static func setup(with apiKey: String) {
    TestimonialKitManager.shared.setup(with: apiKey)
  }

  public static func trackEvent(
    name: String,
    score: Int,
    type: AppEventType = .positive,
    metadata: [String: String]? = nil
  ) {
    TestimonialKitManager.shared.trackEvent(name: name, score: score, type: type, metadata: metadata)
  }

  public static func promptIfPossible(metadata: [String: String]? = nil) {
    TestimonialKitManager.shared.promptIfPossible(metadata: metadata)
  }

  @MainActor
  public func showProptUI() {
    TestimonialKitManager.shared.showProptUI()
  }
}
