import SwiftUI
import TestimonialKit

@main
struct ios_demoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            .onAppear {
              TestimonialKit.setup(
                withKey: "tk_pub_b8e586d674610dabf398c7f7af24ba18",
                logLevel: .debug
              )
            }
        }
    }
}
