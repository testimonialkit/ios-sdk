import SwiftUI
import SwiftThemeKit

struct PromptCommentView: View {
  @Environment(\.appTheme) var appTheme
  @Binding var comment: String
  var strings: PromptConfig.CommentStrings
  var isLoading: Bool = false
  var onSubmit: () -> Void
  var onDissmiss: () -> Void

  var body: some View {
    VStack(spacing: 40) {
      PromptHeader(
        title: strings.title,
        subtitle: strings.subtitle
      )

      Group {
        if #available(iOS 16.0, *) {
          // Multiline TextField (keeps your TextField-based styles)
          TextField(strings.placeholder, text: $comment, axis: .vertical)
            .applyThemeTextFieldStyle()
            .lineLimit(3...6) // grows up to 6 lines
        } else {
          // Fallback: TextEditor (apply simple styling)
          ZStack(alignment: .topLeading) {
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
      }

      VStack(spacing: 16) {
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
