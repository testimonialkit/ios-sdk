import SwiftUI

struct RatingPicker: View {
  private let iconSize: CGFloat = 32
  @Binding var rating: Int

  var body: some View {
    HStack(spacing: 12) {
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

  private func icon(for rating: Int) -> String {
    if rating <= self.rating {
      return "star.fill"
    } else {
      return "star"
    }
  }
}
