import SwiftUI
import Factory
import SwiftThemeKit

struct PromptView: View {
  private let config: PromptConfig
  private let lightTheme: Theme
  private let darkTheme: Theme
  @Environment(\.appTheme) var appTheme
  @StateObject private var viewModel = resolve(\.promptViewModel)

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
      .onDisappear {
        viewModel.handleOnDisappear()
      }
    }
  }

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
