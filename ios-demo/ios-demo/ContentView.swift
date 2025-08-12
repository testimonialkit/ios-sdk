import SwiftUI
import TestimonialKit
import SwiftThemeKit

struct ContentView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text("Hello, world!")

      Button("Prompt if possible") {
        TestimonialKit.promptIfPossible { result in
          print("Prompt completion:", result)
        }
      }

      Button("Track custom event") {
        TestimonialKit.trackEvent(name: "customEvent", score: 1)
      }

      Button("Track event with metadata") {
        TestimonialKit.trackEvent(
          name: "metadataEvent", score: 1, metadata: [
            "key1": "value1",
            "key2": "value2"
          ])
      }
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
