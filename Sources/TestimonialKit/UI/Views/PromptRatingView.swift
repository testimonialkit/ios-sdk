import SwiftUI
import SwiftThemeKit

struct PromptRatingView: View {
  @Environment(\.appTheme) var appTheme
  @Binding var rating: Int
  var strings: PromptConfig.RatingStrings
  var isLoading: Bool = false
  var onSubmit: () -> Void
  var onDissmiss: () -> Void

  var body: some View {
    VStack(spacing: 40) {
      PromptHeader(
        title: strings.title,
        subtitle: strings.subtitle
      )

      RatingPicker(rating: $rating)

      VStack(spacing: 16) {
        Button {
          onSubmit()
        } label: {
          if isLoading {
            ProgressView()
              .frame(maxWidth: .infinity)
              .scaleEffect(0.8)
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
