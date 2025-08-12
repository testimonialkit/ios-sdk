import Foundation
import Factory

extension Container {

  var configuration: Factory<TestimonialKitConfig> {
    self {
      let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
      let countryCode = Locale.current.regionCode ?? "unknown"
      let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
      let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
      let appVersion = "\(version) (\(build))"

      return TestimonialKitConfig(
        apiKey: "",
        bundleId: bundleId,
        userId: Storage.internalUserId,
        appVersion: appVersion,
        countryCode: countryCode
      )
    }
    .singleton
  }

  var apiClient: Factory<APIClientProtocol> {
    self { APIClient(config: self.configuration()) }
      .scope(.shared)
  }

  @MainActor
  var promptManager: Factory<PromptManagerProtocol> {
    self { @MainActor in
      PromptManager(
        config: self.configuration()
      )
    }
    .singleton
  }

  var requestQueue: Factory<RequestQueue> {
    self {
      RequestQueue()
    }
    .singleton
  }

  @MainActor
  var testimonialKitManager: Factory<TestimonialKitManagerProtocol> {
    self { @MainActor in
      TestimonialKitManager(
        promptManager: self.promptManager(),
        requestQueue: self.requestQueue(),
        configuration: self.configuration()
      )
    }
    .singleton
  }

  @MainActor
  var promptViewModel: Factory<PromptViewModel> {
    self { @MainActor in
      PromptViewModel(promptManager: self.promptManager(), sdkConfig: self.configuration())
    }
  }
}
