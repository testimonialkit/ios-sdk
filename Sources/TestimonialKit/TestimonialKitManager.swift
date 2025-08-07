import SwiftUI

public class TestimonialKitManager: @unchecked Sendable {
  public static let shared = TestimonialKitManager()
  var config: TestimonialKitConfig!
  private let responseHandler = QueueResponseHandler()
  private let promptManager = PromptManager.shared

  private init() {}

  func setup(with apiKey: String) {
    let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
    let countryCode = Locale.current.regionCode ?? "unknown"
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    let appVersion = "\(version) (\(build))"

    config = TestimonialKitConfig(apiKey: apiKey,
                                  bundleId: bundleId,
                                  userId: Storage.internalUserId,
                                  appVersion: appVersion,
                                  countryCode: countryCode)
    configure(config: config)
    RequestQueue.shared.enqueue(
      APIClient.shared.initSdk(config: config)
    )
  }

  func trackEvent(
    name: String,
    score: Int,
    type: AppEventType = .positive,
    metadata: [String: String]? = nil
  ) {
    guard let config = config else {
      print("[Event Tracking] SDK is not configured.")
      return
    }

    RequestQueue.shared.enqueue(
      APIClient.shared.sendAppEvent(
        name: name,
        score: score,
        type: type,
        metadata: metadata,
        config: config
      )
    )
  }

  func promptIfPossible(metadata: [String: String]? = nil) {
    guard let config = config else { return }

    promptManager.promptForReviewIfPossible(metadata: metadata)
  }

  @MainActor
  func showProptUI() {
    promptManager.showPrompt()
  }

  func configure(config: TestimonialKitConfig) {
    RequestQueue.shared.configure(config: config)
  }
}
