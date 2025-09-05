import SwiftUI
import SwiftThemeKit

/// Comment step view in the feedback prompt flow.
///
/// Displays a header, a multiline text input for leaving feedback comments,
/// and submit/cancel buttons. Uses localized strings from `PromptConfig.CommentStrings`
/// for titles, placeholder text, and button labels.
struct PromptCommentView: View {
  /// Current app theme environment value (provided by `SwiftThemeKit`).
  @Environment(\.appTheme) var appTheme
  /// The comment text entered by the user, bound to external state.
  @Binding var comment: String
  /// Localized strings for the comment screen (title, subtitle, placeholder, and button titles).
  var strings: PromptConfig.CommentStrings
  /// Indicates whether a submission action is currently in progress, disabling inputs and showing a loader.
  var isLoading: Bool = false
  /// Action called when the submit button is tapped.
  var onSubmit: () -> Void
  /// Action called when the cancel button is tapped.
  var onDissmiss: () -> Void

  /// Main body of the comment view.
  /// Shows the header, multiline text input (TextField on iOS 16+, TextEditor fallback on earlier versions),
  /// and the submit/cancel buttons.
  var body: some View {
    VStack(spacing: 30) {
      /// Header displaying the comment title and subtitle.
      PromptHeader(
        title: strings.title,
        subtitle: strings.subtitle
      )

      TextField(strings.placeholder, text: $comment, axis: .vertical)
        .applyThemeTextFieldStyle()
        .lineLimit(3...6)

      VStack(spacing: 16) {
        /// Submit button that invokes `onSubmit` when tapped.
        /// Shows a `ProgressView` if `isLoading` is true.
        Button {
          onSubmit()
        } label: {
          if isLoading {
            ProgressView()
              .frame(maxWidth: .infinity)
          } else {
            Text(strings.submitButtonTitle)
              .frame(maxWidth: .infinity)
          }
        }
        .applyThemeButtonStyle()
        .disabled(isLoading)
        .frame(maxWidth: .infinity)

        /// Cancel button that invokes `onDissmiss` when tapped.
        Button {
          onDissmiss()
        } label: {
          Text(strings.cancelButtonTitle)
        }
        .disabled(isLoading)
        .plainTextButton(.bodySmall)
      }
    }
    .padding()
  }
}
