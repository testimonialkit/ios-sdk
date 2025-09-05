import SwiftUI
import SwiftThemeKit

/// A reusable header view for the feedback prompt.
///
/// Displays a title in a large headline style and an optional subtitle in body text style.
/// Intended for use at the top of each step in the feedback prompt flow.
struct PromptHeader: View {
  /// The main title text to display in the header.
  var title: String
  /// An optional subtitle providing additional context or instructions below the title.
  var subtitle: String?

  /// The view body containing the title and optional subtitle stacked vertically.
  var body: some View {
    VStack(spacing: 8) {
      Text(title)
        .font(TextStyleToken.headlineLarge)
        .multilineTextAlignment(.center)

      if let subtitle {
        Text(subtitle)
          .font(TextStyleToken.bodyMedium)
          .multilineTextAlignment(.center)
      }
    }
  }
}
