import SwiftUI

@main
struct LEDSignApp: App {
    var body: some Scene {
        Window("LED Sign", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
