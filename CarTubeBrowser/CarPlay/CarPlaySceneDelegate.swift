import UIKit
import CarPlay

/// Scene Delegate xử lý kết nối trực tiếp với màn hình Apple CarPlay (Cơ chế giống APTV: Quick -> Browser + Direct CPWindow)
@objc(CarPlaySceneDelegate)
public final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    public var interfaceController: CPInterfaceController?
    public var carWindow: CPWindow?

    // MARK: - 1. Kết nối kèm khung hình CPWindow (Hiển thị trực tiếp Trình duyệt Web YouTube lên màn hình Ô tô)
    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        self.carWindow = window
        SharedWebStore.shared.isCarPlayConnected = true

        // Gắn trực tiếp trình duyệt YouTube (kèm thanh Quick Bar cảm ứng) lên cửa sổ màn hình xe
        let browserVC = CarTubeWebViewController(isCarDisplayMode: true)
        window.rootViewController = browserVC
        window.makeKeyAndVisible()

        // Thiết lập giao diện điều khiển song song trên hệ thống template của CarPlay
        setupAPTVStyleTemplates(on: interfaceController)
    }

    // MARK: - 2. Kết nối chuẩn qua CPInterfaceController (Menu Quick -> Browser kiểu APTV)
    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        SharedWebStore.shared.isCarPlayConnected = true

        // Nếu CarPlay cấp scene window ẩn, gắn luôn WebViewController vào để hiển thị video
        if let sceneWindow = templateApplicationScene.carWindow {
            self.carWindow = sceneWindow
            sceneWindow.rootViewController = CarTubeWebViewController(isCarDisplayMode: true)
            sceneWindow.makeKeyAndVisible()
        }

        setupAPTVStyleTemplates(on: interfaceController)
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.carWindow = nil
        SharedWebStore.shared.isCarPlayConnected = false
    }

    // MARK: - Thiết lập Menu "Quick" & "Browser" giống ứng dụng APTV
    private func setupAPTVStyleTemplates(on controller: CPInterfaceController) {
        // Tab 1: Quick -> Browser (Danh sách các trang ghim sẵn: YouTube, YouTube TV, YouTube Music...)
        let siteItems: [CPListItem] = SharedWebStore.shared.pinnedSites.map { site in
            let item = CPListItem(
                text: site.title,
                detailText: site.subtitle,
                image: UIImage(systemName: site.iconSystemName)
            )
            item.handler = { [weak self] _, completion in
                SharedWebStore.shared.loadURL(site.urlString)
                self?.ensureBrowserWindowVisible()
                completion()
            }
            return item
        }

        let browserSection = CPListSection(
            items: siteItems,
            header: "Quick Browser (Không Quảng Cáo)",
            sectionIndexTitle: nil
        )

        // Mục điều khiển nhanh trên vô lăng / màn hình
        let playPauseItem = CPListItem(
            text: "Phát / Tạm dừng Video",
            detailText: "Điều khiển trực tiếp trình phát YouTube",
            image: UIImage(systemName: "playpause.fill")
        )
        playPauseItem.handler = { _, completion in
            SharedWebStore.shared.togglePlayPause()
            completion()
        }

        let nextItem = CPListItem(
            text: "Chuyển Video Tiếp Theo",
            detailText: "Bỏ qua sang video kế tiếp",
            image: UIImage(systemName: "forward.end.fill")
        )
        nextItem.handler = { _, completion in
            SharedWebStore.shared.nextVideo()
            completion()
        }

        let fullScreenItem = CPListItem(
            text: "Phóng Đầy Màn Hình Ô Tô (Zoom Fit)",
            detailText: "Xóa viền đen hai bên trên màn hình xe cỡ rộng",
            image: UIImage(systemName: "arrow.up.left.and.arrow.down.right")
        )
        fullScreenItem.handler = { _, completion in
            SharedWebStore.shared.isFullBleedZoom.toggle()
            completion()
        }

        let controlsSection = CPListSection(
            items: [playPauseItem, nextItem, fullScreenItem],
            header: "Điều khiển nhanh",
            sectionIndexTitle: nil
        )

        let quickBrowserTemplate = CPListTemplate(
            title: "Quick • Browser",
            sections: [browserSection, controlsSection]
        )
        quickBrowserTemplate.tabTitle = "Browser"
        quickBrowserTemplate.tabImage = UIImage(systemName: "globe")

        // Tab 2: Độ phân giải gốc (Khóa 4K / 2K / 1080p60 không bị bóp băng thông)
        let qualityItems: [CPListItem] = VideoQualityPreset.allCases.map { preset in
            let item = CPListItem(
                text: preset.displayName,
                detailText: "Khóa cố định chất lượng \(preset.rawValue.uppercased())",
                image: UIImage(systemName: "sparkles.tv.fill")
            )
            item.handler = { _, completion in
                SharedWebStore.shared.qualityPreset = preset
                completion()
            }
            return item
        }

        let qualitySection = CPListSection(
            items: qualityItems,
            header: "Khóa Chất Lượng Video Gốc",
            sectionIndexTitle: nil
        )
        let qualityTemplate = CPListTemplate(
            title: "Chất Lượng",
            sections: [qualitySection]
        )
        qualityTemplate.tabTitle = "Chất Lượng HD"
        qualityTemplate.tabImage = UIImage(systemName: "4k.tv.fill")

        // Nếu hệ thống cho phép MapTemplate (để lấy toàn bộ khung vẽ cảm ứng của CarPlay)
        let mapCanvasTemplate = CPMapTemplate()
        let reloadBarButton = CPBarButton(title: "Tải lại") { _ in
            SharedWebStore.shared.reload()
        }
        let zoomBarButton = CPBarButton(title: "Đầy màn") { _ in
            SharedWebStore.shared.isFullBleedZoom.toggle()
        }
        mapCanvasTemplate.leadingNavigationBarButtons = [reloadBarButton]
        mapCanvasTemplate.trailingNavigationBarButtons = [zoomBarButton]
        mapCanvasTemplate.tabTitle = "Màn Hình Video"
        mapCanvasTemplate.tabImage = UIImage(systemName: "play.tv.fill")

        let tabBar = CPTabBarTemplate(templates: [quickBrowserTemplate, qualityTemplate, mapCanvasTemplate])
        controller.setRootTemplate(tabBar, animated: true, completion: nil)
    }

    private func ensureBrowserWindowVisible() {
        guard let window = carWindow else { return }
        if window.rootViewController == nil {
            window.rootViewController = CarTubeWebViewController(isCarDisplayMode: true)
        }
        window.makeKeyAndVisible()
    }
}

/// Scene Delegate dành cho chế độ Màn hình ngoài / AirPlay Video trên ô tô (Không cần chứng chỉ CarPlay đặc biệt!)
@objc(ExternalDisplaySceneDelegate)
public final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    public var window: UIWindow?

    public func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Tắt chế độ overscan compensation để hình ảnh xuất ra màn hình ô tô sắc nét từng điểm ảnh (1:1 Pixel Mapping)
        windowScene.screen.overscanCompensation = .none

        let externalWindow = UIWindow(windowScene: windowScene)
        externalWindow.rootViewController = CarTubeWebViewController(isCarDisplayMode: true)
        externalWindow.makeKeyAndVisible()
        self.window = externalWindow
        SharedWebStore.shared.isCarPlayConnected = true
    }

    public func sceneDidDisconnect(_ scene: UIScene) {
        self.window = nil
        SharedWebStore.shared.isCarPlayConnected = false
    }
}
