import SwiftUI
import ConfettiSwiftUI

/// Thank-you step view in the feedback prompt flow.
///
/// Displays a header, a checkmark icon with confetti animation, and a button to close the prompt.
/// Uses strings from `PromptConfig.ThankYouStrings` for localized text.
struct PromptThankYou: View {
  /// Localized strings for the thank-you screen (title, message, and close button text).
  var strings: PromptConfig.ThankYouStrings
  /// Controls triggering of the confetti animation when the view appears.
  @State var showConfetti: Bool = false
  /// Action called when the close button is tapped.
  var onSubmit: () -> Void
  /// Action called when the prompt should be dismissed (not currently used in this view).
  var onDissmiss: () -> Void

  /// Main body of the thank-you view.
  /// Shows the header, success icon with confetti, and the close button.
  var body: some View {
    VStack(spacing: 53.5) {
      /// Header displaying the thank-you title and message.
      PromptHeader(
        title: strings.title,
        subtitle: strings.message
      )

      /// Success checkmark icon styled in green, with a confetti cannon effect triggered on appear.
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

      /// Container for the close button.
      VStack(spacing: 16) {
        /// Close button that invokes `onSubmit` when tapped.
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
