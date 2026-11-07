# CarTube TV (APTV-Style CarPlay YouTube Browser)

Ứng dụng iOS phát trực tiếp **YouTube trên màn hình ô tô (Apple CarPlay / Màn hình ngoài)** theo cơ chế trình duyệt nhúng giống hệt **APTV (`Quick -> Browser`)**, tích hợp sẵn:
- **Không giảm chất lượng (Max HD Lock)**: Giả lập màn hình Retina 3x (`devicePixelRatio = 3.0`) và đường truyền 100Mbps, đồng thời khóa cứng API `#movie_player` ở độ phân giải cao nhất (`4K 2160p` / `2K 1440p` / `Full HD 1080p60`), khắc phục triệt để tình trạng YouTube tự hạ xuống 360p/480p khi phát trên màn hình xe hơi hoặc sóng 4G/5G.
- **Không quảng cáo (AdBlock + SponsorBlock)**:
  1. Bộ lọc tầng mạng gốc WebKit (`WKContentRuleList`) chặn toàn bộ máy chủ quảng cáo YouTube.
  2. Can thiệp trực tiếp `JSON.parse` & `Response.prototype.json` để xóa `adPlacements`, `playerAds`, `adSlots` trước khi trình phát nạp video.
  3. Tích hợp **SponsorBlock API** tự động tua qua các đoạn giới thiệu/tài trợ trong video.
- **Không tắt hình khi khóa màn hình iPhone**: Chặn sự kiện `visibilitychange` và cấu hình `AVAudioSession` chuẩn `.moviePlayback` + `.allowAirPlay`, hỗ trợ điều khiển qua các phím cứng trên vô lăng xe (`MPRemoteCommandCenter`).

---

## Cấu trúc dự án

- [`project.yml`](project.yml): Cấu hình dự án Xcode tự động thông qua XcodeGen.
- [`.github/workflows/build-ipa.yml`](.github/workflows/build-ipa.yml): Workflow tự động biên dịch ra file `.ipa` trên đám mây GitHub (dành cho người dùng Windows không cần máy Mac).
- [`CarTubeBrowser/App/CarTubeBrowserApp.swift`](CarTubeBrowser/App/CarTubeBrowserApp.swift): Điểm khởi chạy ứng dụng, cấu hình âm thanh xe hơi, phím bấm vô lăng và điều phối 3 màn hình (`PhoneSceneDelegate`, `CarPlaySceneDelegate`, `ExternalDisplaySceneDelegate`).
- [`CarTubeBrowser/Core/YouTubeEngine.swift`](CarTubeBrowser/Core/YouTubeEngine.swift): Lõi lọc quảng cáo 3 lớp và ép độ phân giải gốc 4K/2K/1080p60.
- [`CarTubeBrowser/Core/SharedWebStore.swift`](CarTubeBrowser/Core/SharedWebStore.swift): Trạng thái đồng bộ thời gian thực giữa iPhone và màn hình ô tô.
- [`CarTubeBrowser/CarPlay/CarPlaySceneDelegate.swift`](CarTubeBrowser/CarPlay/CarPlaySceneDelegate.swift): Giao diện CarPlay theo phong cách **APTV (`Quick -> Browser`)** kèm khung trình duyệt trực tiếp trên màn hình xe và chế độ `ExternalDisplaySceneDelegate` (không yêu cầu chứng chỉ CarPlay đặc biệt).
- [`CarTubeBrowser/Views/WebBrowserView.swift`](CarTubeBrowser/Views/WebBrowserView.swift): Trình duyệt YouTube kèm thanh công cụ cảm ứng cỡ lớn cho màn hình ô tô.
- [`CarTubeBrowser/Views/MainView.swift`](CarTubeBrowser/Views/MainView.swift): Giao diện trên iPhone gồm tab `Browser` và tab `Quick (Ô tô)`.

---

## Cách lấy file `.ipa` và cài đặt trên Windows (Không cần chứng chỉ trả phí)

### Bước 1: Tự động tạo file `.ipa` bằng GitHub Actions
1. Tạo 1 repository mới trên GitHub và đẩy toàn bộ thư mục này lên:
   ```powershell
   git init
   git add .
   git commit -m "Initial CarTube TV (APTV-style CarPlay Browser)"
   git branch -M main
   git remote add origin https://github.com/<ten-tai-khoan>/<ten-repo>.git
   git push -u origin main
   ```
2. Vào mục **Actions** trên GitHub -> Chọn workflow **Build CarTubeBrowser IPA (No Certificate Required)**.
3. Sau khoảng 2 phút, tải file nén **CarTubeBrowser-IPA-Files** về máy tính, bên trong có sẵn 2 bản:
   - `CarTubeBrowser-FreeAppleID.ipa`: Cài trực tiếp bằng **Sideloadly** hoặc **AltStore / SideStore** chỉ với tài khoản Apple ID thông thường (không cần mua chứng chỉ).
   - `CarTubeBrowser-FullCarPlay.ipa`: Bản đính kèm sẵn quyền CarPlay mở rộng (dành cho ESign / KSign / Feather / TrollStore).

### Bước 2: Cài vào iPhone qua Sideloadly (Trên Windows)
1. Tải và mở **Sideloadly** trên máy tính Windows, cắm cáp iPhone vào máy.
2. Kéo file `CarTubeBrowser-FreeAppleID.ipa` vào Sideloadly, nhập Apple ID miễn phí của bạn rồi bấm **Start**.
3. Trên iPhone, vào **Cài đặt -> Cài đặt chung -> Quản lý VPN & Thiết bị** -> Tin cậy ứng dụng.

### Bước 3: Sử dụng trên Ô tô (Như APTV)
- Kết nối iPhone với màn hình ô tô qua CarPlay hoặc AirPlay.
- Mở **CarTube TV**, vào mục **Quick -> Browser -> YouTube (No Ads + Max HD)** hoặc bấm biểu tượng truyền màn hình ở góc trên bên phải để xem trực tiếp trên màn hình xe với chất lượng 1080p60/2K/4K và không có quảng cáo.
