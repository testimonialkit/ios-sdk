import SwiftUI

/// An extension on `View` that provides a method for conditionally displaying branding on a view.
extension View {
  /// Conditionally overlays a "Powered by" branding label and logo at the bottom of the view.
  ///
  /// - Parameter show: A Boolean value indicating whether the branding should be displayed.
  /// - Returns: A view that either shows the original content or the content with branding overlay.
  @ViewBuilder func showBranding(_ show: Bool) -> some View {
    if !show {
      self
    } else {
      self.overlay(alignment: .bottom, content: {
        HStack(spacing: 4) {
          Text("Powered by")
            .font(.labelSmall)
            .foregroundColor(.onSurface)

          Image("logoFull", bundle: .module)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 20)
            .foregroundColor(.onSurface)
        }
        .offset(y: 45)
      })
    }
  }
}
