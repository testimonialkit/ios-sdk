import SwiftUI
import SwiftThemeKit

struct PromptRatingView: View {
  @Environment(\.appTheme) var appTheme
  @Binding var rating: Int
  var strings: PromptConfig.RatingStrings
  var isLoading: Bool = false
  var onSubmit: () -> Void
  var onDissmiss: () -> Void

  var ratingLabel: String {
    if(rating == 0) {
      return strings.ratingLabel
    } else {
      return strings.starLabels[rating - 1]
    }
  }

  var body: some View {
    VStack(spacing: 40) {
      PromptHeader(
        title: strings.title,
        subtitle: strings.subtitle
      )

      VStack(spacing: 8) {
        RatingPicker(rating: $rating)
        Text(ratingLabel)
          .font(.labelMedium)
          .foregroundColor(.outline)
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
