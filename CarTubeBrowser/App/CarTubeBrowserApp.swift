import UIKit
import SwiftUI
import AVFoundation
import MediaPlayer

@main
public final class AppDelegate: UIResponder, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureCarAudioAndAirPlaySession()
        configureSteeringWheelControls()
        return true
    }

    /// Cấu hình phiên âm thanh chuẩn MoviePlayback + AirPlay để phát liên tục trên loa ô tô khi tắt màn hình iPhone
    private func configureCarAudioAndAirPlaySession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
            )
            try session.setActive(true)
        } catch {
            print("CarTubeBrowser AudioSession Error: \(error)")
        }
    }

    /// Kết nối các phím cứng trên vô lăng ô tô (Play/Pause, Qua bài, Tua nhanh) với trình phát YouTube
    private func configureSteeringWheelControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            SharedWebStore.shared.togglePlayPause()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            SharedWebStore.shared.togglePlayPause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            SharedWebStore.shared.togglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { _ in
            SharedWebStore.shared.nextVideo()
            return .success
        }

        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [10]
        commandCenter.skipForwardCommand.addTarget { _ in
            SharedWebStore.shared.skipForward(seconds: 10)
            return .success
        }
    }

    // MARK: - Định tuyến Scene (iPhone, CarPlay, và Màn hình ngoài của Ô tô)
    public func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role.rawValue == "CPTemplateApplicationSceneSessionRoleApplication" {
            let config = UISceneConfiguration(name: "CarPlay Configuration", sessionRole: connectingSceneSession.role)
            config.delegateClass = CarPlaySceneDelegate.self
            return config
        }

        if connectingSceneSession.role == .windowExternalDisplayNonInteractive ||
           connectingSceneSession.role.rawValue.contains("ExternalDisplay") {
            let config = UISceneConfiguration(name: "CarExternalDisplay Configuration", sessionRole: connectingSceneSession.role)
            config.delegateClass = ExternalDisplaySceneDelegate.self
            return config
        }

        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = PhoneSceneDelegate.self
        return config
    }
}

/// Scene Delegate chính hiển thị giao diện điều khiển và trình duyệt trên màn hình iPhone
@objc(PhoneSceneDelegate)
public final class PhoneSceneDelegate: UIResponder, UIWindowSceneDelegate {
    public var window: UIWindow?

    public func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let mainWindow = UIWindow(windowScene: windowScene)
        mainWindow.rootViewController = UIHostingController(rootView: MainView())
        mainWindow.makeKeyAndVisible()
        self.window = mainWindow
    }
}
