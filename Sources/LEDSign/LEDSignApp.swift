import SwiftUI

@main
struct LEDSignApp: App {
    var body: some Scene {
        WindowGroup("LED Sign") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
