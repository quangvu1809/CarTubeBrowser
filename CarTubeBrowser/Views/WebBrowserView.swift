import SwiftUI
import UIKit
import WebKit
import AVKit

/// UIViewController hiển thị trình duyệt YouTube Không Quảng Cáo + Độ Phân Giải Gốc
/// Dùng chung cho cả màn hình iPhone và màn hình CarPlay / Màn hình ngoài của Ô tô (kiểu APTV)
public final class CarTubeWebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private var webView: WKWebView!
    private let isCarDisplayMode: Bool
    private var topToolbar: UIView!
    private var qualityButton: UIButton!
    private var zoomButton: UIButton!

    // Custom User-Agent giúp YouTube cấp luồng High-Bitrate 1080p60/1440p/4K VP9/H264 ổn định
    private let highResUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
    private let mobileTouchUserAgent = "Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

    public init(isCarDisplayMode: Bool = false) {
        self.isCarDisplayMode = isCarDisplayMode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.isCarDisplayMode = false
        super.init(coder: coder)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebView()
        if isCarDisplayMode {
            setupCarDisplayOverlayBar()
        }
        loadInitialURL()
    }

    private func setupWebView() {
        let config = YouTubeEngine.shared.makeConfiguredWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.backgroundColor = .black
        webView.isOpaque = false

        // Dùng User-Agent iPadOS/Desktop để YouTube luôn mở khóa luồng 1080p60 / 2K / 4K mà vẫn giữ giao diện cảm ứng lớn
        webView.customUserAgent = mobileTouchUserAgent

        view.addSubview(webView)
        SharedWebStore.shared.registerWebView(webView)

        if isCarDisplayMode {
            // Chừa 44pt phía trên cho thanh điều khiển nhanh trên màn hình xe
            NSLayoutConstraint.activate([
                webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                webView.topAnchor.constraint(equalTo: view.topAnchor, constant: 44)
            ])
        } else {
            NSLayoutConstraint.activate([
                webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                webView.topAnchor.constraint(equalTo: view.topAnchor),
                webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
    }

    /// Thanh công cụ cảm ứng chuyên dụng hiển thị trực tiếp trên màn hình Ô tô (giống Quick Browser của APTV)
    private func setupCarDisplayOverlayBar() {
        topToolbar = UIView()
        topToolbar.translatesAutoresizingMaskIntoConstraints = false
        topToolbar.backgroundColor = UIColor(white: 0.08, alpha: 0.96)
        view.addSubview(topToolbar)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.distribution = .fillProportionally
        stack.translatesAutoresizingMaskIntoConstraints = false
        topToolbar.addSubview(stack)

        let backBtn = makeBarButton(title: "◀ Quay lại", action: #selector(handleBack))
        let homeBtn = makeBarButton(title: "🏠 YouTube", action: #selector(handleHome))
        let tvBtn = makeBarButton(title: "📺 YT TV", action: #selector(handleTVMode))
        let musicBtn = makeBarButton(title: "🎵 Music", action: #selector(handleMusicMode))

        qualityButton = makeBarButton(title: "✨ MAX HD", action: #selector(handleCycleQuality))
        qualityButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.85)

        zoomButton = makeBarButton(title: "⛶ Đầy màn", action: #selector(handleToggleZoom))
        let reloadBtn = makeBarButton(title: "↻", action: #selector(handleReload))

        [backBtn, homeBtn, tvBtn, musicBtn, qualityButton, zoomButton, reloadBtn].forEach {
            stack.addArrangedSubview($0)
        }

        NSLayoutConstraint.activate([
            topToolbar.topAnchor.constraint(equalTo: view.topAnchor),
            topToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topToolbar.heightAnchor.constraint(equalToConstant: 44),

            stack.leadingAnchor.constraint(equalTo: topToolbar.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: topToolbar.trailingAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: topToolbar.centerYAnchor),
            stack.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func makeBarButton(title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        btn.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        btn.layer.cornerRadius = 8
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    private func loadInitialURL() {
        if let url = URL(string: SharedWebStore.shared.currentURLString) {
            webView.load(URLRequest(url: url))
        }
    }

    @objc private func handleBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    @objc private func handleHome() {
        webView.customUserAgent = mobileTouchUserAgent
        SharedWebStore.shared.loadURL("https://m.youtube.com")
    }

    @objc private func handleTVMode() {
        webView.customUserAgent = highResUserAgent
        SharedWebStore.shared.loadURL("https://www.youtube.com/tv")
    }

    @objc private func handleMusicMode() {
        webView.customUserAgent = highResUserAgent
        SharedWebStore.shared.loadURL("https://music.youtube.com")
    }

    @objc private func handleCycleQuality() {
        let all = VideoQualityPreset.allCases
        if let idx = all.firstIndex(of: SharedWebStore.shared.qualityPreset) {
            let next = all[(idx + 1) % all.count]
            SharedWebStore.shared.qualityPreset = next
            qualityButton?.setTitle("✨ \(next.rawValue.uppercased())", for: .normal)
        }
    }

    @objc private func handleToggleZoom() {
        SharedWebStore.shared.isFullBleedZoom.toggle()
        let isZoom = SharedWebStore.shared.isFullBleedZoom
        zoomButton?.backgroundColor = isZoom ? UIColor.systemBlue : UIColor(white: 0.2, alpha: 1.0)
    }

    @objc private func handleReload() {
        webView.reload()
    }

    // MARK: - WKNavigationDelegate

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        DispatchQueue.main.async {
            SharedWebStore.shared.isLoading = true
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async {
            SharedWebStore.shared.isLoading = false
            SharedWebStore.shared.canGoBack = webView.canGoBack
            SharedWebStore.shared.canGoForward = webView.canGoForward
            if let urlStr = webView.url?.absoluteString {
                SharedWebStore.shared.currentURLString = urlStr
            }
            if let title = webView.title, !title.isEmpty {
                SharedWebStore.shared.pageTitle = title
            }
            SharedWebStore.shared.applyQualitySettingsToAllWebViews()
        }
    }

    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Mở mọi popup/link mới ngay trong cùng khung trình duyệt trên xe
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}

/// SwiftUI Wrapper dùng trên màn hình chính iPhone
public struct WebBrowserView: UIViewControllerRepresentable {
    public init() {}

    public func makeUIViewController(context: Context) -> CarTubeWebViewController {
        return CarTubeWebViewController(isCarDisplayMode: false)
    }

    public func updateUIViewController(_ uiViewController: CarTubeWebViewController, context: Context) {}
}

/// Nút chọn đầu ra AirPlay Video (dành cho các dòng xe hỗ trợ AirPlay / CarPlay Video trên iOS mới nhất)
public struct AirPlayRoutePickerButton: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = .white
        picker.activeTintColor = .systemRed
        picker.prioritizesVideoDevices = true
        return picker
    }

    public func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
