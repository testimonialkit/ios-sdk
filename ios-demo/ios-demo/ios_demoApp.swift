import SwiftUI
import TestimonialKit

@main
struct ios_demoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            .onAppear {
              TestimonialKit.setup(
                withKey: "tk_pub_68775e735a1e354c787b5d932036d877",
                logLevel: .verbose
              )
            }
        }
    }
}
