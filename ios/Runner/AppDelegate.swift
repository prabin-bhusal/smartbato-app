import Flutter
import UIKit
import Darwin

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let securityChannelName = "com.example.app/security"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let channel = FlutterMethodChannel(name: securityChannelName, binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }

      switch call.method {
      case "enableSecureWindow":
        // iOS does not provide FLAG_SECURE equivalent globally.
        result(nil)
      case "getDeviceRisk":
        result([
          "isRooted": false,
          "isJailbroken": self.isJailbroken(),
          "isEmulator": self.isRunningInSimulator(),
          "isHooked": self.isHookingDetected(),
          "isDebuggerAttached": self.isDebuggerAttached(),
        ])
      case "getAttestationToken":
        // TODO: integrate App Attest token generation and return assertion.
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func isRunningInSimulator() -> Bool {
    #if targetEnvironment(simulator)
      return true
    #else
      return false
    #endif
  }

  private func isJailbroken() -> Bool {
    #if targetEnvironment(simulator)
      return false
    #else
      let jailbreakPaths = [
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt",
      ]

      if jailbreakPaths.contains(where: { FileManager.default.fileExists(atPath: $0) }) {
        return true
      }

      if canOpen(path: "/private/jailbreak.txt") {
        return true
      }

      return false
    #endif
  }

  private func canOpen(path: String) -> Bool {
    do {
      try "test".write(toFile: path, atomically: true, encoding: .utf8)
      try FileManager.default.removeItem(atPath: path)
      return true
    } catch {
      return false
    }
  }

  private func isHookingDetected() -> Bool {
    let suspiciousFiles = [
      "/usr/lib/frida/frida-agent.dylib",
      "/Library/MobileSubstrate/DynamicLibraries/FridaGadget.dylib",
    ]

    return suspiciousFiles.contains(where: { FileManager.default.fileExists(atPath: $0) })
  }

  private func isDebuggerAttached() -> Bool {
    return isDebugging()
  }

  private func isDebugging() -> Bool {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

    let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
    if result != 0 {
      return false
    }

    return (info.kp_proc.p_flag & P_TRACED) != 0
  }
}
