import SwiftUI
import ConfettiSwiftUI

/// Store review step view in the feedback prompt flow.
///
/// Displays a header with a success message, a checkmark icon with a confetti animation,
/// and buttons for submitting or cancelling the store review prompt.
/// Uses strings from `PromptConfig.StoreReviewStrings` for localized text.
struct PromptStoreReview: View {
  /// Localized strings for the store review screen (title, message, submit, and cancel button titles).
  var strings: PromptConfig.StoreReviewStrings
  /// Controls triggering of the confetti animation when the view appears.
  @State var showConfetti: Bool = false
  /// Indicates whether a submission action is currently in progress, disabling inputs and showing a loader.
  var isLoading: Bool = false
  /// Action called when the submit button is tapped.
  var onSubmit: () -> Void
  /// Action called when the cancel button is tapped.
  var onDissmiss: () -> Void

  /// Main body of the store review view.
  /// Shows the header, success icon with confetti, and submit/cancel buttons.
  var body: some View {
    VStack(spacing: 43) {
      /// Header displaying the store review title and message.
      PromptHeader(
        title: strings.title,
        subtitle: strings.message
      )

      /// Success checkmark icon styled in green, with a confetti cannon effect triggered on appear.
      /// - `num`: The number of confetti particles (250).
      /// - `openingAngle` and `closingAngle`: Define the emission spread.
      /// - `radius`: The radius within which confetti spawns.
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

      /// Container for the submit and cancel buttons.
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
      .zIndex(1)
    }
    .padding()
  }
}
