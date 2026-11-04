import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Yerel (flutter_local_notifications) bildirim dokunuşları Flutter'a
    // ulaşsın: Firebase kendi delegesini kurarken FCM olmayan bildirimleri
    // eklentiye ileten önceki delege bulunmuyordu (GPT-6 Pro ALAN 4).
    // `super` çağrısından ÖNCE atanır; FlutterAppDelegate zaten
    // UNUserNotificationCenterDelegate uygular.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NotificationSettings") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.zankurd.app/notification_settings",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "open" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
    }
  }
}
