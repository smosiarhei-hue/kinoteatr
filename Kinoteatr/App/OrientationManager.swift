import UIKit

final class OrientationManager {
    static var orientationMask: UIInterfaceOrientationMask = .portrait

    static func lockLandscape() {
        orientationMask = .landscape
        rotate(to: .landscapeRight)
    }

    static func lockPortrait() {
        orientationMask = .portrait
        rotate(to: .portrait)
    }

    // iOS 26 SDK изменил requestGeometryUpdate (.iOS(...) больше не принимает
    // аргументы и не компилируется), поэтому используем проверенный совместимый
    // способ принудительного поворота: supportedInterfaceOrientationsFor из
    // AppDelegate + UIDevice.setValue("orientation"), с защитой от отсутствия
    // приватного селектора (на случай будущих iOS).
    private static func rotate(to orientation: UIInterfaceOrientation) {
        if UIDevice.current.responds(to: NSSelectorFromString("setOrientation:")) {
            UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
        }
        UIViewController.attemptRotationToDeviceOrientation()
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationManager.orientationMask
    }
}