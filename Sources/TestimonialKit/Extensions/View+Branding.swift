import SwiftUI

extension View {
  func showBranding() -> some View {
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
