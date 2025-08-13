import Foundation
import Factory

/// Dependency registrations for the TestimonialKit demo app using the `Factory` container.
///
/// Centralizes construction, lifetimes, and actor constraints for SDK components
/// such as configuration, networking client, request queue, prompt manager, and view models.
extension Container {

  /// Provides a singleton `TestimonialKitConfig` built from bundle and locale information.
  ///
  /// The instance reads the app's bundle identifier, version/build, and current region code,
  /// and initializes the SDK config with a generated internal user ID.
  /// Lifetime: `.singleton`.
  var configuration: Factory<TestimonialKitConfig> {
    self {
      /// Resolve host app identity and environment metadata.
      let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
      let countryCode = Locale.current.region?.identifier ?? "unknown"
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

  /// Provides a shared `APIClientProtocol` configured with the current SDK configuration.
  /// Lifetime: `.shared` (aliased by Factory as a cached instance per container scope).
  var apiClient: Factory<APIClientProtocol> {
    self { APIClient(config: self.configuration()) }
      .scope(.shared)
  }

  /// Provides a main-actor `PromptManagerProtocol` responsible for the prompt lifecycle.
  ///
  /// Injects `TestimonialKitConfig`, `RequestQueue`, and `APIClient` dependencies.
  /// Lifetime: `.singleton`.
  @MainActor
  var promptManager: Factory<PromptManagerProtocol> {
    self { @MainActor in
      /// Construct the actor-backed prompt manager with required collaborators.
      PromptManager(
        config: self.configuration(),
        requestQueue: self.requestQueue(),
        apiClient: self.apiClient()
      )
    }
    .singleton
  }

  /// Provides the singleton `RequestQueue` used to enqueue and retry network requests.
  /// Lifetime: `.singleton`.
  var requestQueue: Factory<RequestQueue> {
    self {
      RequestQueue()
    }
    .singleton
  }

  /// Provides the main-actor `TestimonialKitManagerProtocol` which coordinates SDK setup,
  /// event tracking, and prompt presentation.
  /// Lifetime: `.singleton`.
  @MainActor
  var testimonialKitManager: Factory<TestimonialKitManagerProtocol> {
    self { @MainActor in
      /// Construct the high-level manager with the prompt manager, request queue, and configuration.
      TestimonialKitManager(
        promptManager: self.promptManager(),
        requestQueue: self.requestQueue(),
        configuration: self.configuration()
      )
    }
    .singleton
  }

  /// Provides a `PromptViewModel` bound to the main actor for driving the prompt UI.
  ///
  /// Injects the `PromptManagerProtocol` and shared `TestimonialKitConfig`.
  @MainActor
  var promptViewModel: Factory<PromptViewModel> {
    self { @MainActor in
      /// Construct the view model with its dependencies.
      PromptViewModel(promptManager: self.promptManager(), sdkConfig: self.configuration())
    }
  }
}
