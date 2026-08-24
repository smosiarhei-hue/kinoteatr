import UIKit

final class OrientationManager {
    static var orientationMask: UIInterfaceOrientationMask = .portrait

    static func lockLandscape() {
        orientationMask = .landscape
        apply(.landscapeRight)
    }

    static func lockPortrait() {
        orientationMask = .portrait
        apply(.portrait)
    }

    private static func apply(_ orientation: UIInterfaceOrientation) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        Task { @MainActor in
            try? await scene.requestGeometryUpdate(.iOS(interfaceOrientation: orientation))
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationManager.orientationMask
    }
}
