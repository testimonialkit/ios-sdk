import SwiftUI

struct PromptView: View {
  let promptText: String

  @State private var rating: Int = 0
  @State private var comment: String = ""

  var onSubmit: ((Int, String?) -> Void)?
  var onDismiss: (() -> Void)?

  var body: some View {
    VStack(spacing: 20) {
      Text(promptText)
        .font(.headline)

      Picker("Rating", selection: $rating) {
        ForEach(1..<6) { Text("\($0)").tag(Optional($0)) }
      }
      .pickerStyle(.segmented)

      TextField("Optional comment", text: $comment)
        .textFieldStyle(.roundedBorder)

      Button("Submit") {
        onSubmit?(rating + 1, comment.isEmpty ? nil : comment)
      }

      Button("Dismiss") {
        PromptManager.shared.dismissPrompt()
      }
      .foregroundColor(.red)
    }
    .padding()
    .onAppear {
      PromptManager.shared.logPromptShown()
    }
    .onDisappear {
      PromptManager.shared.logPromptDismissed()
    }
  }
}

#Preview {
  PromptView(
    promptText: "Some test") { rating, comment in
      
    }
}
