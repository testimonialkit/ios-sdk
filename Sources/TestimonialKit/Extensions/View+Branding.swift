import SwiftUI

extension View {
  @ViewBuilder
  func showBranding(_ show: Bool) -> some View {
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
