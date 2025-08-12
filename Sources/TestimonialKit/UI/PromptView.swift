import SwiftUI
import Factory
import SwiftThemeKit

/// Root SwiftUI view for the in-app feedback prompt.
///
/// Switches between rating, comment, store review, and thank-you subviews based on the
/// `PromptViewModel` state, applying theming from `SwiftThemeKit` and respecting the provided `PromptConfig`.
struct PromptView: View {
  /// Prompt configuration containing localized strings, tint colors, and component styles.
  private let config: PromptConfig
  /// Theme instance for light mode, derived from `config` values.
  private let lightTheme: Theme
  /// Theme instance for dark mode, derived from `config` values.
  private let darkTheme: Theme
  /// Current app theme environment value (provided by `SwiftThemeKit`).
  @Environment(\.appTheme) var appTheme
  /// View model driving the prompt UI state and handling user actions.
  @StateObject private var viewModel = resolve(\.promptViewModel)

  /// Creates a `PromptView` with a given configuration.
  /// - Parameter config: Prompt appearance and text configuration.
  /// Builds separate light and dark `Theme` instances from the provided config.
  init(config: PromptConfig) {
    self.config = config
    self.lightTheme = .defaultLight.copy(
      colors: .defaultLight.copy(
        primary: config.tintColorDark
      ),
      buttons: .defaultLight.copy(
        shape: config.submitButton.shape,
        size: config.submitButton.size,
        variant: config.submitButton.variant
      ),
      textFields: ThemeTextFieldDefaults(
        shape: config.commentField.shape,
        size: config.commentField.size,
        variant: config.commentField.variant
      )
    )

    self.darkTheme = .defaultDark.copy(
      colors: .defaultDark.copy(
        primary: config.tintColorDark
      ),
      buttons: .defaultDark.copy(
        shape: config.submitButton.shape,
        size: config.submitButton.size,
        variant: config.submitButton.variant
      ),
      textFields: ThemeTextFieldDefaults(
        shape: config.commentField.shape,
        size: config.commentField.size,
        variant: config.commentField.variant
      )
    )
  }

  /// Main view body, wrapped in a `ThemeProvider` to apply light/dark themes.
  /// Switches between subviews based on `viewModel.state` and adds branding if applicable.
  var body: some View {
    ThemeProvider(
      light: lightTheme,
      dark: darkTheme
    ) {
      ZStack {
        switch viewModel.state {
        case .rating:
          ratingView
        case .comment:
          commentView
        case .storeReview:
          storeReviewView
        case .thankYou:
          thankYouView
        }
      }
      .showBranding(viewModel.showBranding)
      .animation(.easeInOut(duration: 0.25), value: viewModel.state)
      .padding(16)
      /// Notify the view model when the prompt view disappears.
      .onDisappear {
        viewModel.handleOnDisappear()
      }
    }
  }

  /// Rating step view where the user can provide a star rating.
  /// Binds `viewModel.rating` and wires submit/dismiss actions.
  @ViewBuilder
  private var ratingView: some View {
    PromptRatingView(
      rating: $viewModel.rating,
      strings: config.ratingStrings,
      isLoading: viewModel.isLoading,
      onSubmit: {
        viewModel.handleSubmit()
      },
      onDissmiss: {
        viewModel.handleDismiss()
      }
    )
    .transition(.opacity)
  }

  /// Comment step view where the user can leave textual feedback.
  /// Binds `viewModel.comment` and wires submit/dismiss actions.
  @ViewBuilder
  private var commentView: some View {
    PromptCommentView(
      comment: $viewModel.comment,
      strings: config.commentStrings,
      isLoading: viewModel.isLoading,
      onSubmit: {
        viewModel.handleSubmit()
      },
      onDissmiss: {
        viewModel.handleDismiss()
      }
    )
    .transition(.opacity)
  }

  /// Store review step view prompting the user to leave an App Store review.
  /// Wires submit/dismiss actions.
  @ViewBuilder
  private var storeReviewView: some View {
    PromptStoreReview(
      strings: config.storeReviewStrings,
      onSubmit: {
        viewModel.handleSubmit()
      },
      onDissmiss: {
        viewModel.handleDismiss()
      }
    )
    .transition(.opacity)
  }

  /// Thank-you step view shown after feedback submission.
  /// Wires submit/dismiss actions.
  @ViewBuilder
  private var thankYouView: some View {
    PromptThankYou(
      strings: config.thankYouStrings,
      onSubmit: {
        viewModel.handleSubmit()
      },
      onDissmiss: {
        viewModel.handleDismiss()
      }
    )
    .transition(.opacity)
  }
}

#Preview {
  PromptView(config: PromptConfig())
}
