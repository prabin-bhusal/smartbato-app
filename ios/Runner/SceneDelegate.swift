import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
	private var privacyOverlay: UIView?

	override func scene(
		_ scene: UIScene,
		willConnectTo session: UISceneSession,
		options connectionOptions: UIScene.ConnectionOptions
	) {
		super.scene(scene, willConnectTo: session, options: connectionOptions)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleCaptureChange),
			name: UIScreen.capturedDidChangeNotification,
			object: nil
		)

		handleCaptureChange()
	}

	override func sceneWillResignActive(_ scene: UIScene) {
		showPrivacyOverlay()
	}

	override func sceneDidBecomeActive(_ scene: UIScene) {
		hidePrivacyOverlayIfAllowed()
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	@objc private func handleCaptureChange() {
		if UIScreen.main.isCaptured {
			showPrivacyOverlay()
		} else {
			hidePrivacyOverlayIfAllowed()
		}
	}

	private func showPrivacyOverlay() {
		guard let window = self.window else {
			return
		}

		if privacyOverlay == nil {
			let overlay = UIView(frame: window.bounds)
			overlay.backgroundColor = UIColor.black

			let label = UILabel()
			label.translatesAutoresizingMaskIntoConstraints = false
			label.text = "Screen capture blocked"
			label.textColor = UIColor.white
			label.font = UIFont.boldSystemFont(ofSize: 20)

			overlay.addSubview(label)
			NSLayoutConstraint.activate([
				label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
				label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
			])

			privacyOverlay = overlay
		}

		if let overlay = privacyOverlay, overlay.superview == nil {
			overlay.frame = window.bounds
			window.addSubview(overlay)
		}
	}

	private func hidePrivacyOverlayIfAllowed() {
		if UIScreen.main.isCaptured {
			return
		}

		privacyOverlay?.removeFromSuperview()
	}

}
