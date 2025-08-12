import SwiftUI
import SwiftThemeKit

/// Rating step view in the feedback prompt flow.
///
/// Displays a header, a row of tappable stars, a label describing the selected rating,
/// and buttons to submit or cancel the rating. Uses localized strings from `PromptConfig.RatingStrings`.
struct PromptRatingView: View {
  /// Current app theme environment value (provided by `SwiftThemeKit`).
  @Environment(\.appTheme) var appTheme
  /// The currently selected star rating, bound to external state.
  @Binding var rating: Int
  /// Localized strings for the rating screen (title, subtitle, button titles, and rating labels).
  var strings: PromptConfig.RatingStrings
  /// Indicates whether a submission action is in progress, disabling inputs and showing a loader.
  var isLoading: Bool = false
  /// Action called when the submit button is tapped.
  var onSubmit: () -> Void
  /// Action called when the cancel button is tapped.
  var onDissmiss: () -> Void

  /// The label text corresponding to the current `rating`.
  /// - Returns: The default rating label if no rating is selected, otherwise the label for the selected star.
  var ratingLabel: String {
    if(rating == 0) {
      return strings.ratingLabel
    } else {
      return strings.starLabels[rating - 1]
    }
  }

  /// Main body of the rating view.
  /// Shows the header, rating picker with label, and submit/cancel buttons.
  var body: some View {
    VStack(spacing: 40) {
      /// Header displaying the rating title and subtitle.
      PromptHeader(
        title: strings.title,
        subtitle: strings.subtitle
      )

      VStack(spacing: 8) {
        /// Interactive star rating picker bound to `rating`.
        RatingPicker(rating: $rating)
        /// Text label describing the currently selected rating.
        Text(ratingLabel)
          .font(.labelMedium)
          .foregroundColor(.outline)
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
