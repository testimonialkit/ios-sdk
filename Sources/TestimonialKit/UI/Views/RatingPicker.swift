import SwiftUI

/// A horizontal row of tappable star icons for selecting a rating.
///
/// Displays five stars, each as a button. The selected star and all stars to its left are filled;
/// others are outlined. The selected rating is bound via `@Binding`.
struct RatingPicker: View {
  /// The width and height for each star icon.
  private let iconSize: CGFloat = 32

  /// The currently selected rating value, bound to external state.
  /// Setting this updates the UI to reflect the new selection.
  @Binding var rating: Int

  /// The view content displaying five star buttons.
  /// Each button updates the `rating` when tapped and reflects selection with a filled star.
  var body: some View {
    HStack(spacing: 12) {
      /// Star button for rating value 1.
      Button {
        rating = 1
      } label: {
        Image(systemName: icon(for: 1))
          .resizable()
          .renderingMode(.template)
          .foregroundColor(.yellow)
          .aspectRatio(contentMode: .fit)
          .frame(width: iconSize, height: iconSize)
      }
      .buttonStyle(.plain)

      /// Star button for rating value 2.
      Button {
        rating = 2
      } label: {
        Image(systemName: icon(for: 2))
          .resizable()
          .renderingMode(.template)
          .foregroundColor(.yellow)
          .aspectRatio(contentMode: .fit)
          .frame(width: iconSize, height: iconSize)
      }
      .buttonStyle(.plain)

      /// Star button for rating value 3.
      Button {
        rating = 3
      } label: {
        Image(systemName: icon(for: 3))
          .resizable()
          .renderingMode(.template)
          .foregroundColor(.yellow)
          .aspectRatio(contentMode: .fit)
          .frame(width: iconSize, height: iconSize)
      }
      .buttonStyle(.plain)

      /// Star button for rating value 4.
      Button {
        rating = 4
      } label: {
        Image(systemName: icon(for: 4))
          .resizable()
          .renderingMode(.template)
          .foregroundColor(.yellow)
          .aspectRatio(contentMode: .fit)
          .frame(width: iconSize, height: iconSize)
      }
      .buttonStyle(.plain)

      /// Star button for rating value 5.
      Button {
        rating = 5
      } label: {
        Image(systemName: icon(for: 5))
          .resizable()
          .renderingMode(.template)
          .foregroundColor(.yellow)
          .aspectRatio(contentMode: .fit)
          .frame(width: iconSize, height: iconSize)
      }
      .buttonStyle(.plain)
    }
  }

  /// Returns the system image name for the star icon corresponding to a given rating position.
  /// - Parameter rating: The star position (1–5) to determine the icon for.
  /// - Returns: `"star.fill"` if the position is less than or equal to the current rating, otherwise `"star"`.
  private func icon(for rating: Int) -> String {
    if rating <= self.rating {
      return "star.fill"
    } else {
      return "star"
    }
  }
}
