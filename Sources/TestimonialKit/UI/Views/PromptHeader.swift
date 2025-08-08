import SwiftUI
import SwiftThemeKit

struct PromptHeader: View {
  var title: String
  var subtitle: String?

  var body: some View {
    VStack {
      Text(title)
        .font(TextStyleToken.headlineLarge)

      if let subtitle {
        Text(subtitle)
          .font(TextStyleToken.bodyMedium)
      }
    }
  }
}
