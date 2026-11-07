import SwiftUI

public struct MainView: View {
    @ObservedObject private var store = SharedWebStore.shared
    @State private var selectedTab: Int = 0
    @State private var addressInput: String = ""
    @State private var newSiteTitle: String = ""
    @State private var newSiteURL: String = ""
    @State private var showingAddSiteSheet: Bool = false

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            // TAB 1: TRÌNH DUYỆT YOUTUBE KHÔNG QUẢNG CÁO
            browserTabView
                .tabItem {
                    Label("Browser", systemImage: "play.tv.fill")
                }
                .tag(0)

            // TAB 2: QUICK MENU (GIỐNG ỨNG DỤNG APTV)
            quickMenuTabView
                .tabItem {
                    Label("Quick (Ô tô)", systemImage: "car.fill")
                }
                .tag(1)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Tab 1: Trình duyệt trực tiếp
    private var browserTabView: some View {
        VStack(spacing: 0) {
            // Thanh điều khiển trên cùng
            HStack(spacing: 10) {
                Button(action: { store.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(store.canGoBack ? .white : .gray)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .disabled(!store.canGoBack)

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 13))

                    TextField("Tìm kiếm YouTube hoặc nhập địa chỉ web...", text: $addressInput, onCommit: {
                        if !addressInput.isEmpty {
                            store.loadURL(addressInput)
                        }
                    })
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                    if !addressInput.isEmpty {
                        Button(action: { addressInput = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)

                // Nút chọn chất lượng gốc không giảm độ phân giải
                Menu {
                    Picker("Chất lượng Video", selection: $store.qualityPreset) {
                        ForEach(VideoQualityPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    Divider()
                    Button(action: { store.isFullBleedZoom.toggle() }) {
                        Label(
                            store.isFullBleedZoom ? "Tắt phóng đầy màn xe" : "Phóng đầy màn hình xe",
                            systemImage: "arrow.up.left.and.arrow.down.right"
                        )
                    }
                    Button(action: { store.reload() }) {
                        Label("Tải lại trang", systemImage: "arrow.clockwise")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles.tv.fill")
                            .font(.system(size: 12))
                        Text(store.qualityPreset.rawValue.uppercased())
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .frame(height: 34)
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(8)
                }

                // Nút phát hình ảnh lên màn hình xe qua AirPlay Video / CarPlay
                AirPlayRoutePickerButton()
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.07, green: 0.07, blue: 0.09))

            // Dải trạng thái Chặn Quảng Cáo & Kết nối CarPlay
            HStack {
                Label("Đã chặn \(store.blockedAdsCount) QC • SponsorBlock Bật", systemImage: "shield.checkered")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(store.isCarPlayConnected ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(store.isCarPlayConnected ? "Đang phát trên màn hình Ô tô" : "Chế độ Sẵn sàng CarPlay")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Color.black)

            // Khung trình duyệt YouTube
            WebBrowserView()
                .edgesIgnoringSafeArea(.bottom)
        }
    }

    // MARK: - Tab 2: Menu Quick -> Browser giống ứng dụng APTV
    private var quickMenuTabView: some View {
        NavigationView {
            List {
                Section(header: Text("Lối tắt Nhanh trên Màn Hình Ô Tô (Quick Browser)")) {
                    ForEach(store.pinnedSites) { site in
                        Button(action: {
                            store.loadURL(site.urlString)
                            selectedTab = 0
                        }) {
                            HStack(spacing: 14) {
                                Image(systemName: site.iconSystemName)
                                    .font(.system(size: 22))
                                    .foregroundColor(.red)
                                    .frame(width: 38, height: 38)
                                    .background(Color.red.opacity(0.15))
                                    .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(site.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(site.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section(header: Text("Cấu hình Chất Lượng & Chặn Quảng Cáo")) {
                    Picker("Độ phân giải cố định", selection: $store.qualityPreset) {
                        ForEach(VideoQualityPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }

                    Toggle("Chặn toàn bộ Quảng cáo YouTube", isOn: $store.adBlockEnabled)
                    Toggle("Tự động tua qua đoạn tài trợ (SponsorBlock)", isOn: $store.sponsorBlockEnabled)
                    Toggle("Phóng đầy màn hình rộng trên xe (Full-Bleed)", isOn: $store.isFullBleedZoom)
                }

                Section(header: Text("Hướng dẫn phát lên màn hình Ô tô (Như APTV)")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Cắm cáp hoặc kết nối không dây iPhone với Apple CarPlay trên xe.")
                        Text("2. Mở ứng dụng CarTube TV trên màn hình xe, chọn mục Quick -> Browser -> YouTube.")
                        Text("3. Hoặc nhấn biểu tượng AirPlay ở góc phải trên cùng để truyền hình ảnh trực tiếp độ phân giải gốc (1080p/2K/4K) lên màn hình xe.")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Quick • CarPlay TV")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSiteSheet = true }) {
                        Label("Thêm trang", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddSiteSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("Thêm trang web / Kênh mới vào Quick Menu")) {
                            TextField("Tên hiển thị (VD: VTV Go, PhimMoi...)", text: $newSiteTitle)
                            TextField("Địa chỉ URL (VD: https://vtvgo.vn)", text: $newSiteURL)
                                .autocapitalization(.none)
                                .keyboardType(.URL)
                        }
                    }
                    .navigationTitle("Thêm Lối Tắt")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Hủy") { showingAddSiteSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Lưu") {
                                guard !newSiteTitle.isEmpty, !newSiteURL.isEmpty else { return }
                                store.pinnedSites.append(
                                    QuickSiteItem(
                                        title: newSiteTitle,
                                        subtitle: newSiteURL,
                                        urlString: newSiteURL,
                                        iconSystemName: "globe"
                                    )
                                )
                                newSiteTitle = ""
                                newSiteURL = ""
                                showingAddSiteSheet = false
                            }
                        }
                    }
                }
            }
        }
    }
}
