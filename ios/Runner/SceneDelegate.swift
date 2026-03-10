import UIKit
import Flutter
import fluwx

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    // Flutter 会在 AppDelegate 中创建并管理窗口，这里只需保持默认行为即可。
    guard scene is UIWindowScene else { return }
  }

  // Universal Link 回调
  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    FluwxPlugin.handleOpenURL(userActivity)
  }

  // URL Scheme 回调
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    FluwxPlugin.handleOpenURL(url)
  }
}
