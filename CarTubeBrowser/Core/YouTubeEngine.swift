import Foundation
import WebKit

/// Bộ xử lý trung tâm: Chặn quảng cáo tầng mạng (WKContentRuleList), can thiệp JSON Player,
/// giả lập băng thông 100Mbps + màn hình Retina 3x để không bị giảm chất lượng trên màn hình ô tô,
/// và tích hợp SponsorBlock.
public final class YouTubeEngine: NSObject, WKScriptMessageHandler {
    public static let shared = YouTubeEngine()
    public static let messageHandlerName = "carTubeBridge"

    /// Luật chặn quảng cáo tầng mạng WebKit (biên dịch thành bytecode gốc của Safari)
    private let contentBlockerRulesJSON = """
    [
        {
            "trigger": {
                "url-filter": ".*",
                "if-domain": ["*youtube.com", "*youtu.be", "*googlevideo.com"]
            },
            "action": {
                "type": "css-display-none",
                "selector": ".video-ads, .ytp-ad-module, .ytp-ad-overlay-container, .ytp-ad-message-container, ytm-promoted-sparkles-web-renderer, ytm-promoted-video-renderer, ytm-companion-ad-renderer, ytd-ad-slot-renderer, ytd-in-feed-ad-layout-renderer, ytd-banner-promo-renderer, .ad-container, .ad-div, #masthead-ad, #player-ads"
            }
        },
        {
            "trigger": {
                "url-filter": "(doubleclick\\\\.net|googlesyndication\\\\.com|googleadservices\\\\.com|youtube\\\\.com/api/stats/ads|youtube\\\\.com/pagead/|youtube\\\\.com/ptracking|youtube\\\\.com/get_midroll_)"
            },
            "action": {
                "type": "block"
            }
        }
    ]
    """

    /// Tạo cấu hình WKWebView đã nhúng đầy đủ bộ lọc Không Quảng Cáo + Không Giảm Chất Lượng
    public func makeConfiguredWebViewConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.websiteDataStore = .default()

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        let userContentController = WKUserContentController()
        userContentController.add(self, name: Self.messageHandlerName)

        // 1. Script chạy ngay ở DocumentStart: Giả lập màn hình 4K Retina & mạng cáp quang 100Mbps, lọc JSON quảng cáo
        let startScript = WKUserScript(
            source: buildDocumentStartScript(),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(startScript)

        // 2. Script chạy ở DocumentEnd: Ép độ phân giải cao nhất, SponsorBlock, và thanh công cụ cảm ứng CarPlay
        let endScript = WKUserScript(
            source: buildDocumentEndScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(endScript)

        config.userContentController = userContentController

        // 3. Biên dịch WKContentRuleList để chặn quảng cáo tầng mạng
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "CarTubeAdBlockRules",
            encodedContentRuleList: contentBlockerRulesJSON
        ) { ruleList, _ in
            if let ruleList = ruleList {
                DispatchQueue.main.async {
                    userContentController.add(ruleList)
                }
            }
        }

        return config
    }

    /// Script khởi chạy trước khi YouTube nạp Player:
    /// - Chặn sự kiện tắt màn hình (visibilitychange) để tắt màn hình iPhone vẫn phát mượt trên CarPlay
    /// - Giả lập PixelRatio = 3.0 và băng thông 100Mbps để YouTube không hạ độ phân giải trên màn hình xe (thường chỉ 800x480)
    /// - Xóa cấu trúc adPlacements / playerAds ngay trong phản hồi API `/youtubei/v1/player`
    private func buildDocumentStartScript() -> String {
        let targetQuality = SharedWebStore.shared.qualityPreset.rawValue
        return """
        (function() {
            'use strict';
            window.__CARTUBE_TARGET_QUALITY = '\(targetQuality)';

            // 1. Giữ trạng thái hiển thị luôn active khi khóa màn hình iPhone
            Object.defineProperty(document, 'hidden', { get: () => false, configurable: true });
            Object.defineProperty(document, 'visibilityState', { get: () => 'visible', configurable: true });
            Object.defineProperty(document, 'webkitHidden', { get: () => false, configurable: true });
            window.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);
            window.addEventListener('webkitvisibilitychange', function(e) { e.stopImmediatePropagation(); }, true);

            // 2. Giả lập mật độ điểm ảnh Retina 3x & kết nối tốc độ cao 100Mbps để không bị bóp chất lượng
            try {
                Object.defineProperty(window, 'devicePixelRatio', { get: () => 3.0, configurable: true });
                if (navigator.connection) {
                    Object.defineProperty(navigator.connection, 'effectiveType', { get: () => '4g', configurable: true });
                    Object.defineProperty(navigator.connection, 'downlink', { get: () => 100, configurable: true });
                    Object.defineProperty(navigator.connection, 'rtt', { get: () => 10, configurable: true });
                    Object.defineProperty(navigator.connection, 'saveData', { get: () => false, configurable: true });
                }
            } catch (err) {}

            // 3. Lưu cấu hình chất lượng mặc định cao nhất vào localStorage & sessionStorage của YouTube
            function writeQualityStorage() {
                try {
                    const now = Date.now();
                    const payload = JSON.stringify({
                        data: JSON.stringify({ quality: 2160, previousQuality: 2160 }),
                        expiration: now + 31536000000,
                        creation: now
                    });
                    localStorage.setItem('yt-player-quality', payload);
                    sessionStorage.setItem('yt-player-quality', payload);
                    localStorage.setItem('yt-player-av1-pref', '8192');
                } catch (e) {}
            }
            writeQualityStorage();

            // 4. Lọc bỏ adPlacements và playerAds ngay từ bước giải mã JSON của YouTube Player API
            const originalParse = JSON.parse;
            JSON.parse = function(text, reviver) {
                const data = originalParse.call(this, text, reviver);
                if (data && typeof data === 'object') {
                    if (data.adPlacements || data.playerAds || data.adSlots) {
                        delete data.adPlacements;
                        delete data.playerAds;
                        delete data.adSlots;
                        try {
                            window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({ type: 'adBlocked' });
                        } catch (e) {}
                    }
                }
                return data;
            };

            const origJson = Response.prototype.json;
            Response.prototype.json = async function() {
                const data = await origJson.call(this);
                if (data && typeof data === 'object') {
                    if (data.adPlacements || data.playerAds || data.adSlots) {
                        delete data.adPlacements;
                        delete data.playerAds;
                        delete data.adSlots;
                        try {
                            window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({ type: 'adBlocked' });
                        } catch (e) {}
                    }
                }
                return data;
            };
        })();
        """
    }

    /// Script khởi chạy khi DOM đã sẵn sàng:
    /// - Tự động ép độ phân giải cao nhất qua API nội bộ `#movie_player`
    /// - Dọn dẹp quảng cáo còn sót & tích hợp SponsorBlock
    /// - Tạo thanh điều khiển nổi tối ưu cho cảm ứng trên màn hình ô tô
    private func buildDocumentEndScript() -> String {
        return """
        (function() {
            'use strict';

            const QUALITY_PRIORITY = ['highres', 'hd2160', 'hd1440', 'hd1080', 'hd720', 'large'];

            window.__carTubeEnforceQuality = function() {
                try {
                    const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
                    if (!player) return;

                    const target = window.__CARTUBE_TARGET_QUALITY || 'hd2160';
                    if (typeof player.getAvailableQualityLevels === 'function') {
                        const available = player.getAvailableQualityLevels() || [];
                        if (available.length > 0) {
                            let chosen = available.includes(target) ? target : available[0];
                            if (typeof player.setPlaybackQualityRange === 'function') {
                                player.setPlaybackQualityRange(chosen, chosen);
                            }
                            if (typeof player.setPlaybackQuality === 'function') {
                                player.setPlaybackQuality(chosen);
                            }
                            updateQualityBadge(chosen.toUpperCase());
                        }
                    }
                } catch (e) {}
            };

            // Tự động bỏ qua nếu có bất kỳ quảng cáo video nào lọt qua
            function skipAnyActiveAd() {
                try {
                    const skipBtns = document.querySelectorAll(
                        '.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button, .videoAdUiSkipButton'
                    );
                    skipBtns.forEach(btn => btn.click());

                    const adShowing = document.querySelector('.ad-showing, .ad-interrupting');
                    if (adShowing) {
                        const video = document.querySelector('video');
                        if (video && isFinite(video.duration) && video.duration > 0) {
                            video.currentTime = video.duration;
                        }
                        const player = document.getElementById('movie_player');
                        if (player && typeof player.cancelPlayback === 'function') {
                            player.cancelPlayback();
                            player.playVideo();
                        }
                        try {
                            window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage({ type: 'adBlocked' });
                        } catch (e) {}
                    }
                } catch (e) {}
            }

            // Tích hợp SponsorBlock tự động bỏ qua đoạn giới thiệu/tài trợ trong video
            let currentVideoId = null;
            let sponsorSegments = [];

            function fetchSponsorSegments(videoId) {
                if (!videoId || videoId === currentVideoId) return;
                currentVideoId = videoId;
                sponsorSegments = [];
                fetch('https://sponsor.ajay.app/api/skipSegments?videoID=' + encodeURIComponent(videoId) + '&categories=["sponsor","selfpromo","interaction"]')
                    .then(r => r.ok ? r.json() : [])
                    .then(data => {
                        if (Array.isArray(data)) {
                            sponsorSegments = data.map(item => item.segment).filter(Boolean);
                        }
                    })
                    .catch(() => {});
            }

            function checkSponsorSkip() {
                const urlParams = new URLSearchParams(window.location.search);
                const vid = urlParams.get('v');
                if (vid && vid !== currentVideoId) {
                    fetchSponsorSegments(vid);
                }
                if (!sponsorSegments.length) return;
                const video = document.querySelector('video');
                if (!video) return;
                const t = video.currentTime;
                for (const seg of sponsorSegments) {
                    if (t >= seg[0] && t < seg[1] - 0.3) {
                        video.currentTime = seg[1];
                        break;
                    }
                }
            }

            // Gắn sự kiện theo dõi video để luôn khóa độ phân giải cao nhất
            setInterval(() => {
                skipAnyActiveAd();
                window.__carTubeEnforceQuality();
                checkSponsorSkip();
            }, 1200);

            document.addEventListener('play', function() {
                setTimeout(() => window.__carTubeEnforceQuality(), 300);
            }, true);

            // Thanh trạng thái nhỏ gọn hiển thị chất lượng thực tế trên màn hình xe
            function updateQualityBadge(label) {
                let badge = document.getElementById('cartube-quality-badge');
                if (badge) {
                    badge.textContent = 'NO ADS • ' + label;
                }
            }

            function injectCarPlayStyles() {
                if (document.getElementById('cartube-custom-style')) return;
                const style = document.createElement('style');
                style.id = 'cartube-custom-style';
                style.textContent = `
                    /* Ẩn các thành phần gây rối mắt và quảng cáo trên màn hình ô tô */
                    ytm-promoted-sparkles-web-renderer,
                    ytm-companion-ad-renderer,
                    .ytp-ad-overlay-container,
                    .mealbar-promo-renderer,
                    ytm-mealbar-promo-renderer,
                    .ytm-autonav-bar {
                        display: none !important;
                    }
                    /* Giữ khung hình video sắc nét tối đa */
                    video {
                        width: 100% !important;
                        height: 100% !important;
                    }
                `;
                document.head.appendChild(style);
            }

            injectCarPlayStyles();
        })();
        """
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageHandlerName,
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        if type == "adBlocked" {
            DispatchQueue.main.async {
                SharedWebStore.shared.blockedAdsCount += 1
            }
        }
    }
}
