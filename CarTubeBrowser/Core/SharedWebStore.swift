import Foundation
import Combine
import WebKit

/// Độ phân giải mục tiêu để ép YouTube luôn phát chất lượng cao nhất, không bị bóp băng thông
public enum VideoQualityPreset: String, CaseIterable, Identifiable {
    case maxAvailable = "hd2160" // Tự động ưu tiên 4K -> 2K -> 1080p60
    case qhd1440 = "hd1440"      // 2K QHD (1440p60)
    case fhd1080 = "hd1080"      // Full HD (1080p60)
    case hd720 = "hd720"         // HD (720p60)

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .maxAvailable: return "Tối đa (4K / 2K / 1080p60)"
        case .qhd1440: return "2K QHD (1440p60)"
        case .fhd1080: return "Full HD (1080p60)"
        case .hd720: return "HD (720p)"
        }
    }
}

/// Danh mục lối tắt nhanh trong menu Quick -> Browser (giống APTV)
public struct QuickSiteItem: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let urlString: String
    public let iconSystemName: String

    public init(id: String = UUID().uuidString, title: String, subtitle: String, urlString: String, iconSystemName: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.urlString = urlString
        self.iconSystemName = iconSystemName
    }
}

/// Quản lý trạng thái đồng bộ giữa màn hình iPhone và màn hình ô tô (CarPlay / External Display)
public final class SharedWebStore: ObservableObject {
    public static let shared = SharedWebStore()

    @Published public var currentURLString: String = "https://m.youtube.com"
    @Published public var pageTitle: String = "YouTube CarPlay"
    @Published public var isLoading: Bool = false
    @Published public var canGoBack: Bool = false
    @Published public var canGoForward: Bool = false

    @Published public var qualityPreset: VideoQualityPreset = .maxAvailable {
        didSet {
            UserDefaults.standard.set(qualityPreset.rawValue, forKey: "cartube_quality_preset")
            applyQualitySettingsToAllWebViews()
        }
    }

    @Published public var adBlockEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(adBlockEnabled, forKey: "cartube_adblock_enabled")
        }
    }

    @Published public var sponsorBlockEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(sponsorBlockEnabled, forKey: "cartube_sponsorblock_enabled")
        }
    }

    @Published public var isFullBleedZoom: Bool = false {
        didSet {
            toggleZoomModeOnAllWebViews()
        }
    }

    @Published public var blockedAdsCount: Int = 0
    @Published public var isCarPlayConnected: Bool = false
    @Published public var pinnedSites: [QuickSiteItem] = [
        QuickSiteItem(
            id: "yt-main",
            title: "YouTube (No Ads + Max HD)",
            subtitle: "Giao diện cảm ứng tối ưu cho màn hình xe",
            urlString: "https://m.youtube.com",
            iconSystemName: "play.rectangle.fill"
        ),
        QuickSiteItem(
            id: "yt-tv",
            title: "YouTube TV Mode (Giao diện Ô tô)",
            subtitle: "Nút bấm lớn cho màn hình CarPlay",
            urlString: "https://www.youtube.com/tv",
            iconSystemName: "tv.fill"
        ),
        QuickSiteItem(
            id: "yt-music",
            title: "YouTube Music",
            subtitle: "Nghe nhạc & MV chất lượng gốc",
            urlString: "https://music.youtube.com",
            iconSystemName: "music.note.tv.fill"
        ),
        QuickSiteItem(
            id: "invidious",
            title: "Invidious (YouTube Siêu Nhẹ)",
            subtitle: "Không quảng cáo, tải cực nhanh",
            urlString: "https://yewtu.be",
            iconSystemName: "bolt.shield.fill"
        )
    ]

    /// Giữ tham chiếu yếu tới các WKWebView đang hoạt động (trên iPhone và trên CarPlay)
    private var activeWebViews: NSHashTable<WKWebView> = NSHashTable.weakObjects()

    private init() {
        if let savedQuality = UserDefaults.standard.string(forKey: "cartube_quality_preset"),
           let preset = VideoQualityPreset(rawValue: savedQuality) {
            self.qualityPreset = preset
        }
        if UserDefaults.standard.object(forKey: "cartube_adblock_enabled") != nil {
            self.adBlockEnabled = UserDefaults.standard.bool(forKey: "cartube_adblock_enabled")
        }
        if UserDefaults.standard.object(forKey: "cartube_sponsorblock_enabled") != nil {
            self.sponsorBlockEnabled = UserDefaults.standard.bool(forKey: "cartube_sponsorblock_enabled")
        }
    }

    public func registerWebView(_ webView: WKWebView) {
        if !activeWebViews.contains(webView) {
            activeWebViews.add(webView)
        }
    }

    public func loadURL(_ urlString: String) {
        var formatted = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.hasPrefix("http://") && !formatted.hasPrefix("https://") {
            // Nếu người dùng nhập từ khóa tìm kiếm thay vì URL
            if !formatted.contains(".") || formatted.contains(" ") {
                let encoded = formatted.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                formatted = "https://m.youtube.com/results?search_query=\(encoded)"
            } else {
                formatted = "https://" + formatted
            }
        }
        guard let url = URL(string: formatted) else { return }
        DispatchQueue.main.async {
            self.currentURLString = formatted
            for webView in self.activeWebViews.allObjects {
                webView.load(URLRequest(url: url))
            }
        }
    }

    public func searchYouTube(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        loadURL("https://m.youtube.com/results?search_query=\(encoded)")
    }

    public func goBack() {
        for webView in activeWebViews.allObjects where webView.canGoBack {
            webView.goBack()
        }
    }

    public func goForward() {
        for webView in activeWebViews.allObjects where webView.canGoForward {
            webView.goForward()
        }
    }

    public func reload() {
        for webView in activeWebViews.allObjects {
            webView.reload()
        }
    }

    public func togglePlayPause() {
        let js = """
        (function() {
            const video = document.querySelector('video');
            if (video) {
                if (video.paused) { video.play(); } else { video.pause(); }
            }
        })();
        """
        evaluateJavaScriptOnAll(js)
    }

    public func skipForward(seconds: Double = 10) {
        let js = """
        (function() {
            const video = document.querySelector('video');
            if (video) { video.currentTime += \(seconds); }
        })();
        """
        evaluateJavaScriptOnAll(js)
    }

    public func nextVideo() {
        let js = """
        (function() {
            const player = document.getElementById('movie_player');
            if (player && player.nextVideo) {
                player.nextVideo();
                return;
            }
            const nextBtn = document.querySelector('.ytp-next-button, a.ytp-next-button');
            if (nextBtn) { nextBtn.click(); }
        })();
        """
        evaluateJavaScriptOnAll(js)
    }

    public func applyQualitySettingsToAllWebViews() {
        let js = "window.__CARTUBE_TARGET_QUALITY = '\(qualityPreset.rawValue)'; if (window.__carTubeEnforceQuality) { window.__carTubeEnforceQuality(); }"
        evaluateJavaScriptOnAll(js)
    }

    private func toggleZoomModeOnAllWebViews() {
        let fitMode = isFullBleedZoom ? "cover" : "contain"
        let js = """
        (function() {
            const styleId = 'cartube-video-fit-style';
            let styleEl = document.getElementById(styleId);
            if (!styleEl) {
                styleEl = document.createElement('style');
                styleEl.id = styleId;
                document.head.appendChild(styleEl);
            }
            styleEl.textContent = 'video { object-fit: \(fitMode) !important; }';
        })();
        """
        evaluateJavaScriptOnAll(js)
    }

    public func evaluateJavaScriptOnAll(_ script: String) {
        DispatchQueue.main.async {
            for webView in self.activeWebViews.allObjects {
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
        }
    }
}
