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
    VStack(spacing: 32) {
      /// Header displaying the comment title and subtitle.
      PromptHeader(
        title: strings.title,
        subtitle: strings.subtitle
      )

      Group {
        #if canImport(AppKit)
        /// macOS: use a styled `TextEditor` with placeholder overlay.
        ZStack(alignment: .topLeading) {
          /// Placeholder text shown when the comment field is empty.
          if comment.isEmpty {
            Text(strings.placeholder)
              .foregroundColor(.secondary)
              .padding(.horizontal, 12)
              .padding(.vertical, 10)
          }
          TextEditor(text: $comment)
            .frame(minHeight: 96, maxHeight: 200)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .overlay(
          RoundedRectangle(cornerRadius: appTheme.textFields.shape.radius(for: appTheme))
            .stroke(.xs)
        )
        #else
        /// iOS: use multiline TextField on iOS 16+, TextEditor fallback on earlier versions.
        if #available(iOS 16.0, *) {
          // Multiline TextField (keeps your TextField-based styles)
          TextField(strings.placeholder, text: $comment, axis: .vertical)
            .applyThemeTextFieldStyle()
            .lineLimit(2...6) // grows up to 6 lines
        } else {
          /// For iOS 15 and earlier, use a styled TextEditor with a placeholder overlay when empty.
          ZStack(alignment: .topLeading) {
            /// Placeholder text shown when the comment field is empty.
            if comment.isEmpty {
              Text(strings.placeholder)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            TextEditor(text: $comment)
              .frame(minHeight: 96, maxHeight: 160)
              .padding(.horizontal, 8)
              .padding(.vertical, 8)
          }
          .overlay(
            RoundedRectangle(cornerRadius: appTheme.textFields.shape.radius(for: appTheme))
              .stroke(.xs)
          )
        }
        #endif
      }

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
