import SwiftUI
import SwiftThemeKit

struct PromptRatingView: View {
  @Environment(\.appTheme) var appTheme
  @Binding var rating: Int
  var title: String = ""
  var subtitle: String = ""
  var submitTitle: String = "Submit"
  var dismissTitle: String = "Cancel"
  var isLoading: Bool = false
  var onSubmit: () -> Void
  var onDissmiss: () -> Void

  var body: some View {
    VStack(spacing: 40) {
      PromptHeader(
        title: title,
        subtitle: subtitle
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
            Text(submitTitle)
              .frame(maxWidth: .infinity)
          }
        }
        .applyThemeButtonStyle()
        .disabled(isLoading)
        .frame(maxWidth: .infinity)

        Button {
          onDissmiss()
        } label: {
          Text(dismissTitle)
        }
        .disabled(isLoading)
        .plainTextButton(.bodySmall)
      }
    }
    .padding()
  }
}
