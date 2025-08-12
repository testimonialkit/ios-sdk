//
//  ios_demoApp.swift
//  ios-demo
//
//  Created by Eduard Albu on 07.08.2025.
//

import SwiftUI
import TestimonialKit

@main
struct ios_demoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            .onAppear {
              TestimonialKit.setup(with: "tk_pub_b8e586d674610dabf398c7f7af24ba18", logLevel: .debug)
            }
        }
    }
}
