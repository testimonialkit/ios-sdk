import SwiftUI
import TestimonialKit

struct ContentView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text("Hello, world!")

      Button("Prompt if possible") {
        TestimonialKit.shared.promptIfPossible()
      }

      Button("Track custom event") {
        TestimonialKit.shared.trackEvent(name: "customEvent", score: 1)
      }

      Button("Track event with metadata") {
        TestimonialKit.shared.trackEvent(
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
