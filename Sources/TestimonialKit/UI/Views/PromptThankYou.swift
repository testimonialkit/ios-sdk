import SwiftUI
import ConfettiSwiftUI

struct PromptThankYou: View {
  var strings: PromptConfig.ThankYouStrings
  @State var showConfetti: Bool = false
  var onSubmit: () -> Void
  var onDissmiss: () -> Void

  var body: some View {
    VStack(spacing: 53.5) {
      PromptHeader(
        title: strings.title,
        subtitle: strings.message
      )

      Image(systemName: "checkmark.circle.fill")
        .resizable()
        .renderingMode(.template)
        .foregroundColor(.green)
        .frame(width: 60, height: 60)
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
          Text(strings.closeButtonTitle)
            .frame(maxWidth: .infinity)
        }
        .applyThemeButtonStyle()
        .frame(maxWidth: .infinity)
      }
      .zIndex(1)
    }
    .padding()
  }
}
