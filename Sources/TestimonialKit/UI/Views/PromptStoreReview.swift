import SwiftUI
import ConfettiSwiftUI

struct PromptStoreReview: View {
  var strings: PromptConfig.StoreReviewStrings
  @State var showConfetti: Bool = false
  var isLoading: Bool = false
  var onSubmit: () -> Void
  var onDissmiss: () -> Void

  var body: some View {
    VStack(spacing: 43) {
      PromptHeader(
        title: strings.title,
        subtitle: strings.message
      )

      Image(systemName: "checkmark.circle.fill")
        .resizable()
        .renderingMode(.template)
        .foregroundColor(.green)
        .frame(width: 48, height: 48)
        .confettiCannon(
          trigger: $showConfetti,
          num: 250,
          openingAngle: Angle(degrees: 0),
          closingAngle: Angle(degrees: 360),
          radius: 150
        )
        .zIndex(2)
        .onAppear {
          showConfetti = true
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
      .zIndex(1)
    }
    .padding()
  }
}
