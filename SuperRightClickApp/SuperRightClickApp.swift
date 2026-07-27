import SwiftUI

@main
struct SuperRightClickApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
