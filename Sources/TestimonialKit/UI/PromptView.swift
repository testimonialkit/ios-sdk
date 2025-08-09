import SwiftUI
import Factory
import SwiftThemeKit

struct PromptView: View {
  let config: PromptConfig
  @Injected(\.promptManager) var promptManager
  @Environment(\.appTheme) var appTheme
  @StateObject private var viewModel = PromptViewModel()

  var body: some View {
    ThemeProvider(
      light: .defaultLight.copy(
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
      ),
      dark: .defaultDark.copy(
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
    ) {
      ZStack {
        switch viewModel.state {
        case .rating:
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
          .overlay(alignment: .bottom, content: {
            HStack(spacing: 4) {
              Text("Powered by")
                .font(.labelSmall)
                .foregroundColor(.onSurface)

              Image("logoFull", bundle: .module)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 20)
                .foregroundColor(.onSurface)
            }
            .offset(y: 45)
          })
          .transition(.opacity)
        case .comment:
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
          .overlay(alignment: .bottom, content: {
            HStack(spacing: 4) {
              Text("Powered by")
                .font(.labelSmall)
                .foregroundColor(.onSurface)

              Image("logoFull", bundle: .module)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 20)
                .foregroundColor(.onSurface)
            }
            .offset(y: 45)
          })
          .transition(.opacity)
        case .storeReview:
          EmptyView()
            .transition(.opacity)
        }
      }
      .animation(.easeInOut(duration: 0.25), value: viewModel.state)
      .onAppear {
        promptManager.logPromptShown()
      }
      .onDisappear {
        promptManager.logPromptDismissed()
      }
      .padding(16)
    }
  }
}

#Preview {
  PromptView(config: PromptConfig())
}
