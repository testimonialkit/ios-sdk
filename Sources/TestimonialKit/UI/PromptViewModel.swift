import SwiftUI
import Combine
import Factory

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Represents the different UI states in the feedback prompt flow.
/// Used by `PromptViewModel` to drive the view based on backend events and user actions.
enum PromptViewState: Equatable, Sendable {
  /// The initial state where the user can provide a star rating.
  case rating
  /// State where the user is prompted to leave a text comment, optionally with a rating.
  /// - Parameter data: The feedback log data from the backend.
  case comment(data: FeedbackLogResponse)
  /// State showing a thank-you message after feedback submission.
  /// - Parameter data: Optional feedback data if available.
  case thankYou(data: FeedbackLogResponse?)
  /// State for directing the user to the App Store review screen.
  /// - Parameters:
  ///   - redirected: Indicates whether the user was redirected successfully.
  ///   - data: Feedback log data from the backend.
  case storeReview(redirected: Bool, data: FeedbackLogResponse)
}

/// View model driving the state and actions of the feedback prompt UI.
///
/// Listens to `PromptManagerProtocol` feedback events and updates the UI accordingly.
/// Provides methods for handling user actions such as submitting ratings/comments,
/// dismissing the prompt, and redirecting to the App Store review page.
@MainActor
class PromptViewModel: ObservableObject {
  /// Retains Combine subscriptions for the lifetime of the view model.
  private var cancellables = Set<AnyCancellable>()
  /// The prompt manager responsible for managing prompt lifecycle and logging.
  private let promptManager: PromptManagerProtocol
  /// SDK configuration containing subscription and environment details.
  private let sdkConfig: TestimonialKitConfig
  /// The selected star rating from the user.
  @Published var rating: Int = 0
  /// The optional comment text provided by the user.
  @Published var comment: String = ""
  /// Current UI state of the prompt.
  @Published var state: PromptViewState = .rating
  /// Indicates whether a network request or action is in progress.
  @Published var isLoading = false

  /// Whether to display SDK branding in the prompt UI.
  /// Branding is hidden for active subscription holders.
  var showBranding: Bool {
    !sdkConfig.hasActiveSubscription
  }

  /// Guards against multiple prompt dismiss requests.
  private var didRequestDismiss = false

  /// Creates a new `PromptViewModel`.
  /// - Parameters:
  ///   - promptManager: The manager to coordinate prompt logic.
  ///   - sdkConfig: The current SDK configuration.
  ///
  /// Subscribes to `feedbackEventPublisher` to react to feedback events from the manager.
  init(promptManager: PromptManagerProtocol, sdkConfig: TestimonialKitConfig) {
    self.promptManager = promptManager
    self.sdkConfig = sdkConfig
    promptManager.feedbackEventPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] (event) in
        guard let self else { return }

        /// Handle a rating event: determine next state based on positivity, comment request, and App Store redirect settings.
        switch event {
        case .rating(let data):
          if !data.isPositiveRating || data.requestComment {
            setStateDeferred(.comment(data: data))
          } else if data.isPositiveRating && data.redirectAutomatically && data.hasAppStoreId {
            self.redirectToAppStoreReview(data: data)
          } else if data.isPositiveRating && data.hasAppStoreId {
            setStateDeferred(.storeReview(redirected: false, data: data))
          } else {
            setStateDeferred(.thankYou(data: data))
          }

        /// Handle a comment event: determine next state similarly, possibly showing store review or thank-you.
        case .comment(let data):
          if data.isPositiveRating && data.redirectAutomatically && data.hasAppStoreId {
            self.redirectToAppStoreReview(data: data)
          } else if data.isPositiveRating && data.hasAppStoreId {
            setStateDeferred(.storeReview(redirected: false, data: data))
          } else {
            setStateDeferred(.thankYou(data: data))
          }

        /// Handle an error event: go directly to thank-you with no feedback data.
        case .error:
          setStateDeferred(.thankYou(data: nil))
        }

        do { self.isLoading = false }
      }
      .store(in: &cancellables)
  }

  /// Handles submission based on the current prompt state.
  func handleSubmit() {
    switch state {
    case .rating:
      handleSubmitRating()
    case .comment:
      handleSubmitComment()
    case .storeReview(_, let data):
      redirectToAppStoreReview(data: data)
    case .thankYou(let data):
      requestDismiss(as: .thankYou(data: data))
    }
  }

  /// Sends the selected rating to the prompt manager.
  func handleSubmitRating() {
    if rating == 0 { return }
    isLoading = true
    Task { [weak self] in
      guard let self else { return }
      await promptManager.logUserFeedback(rating: rating, comment: comment.isEmpty ? nil : comment)
    }
  }

  /// Sends the entered comment to the prompt manager.
  func handleSubmitComment() {
    isLoading = true
    dismissKeyboard()
    Task { [weak self] in
      guard let self else { return }
      await promptManager.logUserComment(comment: comment.isEmpty ? nil : comment)
    }
  }

  /// Handles dismissal logic depending on the current state.
  func handleDismiss() {
    if case .comment(let data) = state {
      if data.isPositiveRating && data.hasAppStoreId {
        setStateDeferred(.storeReview(redirected: false, data: data))
      } else {
        setStateDeferred(.thankYou(data: data))
      }
    } else {
      requestDismiss(as: state)
    }
  }

  /// Called when the prompt view disappears; notifies the manager of dismissal.
  func handleOnDisappear() {
    Task { [weak self] in
      guard let self, !didRequestDismiss else { return }
      await promptManager.handlePromptDismissAction(on: state)
    }
  }

  /// Attempts to open the App Store review page for the app using the provided feedback data.
  func redirectToAppStoreReview(data: FeedbackLogResponse) {
    let appStoreID = data.appStoreId ?? ""

    if appStoreID.isEmpty {
      Logger.shared.debug("Invalid app identifier")
      requestDismiss(as: .storeReview(redirected: false, data: data))
      return
    }

    #if canImport(UIKit)
    // iOS / iPadOS: use itms-apps URL scheme to open the App Store review page
    guard let url = URL(string: "itms-apps://itunes.apple.com/app/\(appStoreID)?action=write-review") else {
      Logger.shared.debug("Invalid store URL")
      requestDismiss(as: .storeReview(redirected: false, data: data))
      return
    }

    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url, options: [:]) { [weak self] success in
        guard let self else { return }
        if success {
          self.requestDismiss(as: .storeReview(redirected: true, data: data))
        } else {
          Logger.shared.debug("Failed to open AppStore")
          self.requestDismiss(as: .storeReview(redirected: false, data: data))
        }
      }
    } else {
      Logger.shared.debug("Can not open URL")
      requestDismiss(as: .storeReview(redirected: false, data: data))
    }
    #elseif canImport(AppKit)
    // macOS: prefer macappstore://, fall back to https://apps.apple.com
    let primary = URL(string: "macappstore://itunes.apple.com/app/id\(appStoreID)?mt=12&action=write-review")
    let fallback = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")

    if let url = primary, NSWorkspace.shared.open(url) {
      requestDismiss(as: .storeReview(redirected: true, data: data))
    } else if let url = fallback, NSWorkspace.shared.open(url) {
      requestDismiss(as: .storeReview(redirected: true, data: data))
    } else {
      Logger.shared.debug("Failed to open App Store on macOS")
      requestDismiss(as: .storeReview(redirected: false, data: data))
    }
    #else
    // Unsupported platform
    Logger.shared.debug("App Store redirect unsupported on this platform")
    requestDismiss(as: .storeReview(redirected: false, data: data))
    #endif
  }

  /// Programmatically dismisses the on-screen keyboard.
  private func dismissKeyboard() {
    #if canImport(UIKit)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #elseif canImport(AppKit)
    NSApp.keyWindow?.makeFirstResponder(nil)
    #endif
  }

  /// Changes the state on the main thread if it's different from the current one.
  private func setStateDeferred(_ newState: PromptViewState) {
    guard state != newState else { return }
    DispatchQueue.main.async { [weak self] in
      self?.state = newState
    }
  }

  /// Requests prompt dismissal via the prompt manager, ensuring it's done only once.
  private func requestDismiss(as finalState: PromptViewState) {
    guard !didRequestDismiss else { return }
    didRequestDismiss = true

    // Reflect final state for UI immediately (safe), then defer external dismiss
    state = finalState
    Task { [weak self] in
      guard let self else { return }
      await promptManager.dismissPrompt(on: finalState)
      await MainActor.run { didRequestDismiss = false }
    }
  }
}
