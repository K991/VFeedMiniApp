import SwiftUI
import UIKit
import Combine
import WebKit
import PhotosUI

@main
struct VFeedMiniApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - Config

enum AppConfig {
    static let apiVersion = "5.199"

    static let manualAuthURL =
        "https://oauth.vk.com/authorize?client_id=2685278&display=mobile&redirect_uri=https://oauth.vk.com/blank.html&scope=groups,wall,offline,messages,docs,photos,stories&response_type=token&v=5.199"

    static let adminURL = "https://admin.streamvi.io"
    static let yandexMessengerURL = "https://messenger.360.yandex.ru/#/"
    static let yandexAuthURL = "https://passport.yandex.ru/pwl-yandex/auth"
    static let scheduleDownloadAPI = "https://cloud-api.yandex.net/v1/disk/public/resources/download?public_key=https://disk.yandex.ru/d/CVHoMUDLjuKCFA&path=/current.jpg"

    static let defaultGroupId = 158819144
    static let defaultGroupName = "StreamVi | Сервис ретрансляций | Рестрим"
    static let defaultGroupScreenName = "streamvi"
}

// MARK: - Models

struct VKAPIError: Decodable {
    let error_code: Int
    let error_msg: String
}

struct AuthorizedUserSession {
    let accessToken: String
    let userId: Int
}

struct ManagedGroup: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let photoURLString: String?
    let role: String
    let screenName: String?

    var photoURL: URL? {
        guard let photoURLString else { return nil }
        return URL(string: photoURLString)
    }
}

enum RootTab: String, Codable {
    case wall
    case messages
    case admin
    case yandex
    case settings
}

struct FullscreenPhoto: Identifiable {
    let id = UUID()
    let url: URL
}

struct MessageTemplate: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let text: String
}

struct YandexDiskDownloadResponse: Decodable {
    let href: String
}

enum YandexAuthState {
    case checking
    case authorized
    case unauthorized
}

enum SharedWebContext {
    static let processPool = WKProcessPool()
}

// MARK: - Groups API

struct VKGroupsEnvelope: Decodable {
    let response: VKGroupsResponse?
    let error: VKAPIError?
}

struct VKGroupsResponse: Decodable {
    let items: [VKAdminGroup]
}

struct VKAdminGroup: Decodable {
    let id: Int
    let name: String
    let screen_name: String?
    let photo_100: String?
    let admin_level: Int?
    let is_admin: Int?
    let is_member: Int?
}

struct VKGroupByIdEnvelope: Decodable {
    let response: VKGroupByIdResponse?
    let error: VKAPIError?
}

struct VKGroupByIdResponse: Decodable {
    let items: [VKGroupById]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let array = try? container.decode([VKGroupById].self) {
            self.items = array
            return
        }

        let object = try container.decode(VKGroupByIdObjectResponse.self)
        self.items = object.groups
    }
}

struct VKGroupByIdObjectResponse: Decodable {
    let groups: [VKGroupById]
}

struct VKGroupById: Decodable {
    let id: Int
    let name: String
    let screen_name: String?
    let photo_100: String?
}

// MARK: - Wall API

struct VKWallEnvelope: Decodable {
    let response: VKWallResponse?
    let error: VKAPIError?
}

struct VKWallResponse: Decodable {
    let items: [VKWallItem]
}

struct VKWallItem: Decodable {
    let id: Int
    let owner_id: Int
    let date: Double
    let text: String
    let likes: VKCount?
    let comments: VKCount?
    let reposts: VKCount?
    let views: VKCount?
    let attachments: [VKAttachment]?
}

struct VKCount: Decodable {
    let count: Int
}

struct VKAttachment: Decodable {
    let type: String
    let photo: VKPhoto?
    let video: VKVideo?
    let doc: VKDoc?
}

struct VKPhoto: Decodable {
    let sizes: [VKPhotoSize]
}

struct VKPhotoSize: Decodable {
    let url: String
    let width: Int
    let height: Int
}

struct VKVideo: Decodable {
    let image: [VKVideoImage]?
    let first_frame: [VKVideoImage]?
    let duration: Int?
}

struct VKVideoImage: Decodable {
    let url: String
    let width: Int?
    let height: Int?
}

struct VKDoc: Decodable {
    let title: String
    let size: Int
    let ext: String
    let url: String?
}

enum WallMedia {
    case photo(URL)
    case video(URL?, String?)
}

struct WallPost: Identifiable {
    let id: String
    let postId: Int
    let dateText: String
    let text: String
    let likes: Int
    let comments: Int
    let reposts: Int
    let views: Int
    let media: WallMedia?
    let postURL: URL?
}

// MARK: - Messages API

struct VKConversationsEnvelope: Decodable {
    let response: VKConversationsResponse?
    let error: VKAPIError?
}

struct VKConversationsResponse: Decodable {
    let items: [VKConversationItem]
    let profiles: [VKProfile]?
    let groups: [VKEntityGroup]?
}

struct VKConversationItem: Decodable {
    let conversation: VKConversation
    let last_message: VKMessage?
}

struct VKConversation: Decodable {
    let peer: VKPeer
    let unread_count: Int?
}

struct VKPeer: Decodable {
    let id: Int
    let type: String?
    let local_id: Int?
}

struct VKProfile: Decodable {
    let id: Int
    let first_name: String
    let last_name: String
    let photo_100: String?
}

struct VKEntityGroup: Decodable {
    let id: Int
    let name: String
    let photo_100: String?
}

struct VKHistoryEnvelope: Decodable {
    let response: VKHistoryResponse?
    let error: VKAPIError?
}

struct VKHistoryResponse: Decodable {
    let items: [VKMessage]
    let profiles: [VKProfile]?
    let groups: [VKEntityGroup]?
}

struct VKMessage: Decodable {
    let id: Int
    let date: Double
    let text: String?
    let from_id: Int?
    let out: Int?
    let attachments: [VKAttachment]?
}

struct VKSendMessageEnvelope: Decodable {
    let response: Int?
    let error: VKAPIError?
}

struct ConversationPreview: Identifiable, Equatable, Hashable {
    let id: Int
    let title: String
    let subtitle: String
    let timeText: String
    let unreadCount: Int
    let avatarURL: URL?
}

enum MessageAttachment: Hashable {
    case photo(URL)
    case doc(title: String, ext: String, size: Int, url: URL?)
}

struct ChatMessage: Identifiable {
    let id: Int
    let text: String
    let timeText: String
    let isOutgoing: Bool
    let avatarURL: URL?
    let attachments: [MessageAttachment]
}

// MARK: - User Info API

struct VKUsersGetEnvelope: Decodable {
    let response: [VKUserInfo]?
    let error: VKAPIError?
}

struct VKUserInfo: Decodable {
    let id: Int
    let first_name: String
    let last_name: String
    let photo_100: String?
    let bdate: String?
    let sex: Int?
    let city: VKCity?
    let online: Int?
}

struct VKCity: Decodable {
    let id: Int
    let title: String
}

// MARK: - Photo Upload API

struct VKUploadServerEnvelope: Decodable {
    let response: VKUploadServerResponse?
    let error: VKAPIError?
}

struct VKUploadServerResponse: Decodable {
    let upload_url: String
}

struct VKSaveMessagesPhotoEnvelope: Decodable {
    let response: [VKUploadedPhoto]?
    let error: VKAPIError?
}

struct VKUploadedPhoto: Decodable {
    let owner_id: Int
    let id: Int
    let access_key: String?
}

struct VKUploadPhotoResponse: Decodable {
    let server: Int
    let photo: String
    let hash: String
}

// MARK: - Session Store

@MainActor
final class SessionStore: ObservableObject {
    @Published var session: AuthorizedUserSession?
    @Published var selectedGroup: ManagedGroup? {
        didSet { persistSelectedGroup() }
    }
    @Published var selectedTab: RootTab = .wall {
        didSet { persistSelectedTab() }
    }

    private let tokenKey = "vk_user_access_token"
    private let userIdKey = "vk_user_id"
    private let selectedGroupKey = "vk_selected_group"
    private let selectedTabKey = "vk_selected_tab"

    init() {
        restore()
    }

    func loadDefaultGroupIfNeeded() async {
        guard let session else { return }

        let encodedToken = session.accessToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? session.accessToken
        let urlString =
        "https://api.vk.com/method/groups.getById?group_ids=\(AppConfig.defaultGroupScreenName)&fields=screen_name,photo_100&access_token=\(encodedToken)&v=\(AppConfig.apiVersion)"

        guard let url = URL(string: urlString) else {
            selectedGroup = fallbackDefaultGroup()
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(VKGroupByIdEnvelope.self, from: data)

            if let group = decoded.response?.items.first {
                selectedGroup = ManagedGroup(
                    id: group.id,
                    name: group.name,
                    photoURLString: group.photo_100,
                    role: "Основное сообщество",
                    screenName: group.screen_name
                )
                return
            }

            selectedGroup = fallbackDefaultGroup()
        } catch {
            selectedGroup = fallbackDefaultGroup()
        }
    }

    private func fallbackDefaultGroup() -> ManagedGroup {
        ManagedGroup(
            id: AppConfig.defaultGroupId,
            name: AppConfig.defaultGroupName,
            photoURLString: nil,
            role: "Основное сообщество",
            screenName: AppConfig.defaultGroupScreenName
        )
    }

    func saveSession(_ session: AuthorizedUserSession) {
        self.session = session
        UserDefaults.standard.set(session.accessToken, forKey: tokenKey)
        UserDefaults.standard.set(session.userId, forKey: userIdKey)
    }

    func logout() {
        session = nil
        selectedGroup = nil
        selectedTab = .wall
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: selectedGroupKey)
        UserDefaults.standard.removeObject(forKey: selectedTabKey)
    }

    func backToGroups() {
        selectedGroup = nil
    }

    private func restore() {
        let token = UserDefaults.standard.string(forKey: tokenKey) ?? ""
        let userId = UserDefaults.standard.integer(forKey: userIdKey)

        if !token.isEmpty {
            session = AuthorizedUserSession(accessToken: token, userId: userId)
        }

        if let data = UserDefaults.standard.data(forKey: selectedGroupKey),
           let group = try? JSONDecoder().decode(ManagedGroup.self, from: data) {
            selectedGroup = group
        }

        if let rawTab = UserDefaults.standard.string(forKey: selectedTabKey),
           let restoredTab = RootTab(rawValue: rawTab) {
            selectedTab = restoredTab
        }
    }

    private func persistSelectedGroup() {
        guard let selectedGroup else {
            UserDefaults.standard.removeObject(forKey: selectedGroupKey)
            return
        }

        if let data = try? JSONEncoder().encode(selectedGroup) {
            UserDefaults.standard.set(data, forKey: selectedGroupKey)
        }
    }

    private func persistSelectedTab() {
        UserDefaults.standard.set(selectedTab.rawValue, forKey: selectedTabKey)
    }
}

// MARK: - Root

struct RootView: View {
    @StateObject private var sessionStore = SessionStore()

    var body: some View {
        Group {
            if sessionStore.session == nil {
                VKLoginScreen()
                    .environmentObject(sessionStore)
            } else {
                GroupContainerScreen()
                    .environmentObject(sessionStore)
            }
        }
        .task(id: sessionStore.session?.accessToken) {
            guard sessionStore.session != nil else { return }
            sessionStore.selectedTab = .wall
            await sessionStore.loadDefaultGroupIfNeeded()
        }
    }
}

// MARK: - VK Embedded Auth

struct VKAuthSheet: View {
    let authURL: URL
    let title: String
    let onSuccess: (String, Int?) -> Void
    let onClose: () -> Void
    let onError: (String) -> Void

    var body: some View {
        NavigationView {
            VKAuthWebView(
                url: authURL,
                onTokenReceived: onSuccess,
                onError: onError
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        onClose()
                    }
                }
            }
        }
    }
}

struct VKAuthWebView: UIViewRepresentable {
    let url: URL
    let onTokenReceived: (String, Int?) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTokenReceived: onTokenReceived,
            onError: onError
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onTokenReceived: (String, Int?) -> Void
        private let onError: (String) -> Void
        private var didFinishAuth = false

        init(
            onTokenReceived: @escaping (String, Int?) -> Void,
            onError: @escaping (String) -> Void
        ) {
            self.onTokenReceived = onTokenReceived
            self.onError = onError
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            handlePossibleAuthURL(webView.url?.absoluteString)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            handlePossibleAuthURL(navigationAction.request.url?.absoluteString)
            decisionHandler(.allow)
        }

        private func handlePossibleAuthURL(_ urlString: String?) {
            guard !didFinishAuth, let urlString else { return }

            if urlString.contains("access_token=") || urlString.contains("#access_token=") {
                let parsed = VKTokenParser.parse(from: urlString)

                guard let token = parsed.accessToken, !token.isEmpty else {
                    onError("Не удалось получить access_token")
                    return
                }

                didFinishAuth = true
                onTokenReceived(token, parsed.userId)
            }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            guard !didFinishAuth else { return }
            onError(error.localizedDescription)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            guard !didFinishAuth else { return }
            onError(error.localizedDescription)
        }
    }
}

// MARK: - Login Screen

struct VKLoginScreen: View {
    @EnvironmentObject var sessionStore: SessionStore

    @State private var showAuth = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image("streamvi_settings_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                .padding(.bottom, 6)

            Text("Вход через VK")
                .font(.system(size: 28, weight: .bold))

            Text("Нажмите кнопку ниже, чтобы авторизоваться через встроенное окно VK")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                errorText = nil
                showAuth = true
            } label: {
                Text("Авторизация VK")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)

            if let errorText = errorText {
                Text(errorText)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .background(Color.white)
        .sheet(isPresented: $showAuth) {
            if let url = URL(string: AppConfig.manualAuthURL) {
                VKAuthSheet(
                    authURL: url,
                    title: "Авторизация VK",
                    onSuccess: { token, userId in
                        sessionStore.saveSession(
                            AuthorizedUserSession(
                                accessToken: token,
                                userId: userId ?? 0
                            )
                        )

                        sessionStore.selectedGroup = nil
                        sessionStore.selectedTab = .wall
                        showAuth = false

                        Task {
                            await sessionStore.loadDefaultGroupIfNeeded()
                        }
                    },
                    onClose: {
                        showAuth = false
                    },
                    onError: { message in
                        errorText = message
                    }
                )
            }
        }
    }
}

// MARK: - Token Parser

enum VKTokenParser {
    struct ParsedResult {
        let accessToken: String?
        let userId: Int?
    }

    static func parse(from raw: String) -> ParsedResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let directToken = extractTokenAnywhere(from: trimmed) {
            return ParsedResult(accessToken: directToken, userId: extractUserId(from: trimmed))
        }

        if let range = trimmed.range(of: "#") {
            let fragment = String(trimmed[range.upperBound...])
            if let token = extractTokenAnywhere(from: fragment) {
                return ParsedResult(accessToken: token, userId: extractUserId(from: fragment))
            }
        }

        if trimmed.contains("access_token=") {
            let token = extractValue(named: "access_token", from: trimmed)
            let userId = extractValue(named: "user_id", from: trimmed).flatMap(Int.init)
            return ParsedResult(accessToken: token, userId: userId)
        }

        return ParsedResult(accessToken: nil, userId: nil)
    }

    private static func extractTokenAnywhere(from text: String) -> String? {
        if let range = text.range(of: "vk1.") {
            let tail = String(text[range.lowerBound...])
            let token = tail.split(whereSeparator: {
                $0 == " " || $0 == "\n" || $0 == "\t" || $0 == "&" || $0 == "\"" || $0 == "'"
            }).first
            return token.map(String.init)
        }

        if let token = extractValue(named: "access_token", from: text), !token.isEmpty {
            return token
        }

        return nil
    }

    private static func extractUserId(from text: String) -> Int? {
        extractValue(named: "user_id", from: text).flatMap(Int.init)
    }

    private static func extractValue(named name: String, from text: String) -> String? {
        let cleaned = text.replacingOccurrences(of: "#", with: "&")
        let parts = cleaned.split(separator: "&")
        for part in parts {
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2 && pair[0].contains(name) {
                return pair[1]
            }
        }
        return nil
    }
}

// MARK: - ViewModels

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published var groups: [ManagedGroup] = []
    @Published var isLoading = false
    @Published var errorText: String?

    func load(token: String) async {
        isLoading = true
        errorText = nil
        groups = []

        guard
            let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://api.vk.com/method/groups.get?filter=admin,editor,moder&extended=1&access_token=\(encodedToken)&v=\(AppConfig.apiVersion)")
        else {
            errorText = "Не удалось собрать URL"
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(VKGroupsEnvelope.self, from: data)

            if let error = decoded.error {
                errorText = "VK error \(error.error_code): \(error.error_msg)"
                isLoading = false
                return
            }

            let items = decoded.response?.items ?? []
            groups = items.map {
                ManagedGroup(
                    id: $0.id,
                    name: $0.name,
                    photoURLString: $0.photo_100,
                    role: roleText(adminLevel: $0.admin_level, isAdmin: $0.is_admin),
                    screenName: $0.screen_name
                )
            }
        } catch {
            errorText = error.localizedDescription
        }

        isLoading = false
    }

    private func roleText(adminLevel: Int?, isAdmin: Int?) -> String {
        if isAdmin != 1 { return "Участник" }
        switch adminLevel {
        case 3: return "Администратор"
        case 2: return "Редактор"
        case 1: return "Модератор"
        default: return "Управление"
        }
    }
}

@MainActor
final class WallViewModel: ObservableObject {
    @Published var posts: [WallPost] = []
    @Published var searchPosts: [WallPost] = []
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorText: String?

    func load(groupId: Int, token: String) async {
        isLoading = true
        errorText = nil
        posts = []
        searchPosts = []

        guard
            let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://api.vk.com/method/wall.get?owner_id=-\(groupId)&count=20&access_token=\(encodedToken)&v=\(AppConfig.apiVersion)")
        else {
            errorText = "Не удалось собрать URL стены"
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(VKWallEnvelope.self, from: data)

            if let error = decoded.error {
                errorText = "VK error \(error.error_code): \(error.error_msg)"
                isLoading = false
                return
            }

            posts = mapWallItems(decoded.response?.items ?? [])
        } catch {
            errorText = error.localizedDescription
        }

        isLoading = false
    }

    func search(groupId: Int, token: String, query: String) async {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedQuery.isEmpty else {
                searchPosts = []
                isSearching = false
                return
            }

            isSearching = true

            guard
                let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                let encodedQuery = trimmedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                let url = URL(string: "https://api.vk.com/method/wall.search?owner_id=-\(groupId)&owners_only=1&count=100&query=\(encodedQuery)&access_token=\(encodedToken)&v=\(AppConfig.apiVersion)")
            else {
                errorText = "Не удалось собрать URL поиска"
                isSearching = false
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let decoded = try JSONDecoder().decode(VKWallEnvelope.self, from: data)

                if let error = decoded.error {
                    errorText = "VK error \(error.error_code): \(error.error_msg)"
                    isSearching = false
                    return
                }

                searchPosts = mapWallItems(decoded.response?.items ?? [])
            } catch {
                errorText = error.localizedDescription
            }

            isSearching = false
        }

        private func mapWallItems(_ items: [VKWallItem]) -> [WallPost] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            return items.map { item in
                WallPost(
                    id: "\(item.id)_\(Int(item.date))",
                    postId: item.id,
                    dateText: formatter.string(from: Date(timeIntervalSince1970: item.date)),
                    text: item.text.isEmpty ? "Без текста" : item.text,
                    likes: item.likes?.count ?? 0,
                    comments: item.comments?.count ?? 0,
                    reposts: item.reposts?.count ?? 0,
                    views: item.views?.count ?? 0,
                    media: bestMedia(from: item.attachments),
                    postURL: URL(string: "https://vk.com/wall\(item.owner_id)_\(item.id)")
                )
            }
        }

    private func bestMedia(from attachments: [VKAttachment]?) -> WallMedia? {
        guard let attachments = attachments else { return nil }

        for attachment in attachments {
            if attachment.type == "video", let video = attachment.video {
                let frames = (video.first_frame ?? []) + (video.image ?? [])
                let best = frames.max { a, b in
                    ((a.width ?? 0) * (a.height ?? 0)) < ((b.width ?? 0) * (b.height ?? 0))
                }
                let preview = best.flatMap { URL(string: $0.url) }
                return .video(preview, formatDuration(video.duration))
            }

            if attachment.type == "photo", let photo = attachment.photo {
                let best = photo.sizes.max { a, b in
                    (a.width * a.height) < (b.width * b.height)
                }
                if let best = best, let url = URL(string: best.url) {
                    return .photo(url)
                }
            }
        }

        return nil
    }

    private func formatDuration(_ seconds: Int?) -> String? {
        guard let seconds = seconds else { return nil }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}

@MainActor
final class ConversationsViewModel: ObservableObject {
    @Published var conversations: [ConversationPreview] = []
    @Published var isLoading = false
    @Published var errorText: String?

    func load(groupId: Int, token: String) async {
        let isFirstLoad = conversations.isEmpty
        if isFirstLoad { isLoading = true }
        errorText = nil

        guard
            let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://api.vk.com/method/messages.getConversations?group_id=\(groupId)&count=50&extended=1&access_token=\(encodedToken)&v=\(AppConfig.apiVersion)")
        else {
            errorText = "Не удалось собрать URL диалогов"
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(VKConversationsEnvelope.self, from: data)

            if let error = decoded.error {
                errorText = "VK error \(error.error_code): \(error.error_msg)"
                isLoading = false
                return
            }

            let profiles = decoded.response?.profiles ?? []
            let groups = decoded.response?.groups ?? []

            conversations = (decoded.response?.items ?? []).map {
                mapConversation(item: $0, profiles: profiles, groups: groups)
            }
        } catch {
            if conversations.isEmpty {
                errorText = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func mapConversation(item: VKConversationItem, profiles: [VKProfile], groups: [VKEntityGroup]) -> ConversationPreview {
        let peerId = item.conversation.peer.id
        let peerType = item.conversation.peer.type ?? "user"
        let unread = item.conversation.unread_count ?? 0
        let text = normalized(item.last_message?.text)
        let time = formatShortDate(item.last_message?.date)

        if peerType == "user", let profile = profiles.first(where: { $0.id == peerId }) {
            return ConversationPreview(
                id: peerId,
                title: "\(profile.first_name) \(profile.last_name)",
                subtitle: text,
                timeText: time,
                unreadCount: unread,
                avatarURL: profile.photo_100.flatMap(URL.init(string:))
            )
        }

        if peerType == "group", let group = groups.first(where: { $0.id == abs(peerId) }) {
            return ConversationPreview(
                id: peerId,
                title: group.name,
                subtitle: text,
                timeText: time,
                unreadCount: unread,
                avatarURL: group.photo_100.flatMap(URL.init(string:))
            )
        }

        if peerType == "chat" {
            let localId = item.conversation.peer.local_id ?? peerId
            return ConversationPreview(
                id: peerId,
                title: "Чат \(localId)",
                subtitle: text,
                timeText: time,
                unreadCount: unread,
                avatarURL: nil
            )
        }

        return ConversationPreview(
            id: peerId,
            title: "Диалог \(peerId)",
            subtitle: text,
            timeText: time,
            unreadCount: unread,
            avatarURL: nil
        )
    }

    private func normalized(_ text: String?) -> String {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Вложение или пустое сообщение" : trimmed
    }

    private func formatShortDate(_ ts: Double?) -> String {
        guard let ts = ts else { return "" }
        let date = Date(timeIntervalSince1970: ts)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        let cal = Calendar.current

        if cal.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        if cal.isDateInYesterday(date) {
            return "Вчера"
        }

        formatter.dateFormat = "dd.MM"
        return formatter.string(from: date)
    }
}

@MainActor
final class ChatHistoryViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorText: String?

    func load(groupId: Int, peerId: Int, token: String) async {
        guard !isLoading else { return }

        isLoading = true
        errorText = nil

        guard
            let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://api.vk.com/method/messages.getHistory?group_id=\(groupId)&peer_id=\(peerId)&count=50&extended=1&access_token=\(encodedToken)&v=\(AppConfig.apiVersion)")
        else {
            errorText = "Не удалось собрать URL истории"
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(VKHistoryEnvelope.self, from: data)

            if let error = decoded.error {
                errorText = "VK error \(error.error_code): \(error.error_msg)"
                isLoading = false
                return
            }

            let profiles = decoded.response?.profiles ?? []
            let groups = decoded.response?.groups ?? []
            let raw = decoded.response?.items ?? []

            messages = raw.reversed().map { item in
                let fromId = item.from_id ?? 0

                let avatarURL: URL? = {
                    if fromId > 0 {
                        return profiles.first(where: { $0.id == fromId })?.photo_100.flatMap(URL.init(string:))
                    } else {
                        return groups.first(where: { $0.id == abs(fromId) })?.photo_100.flatMap(URL.init(string:))
                    }
                }()

                return ChatMessage(
                    id: item.id,
                    text: normalized(item.text),
                    timeText: formatTime(item.date),
                    isOutgoing: (item.out ?? 0) == 1,
                    avatarURL: avatarURL,
                    attachments: parseAttachments(item.attachments)
                )
            }
        } catch {
            errorText = error.localizedDescription
        }

        isLoading = false
    }

    func send(text: String, groupId: Int, peerId: Int, token: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        guard
            let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let encodedMessage = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://api.vk.com/method/messages.send?group_id=\(groupId)&peer_id=\(peerId)&random_id=\(Int(Date().timeIntervalSince1970 * 1000))&message=\(encodedMessage)&access_token=\(encodedToken)&v=\(AppConfig.apiVersion)")
        else {
            errorText = "Не удалось собрать URL отправки"
            return false
        }

        isSending = true
        defer { isSending = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(VKSendMessageEnvelope.self, from: data)

            if let error = decoded.error {
                errorText = "VK error \(error.error_code): \(error.error_msg)"
                return false
            }

            return decoded.response != nil
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    private func parseAttachments(_ attachments: [VKAttachment]?) -> [MessageAttachment] {
        guard let attachments else { return [] }

        var result: [MessageAttachment] = []

        for attachment in attachments {
            if attachment.type == "photo", let photo = attachment.photo {
                let best = photo.sizes.max { a, b in
                    (a.width * a.height) < (b.width * b.height)
                }
                if let best, let url = URL(string: best.url) {
                    result.append(.photo(url))
                }
            }

            if attachment.type == "doc", let doc = attachment.doc {
                result.append(
                    .doc(
                        title: doc.title,
                        ext: doc.ext,
                        size: doc.size,
                        url: doc.url.flatMap(URL.init(string:))
                    )
                )
            }
        }

        return result
    }

    private func normalized(_ text: String?) -> String {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed
    }

    private func formatTime(_ ts: Double) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: ts))
    }
}

@MainActor
final class ChatInfoViewModel: ObservableObject {
    @Published var infoText: String = "Не указано"
    @Published var subscribeDateText: String = "Не указано"
    @Published var commentText: String = ""
    @Published var onlineText: String = "Не в сети"
    @Published var isOnline: Bool = false

    func load(chat: ConversationPreview, token: String) async {
        subscribeDateText = loadSubscribeDate(peerId: chat.id)
        commentText = loadComment(peerId: chat.id)

        guard chat.id > 0 else {
            infoText = "Не указано"
            isOnline = false
            onlineText = "Не в сети"
            return
        }

        do {
            let user = try await loadUserInfo(userId: chat.id, token: token)
            infoText = makeInfoLine(from: user)
            isOnline = (user.online ?? 0) == 1
            onlineText = isOnline ? "online" : "offline"
        } catch {
            infoText = "Не указано"
            isOnline = false
            onlineText = "Не в сети"
        }
    }

    func saveComment(_ value: String, peerId: Int) {
        UserDefaults.standard.set(value, forKey: commentKey(peerId: peerId))
    }

    func saveSubscribeDate(_ value: String, peerId: Int) {
        UserDefaults.standard.set(value, forKey: subscribeDateKey(peerId: peerId))
    }

    private func loadUserInfo(userId: Int, token: String) async throws -> VKUserInfo {
        let fields = "bdate,sex,city,photo_100,online"
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        let urlString = "https://api.vk.com/method/users.get?user_ids=\(userId)&fields=\(fields)&access_token=\(encodedToken)&v=\(AppConfig.apiVersion)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(VKUsersGetEnvelope.self, from: data)

        if let error = decoded.error {
            throw NSError(
                domain: "VK",
                code: error.error_code,
                userInfo: [NSLocalizedDescriptionKey: error.error_msg]
            )
        }

        guard let user = decoded.response?.first else {
            throw NSError(
                domain: "VK",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Пользователь не найден"]
            )
        }

        return user
    }

    private func makeInfoLine(from user: VKUserInfo) -> String {
        var parts: [String] = []

        if let city = user.city?.title, !city.isEmpty {
            parts.append(city)
        }

        if let age = calculateAge(from: user.bdate) {
            parts.append("\(age)")
        }

        if let sexText = mapSex(user.sex) {
            parts.append(sexText)
        }

        return parts.isEmpty ? "Не указано" : parts.joined(separator: " · ")
    }

    private func calculateAge(from bdate: String?) -> Int? {
        guard let bdate else { return nil }

        let parts = bdate.split(separator: ".").map(String.init)
        guard parts.count == 3,
              let day = Int(parts[0]),
              let month = Int(parts[1]),
              let year = Int(parts[2]) else {
            return nil
        }

        var comps = DateComponents()
        comps.day = day
        comps.month = month
        comps.year = year

        let calendar = Calendar.current
        guard let birthDate = calendar.date(from: comps) else { return nil }

        return calendar.dateComponents([.year], from: birthDate, to: Date()).year
    }

    private func mapSex(_ sex: Int?) -> String? {
        switch sex {
        case 1: return "женский"
        case 2: return "мужской"
        default: return nil
        }
    }

    private func commentKey(peerId: Int) -> String {
        "chat_comment_\(peerId)"
    }

    private func subscribeDateKey(peerId: Int) -> String {
        "chat_subscribe_date_\(peerId)"
    }

    private func loadComment(peerId: Int) -> String {
        let newValue = UserDefaults.standard.string(forKey: commentKey(peerId: peerId))
        if let newValue, !newValue.isEmpty {
            return newValue
        }

        let legacyValue = UserDefaults.standard.string(forKey: "chat_custom_id_\(peerId)") ?? ""
        if !legacyValue.isEmpty {
            UserDefaults.standard.set(legacyValue, forKey: commentKey(peerId: peerId))
            return legacyValue
        }

        return ""
    }

    private func loadSubscribeDate(peerId: Int) -> String {
        UserDefaults.standard.string(forKey: subscribeDateKey(peerId: peerId)) ?? "Не указано"
    }
}

@MainActor
final class VKPhotoMessageSender: ObservableObject {
    @Published var isUploading = false
    @Published var errorText: String?

    func sendPhoto(
        image: UIImage,
        peerId: Int,
        token: String,
        groupId: Int,
        messageText: String = ""
    ) async -> Bool {
        isUploading = true
        errorText = nil
        defer { isUploading = false }

        do {
            let uploadURL = try await getUploadServer(token: token)
            let uploadResult = try await uploadImage(image, to: uploadURL)
            let attachment = try await saveMessagesPhoto(uploadResult: uploadResult, token: token)
            try await sendMessage(
                peerId: peerId,
                token: token,
                text: messageText,
                attachment: attachment,
                groupId: groupId
            )
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    private func getUploadServer(token: String) async throws -> String {
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        let urlString = "https://api.vk.com/method/photos.getMessagesUploadServer?access_token=\(encodedToken)&v=\(AppConfig.apiVersion)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(VKUploadServerEnvelope.self, from: data)

        if let error = decoded.error {
            throw NSError(domain: "VK", code: error.error_code, userInfo: [
                NSLocalizedDescriptionKey: error.error_msg
            ])
        }

        guard let uploadURL = decoded.response?.upload_url else {
            throw NSError(domain: "VK", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Не удалось получить upload_url"
            ])
        }

        return uploadURL
    }

    private func uploadImage(_ image: UIImage, to uploadURL: String) async throws -> VKUploadPhotoResponse {
        guard let url = URL(string: uploadURL) else {
            throw URLError(.badURL)
        }

        guard let imageData = image.jpegData(compressionQuality: 0.95) else {
            throw NSError(domain: "Image", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Не удалось подготовить изображение"
            ])
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(VKUploadPhotoResponse.self, from: data)

        if decoded.photo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || decoded.photo == "[]" {
            throw NSError(domain: "VK", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Фото не загрузилось на сервер VK"
            ])
        }

        return decoded
    }

    private func saveMessagesPhoto(uploadResult: VKUploadPhotoResponse, token: String) async throws -> String {
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        let photo = uploadResult.photo.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uploadResult.photo
        let hash = uploadResult.hash.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uploadResult.hash

        let urlString =
        "https://api.vk.com/method/photos.saveMessagesPhoto?photo=\(photo)&server=\(uploadResult.server)&hash=\(hash)&access_token=\(encodedToken)&v=\(AppConfig.apiVersion)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(VKSaveMessagesPhotoEnvelope.self, from: data)

        if let error = decoded.error {
            throw NSError(domain: "VK", code: error.error_code, userInfo: [
                NSLocalizedDescriptionKey: error.error_msg
            ])
        }

        guard let photoItem = decoded.response?.first else {
            throw NSError(domain: "VK", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Не удалось сохранить фото"
            ])
        }

        if let accessKey = photoItem.access_key, !accessKey.isEmpty {
            return "photo\(photoItem.owner_id)_\(photoItem.id)_\(accessKey)"
        } else {
            return "photo\(photoItem.owner_id)_\(photoItem.id)"
        }
    }

    private func sendMessage(peerId: Int, token: String, text: String, attachment: String, groupId: Int) async throws {
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedAttachment = attachment.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? attachment
        let randomId = Int(Date().timeIntervalSince1970 * 1000)

        let urlString =
        "https://api.vk.com/method/messages.send?group_id=\(groupId)&peer_id=\(peerId)&random_id=\(randomId)&message=\(encodedText)&attachment=\(encodedAttachment)&access_token=\(encodedToken)&v=\(AppConfig.apiVersion)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(VKSendMessageEnvelope.self, from: data)

        if let error = decoded.error {
            throw NSError(domain: "VK", code: error.error_code, userInfo: [
                NSLocalizedDescriptionKey: error.error_msg
            ])
        }

        guard decoded.response != nil else {
            throw NSError(domain: "VK", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Не удалось отправить сообщение"
            ])
        }
    }
}

// MARK: - Screens

struct GroupContainerScreen: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        Group {
            if sessionStore.selectedGroup == nil {
                ProgressView("Открываем StreamVi...")
                    .task {
                                            guard sessionStore.selectedGroup == nil else { return }
                                            await sessionStore.loadDefaultGroupIfNeeded()
                        sessionStore.selectedTab = .wall
                    }
            } else {
                switch sessionStore.selectedTab {
                case .wall:
                    GroupWallScreen()
                        .environmentObject(sessionStore)

                case .messages:
                    GroupMessagesEntryScreen()
                        .environmentObject(sessionStore)

                case .admin:
                    AdminWebScreen()
                        .environmentObject(sessionStore)

                case .yandex:
                    YandexMessengerScreen()
                        .environmentObject(sessionStore)

                case .settings:
                    SettingsScreen()
                        .environmentObject(sessionStore)
                }
            }
        }
    }
}

struct GroupsScreen: View {
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var vm = GroupsViewModel()
    @State private var didAutoOpenSavedGroup = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Мои сообщества")
                        .font(.system(size: 24, weight: .bold))

                    Spacer()

                    Button("Сбросить токен") {
                        sessionStore.logout()
                    }
                    .foregroundColor(.red)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Divider()

                if vm.isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                        Text("Загружаем группы...")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else if let errorText = vm.errorText {
                    VStack(spacing: 12) {
                        Spacer()
                        Text("Не удалось загрузить группы")
                            .font(.headline)
                        Text(errorText)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button("Повторить") {
                            Task {
                                if let token = sessionStore.session?.accessToken {
                                    await vm.load(token: token)
                                    autoOpenSavedGroupIfNeeded()
                                }
                            }
                        }
                        Spacer()
                    }
                } else if vm.groups.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Text("Группы не найдены")
                            .font(.headline)
                        Text("Либо у токена нет прав groups, либо у аккаунта нет нужных сообществ.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Spacer()
                    }
                } else if filteredGroups.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Text("Ничего не найдено")
                            .font(.headline)
                        Text("Попробуй изменить запрос поиска.")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(filteredGroups) { group in
                        Button {
                            openGroup(group: group)
                        } label: {
                            GroupRow(group: group)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Поиск по группам")
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            if let token = sessionStore.session?.accessToken {
                await vm.load(token: token)
                autoOpenSavedGroupIfNeeded()
            }
        }
    }

    private var filteredGroups: [ManagedGroup] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return vm.groups }

        return vm.groups.filter { group in
            group.name.localizedCaseInsensitiveContains(query) ||
            group.role.localizedCaseInsensitiveContains(query) ||
            (group.screenName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private func autoOpenSavedGroupIfNeeded() {
        guard !didAutoOpenSavedGroup else { return }
        didAutoOpenSavedGroup = true

        guard let savedGroup = sessionStore.selectedGroup else { return }

        guard let actualGroup = vm.groups.first(where: { $0.id == savedGroup.id }) else {
            sessionStore.selectedGroup = nil
            return
        }

        sessionStore.selectedGroup = actualGroup
    }

    private func openGroup(group: ManagedGroup) {
        sessionStore.selectedGroup = group
    }
}

struct GroupWallScreen: View {
    @EnvironmentObject var sessionStore: SessionStore
    @StateObject private var vm = WallViewModel()

    @State private var searchText = ""
    @State private var selectedPostForShare: WallPost?
    @State private var showShareMenu = false
    @State private var showSystemShare = false
    @State private var searchTask: Task<Void, Never>?

    private var filteredPosts: [WallPost] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? vm.posts : vm.searchPosts
    }

    var body: some View {
        VStack(spacing: 0) {
            if let group = sessionStore.selectedGroup {
                VKGroupHeader(
                    group: group,
                    onBack: {}
                )
                .environmentObject(sessionStore)

                WallSearchBar(searchText: $searchText)
                if vm.isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                        Text("Загружаем стену...")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else if let errorText = vm.errorText {
                    VStack(spacing: 12) {
                        Spacer()
                        Text("Не удалось загрузить стену")
                            .font(.headline)
                        Text(errorText)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button("Повторить") {
                            Task {
                                if let token = sessionStore.session?.accessToken {
                                    await vm.load(groupId: group.id, token: token)
                                }
                            }
                        }
                        Spacer()
                    }
                } else if vm.isSearching {
                                    VStack {
                                        Spacer()
                                        ProgressView()
                                        Text("Ищем по всей стене...")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                } else if filteredPosts.isEmpty {
                    VStack {
                        Spacer()
                        Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Постов нет" : "Ничего не найдено")
                            .font(.headline)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredPosts) { post in
                                WallPostCard(post: post) { selectedPost in
                                    selectedPostForShare = selectedPost
                                    showShareMenu = true
                                }
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .background(Color.gray.opacity(0.08))
                }

                VKBottomBar(selectedTab: .wall)
                    .environmentObject(sessionStore)
            } else {
                Spacer()
                ProgressView("Открываем StreamVi...")
                Spacer()
            }
        }
        .background(Color.white)
        .task {
            if let token = sessionStore.session?.accessToken,
               let group = sessionStore.selectedGroup {
                await vm.load(groupId: group.id, token: token)
            }
        }
        .onChange(of: searchText) { query in
                    searchTask?.cancel()

                    guard let token = sessionStore.session?.accessToken,
                          let group = sessionStore.selectedGroup else { return }

                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        guard !Task.isCancelled else { return }
                        await vm.search(groupId: group.id, token: token, query: query)
                    }
                }
                .onDisappear {
                    searchTask?.cancel()
                }
        .confirmationDialog(
            "Поделиться постом",
            isPresented: $showShareMenu,
            titleVisibility: .visible
        ) {
            Button("Скопировать ссылку") {
                if let url = selectedPostForShare?.postURL {
                    UIPasteboard.general.string = url.absoluteString
                }
                selectedPostForShare = nil
            }

            Button("Поделиться") {
                showSystemShare = true
            }

            Button("Отмена", role: .cancel) {
                selectedPostForShare = nil
            }
        }
        .sheet(isPresented: $showSystemShare, onDismiss: {
            selectedPostForShare = nil
        }) {
            if let url = selectedPostForShare?.postURL {
                ShareSheet(items: [url])
            }
        }
    }
}

struct GroupMessagesEntryScreen: View {
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        if let group = sessionStore.selectedGroup,
           let userToken = sessionStore.session?.accessToken,
           !userToken.isEmpty {
            ConversationsScreen(group: group, userToken: userToken)
                .environmentObject(sessionStore)
        }
    }
}

struct ConversationsScreen: View {
    @EnvironmentObject var sessionStore: SessionStore

    let group: ManagedGroup
    let userToken: String

    @StateObject private var vm = ConversationsViewModel()
    @State private var path = NavigationPath()
    @State private var searchText = ""

    let refreshTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                MessagesHeader(
                    title: group.name,
                    searchText: $searchText
                )

                if vm.isLoading && vm.conversations.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView()
                        Text("Загружаем диалоги...")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else if let errorText = vm.errorText, vm.conversations.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Text("Не удалось загрузить диалоги")
                            .font(.headline)
                        Text(errorText)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Button("Повторить") {
                            Task {
                                await vm.load(groupId: group.id, token: userToken)
                            }
                        }

                        Spacer()
                    }
                } else if vm.conversations.isEmpty {
                    VStack {
                        Spacer()
                        Text("Диалогов нет")
                            .font(.headline)
                        Spacer()
                    }
                } else if filteredConversations.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Text("Ничего не найдено")
                            .font(.headline)
                        Text("Попробуй изменить запрос поиска.")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(filteredConversations) { chat in
                        NavigationLink(value: chat) {
                            ConversationRow(chat: chat)
                        }
                    }
                    .listStyle(.plain)
                }

                VKBottomBar(selectedTab: .messages)
                    .environmentObject(sessionStore)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ConversationPreview.self) { chat in
                ChatDetailScreen(
                    chat: chat,
                    groupId: group.id,
                    userToken: userToken
                )
            }
        }
        .task {
            await vm.load(groupId: group.id, token: userToken)
        }
        .onReceive(refreshTimer) { _ in
            guard path.isEmpty else { return }
            Task {
                await vm.load(groupId: group.id, token: userToken)
            }
        }
    }

    private var filteredConversations: [ConversationPreview] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return vm.conversations }

        return vm.conversations.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }
}

struct ChatDetailScreen: View {
    let chat: ConversationPreview
    let groupId: Int
    let userToken: String

    @StateObject private var vm = ChatHistoryViewModel()
    @StateObject private var photoSender = VKPhotoMessageSender()
    @State private var draftText = ""
    @State private var fullscreenPhoto: FullscreenPhoto?
    @State private var showPhotoPicker = false
    @State private var showTemplates = false

    private let templates: [MessageTemplate] = [
        .init(title: "Здравствуйте", text: "Здравствуйте!"),
        .init(title: "Спасибо", text: "Спасибо!"),
        .init(title: "Сейчас проверю", text: "Сейчас всё проверю и вернусь с ответом."),
        .init(title: "Отправьте детали", text: "Пожалуйста, отправьте детали сообщением."),
        .init(title: "Добрый день", text: "Добрый день!")
    ]

    let refreshTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ChatHeader(chat: chat, userToken: userToken)

            if vm.isLoading && vm.messages.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Загружаем сообщения...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if let errorText = vm.errorText, vm.messages.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("Не удалось загрузить историю")
                        .font(.headline)
                    Text(errorText)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button("Повторить") {
                        Task {
                            await vm.load(groupId: groupId, peerId: chat.id, token: userToken)
                        }
                    }
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.messages) { message in
                                MessageBubbleRow(
                                    message: message,
                                    onOpenPhoto: { url in
                                        fullscreenPhoto = FullscreenPhoto(url: url)
                                    }
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                    }
                    .background(Color.gray.opacity(0.08))
                    .onAppear {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                    .onChange(of: vm.messages.count) { _ in
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
            }

            if let errorText = vm.errorText, !vm.messages.isEmpty {
                Text(errorText)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.top, 6)
            }

            if let photoError = photoSender.errorText {
                Text(photoError)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }

            MessageInputBar(
                text: $draftText,
                isSending: vm.isSending,
                isUploading: photoSender.isUploading,
                onSend: {
                    let text = draftText
                    Task {
                        let sent = await vm.send(text: text, groupId: groupId, peerId: chat.id, token: userToken)
                        if sent {
                            draftText = ""
                            await vm.load(groupId: groupId, peerId: chat.id, token: userToken)
                        }
                    }
                },
                onAttachTap: {
                    showPhotoPicker = true
                },
                onTemplatesTap: {
                    showTemplates = true
                }
            )
            .confirmationDialog("Шаблоны", isPresented: $showTemplates, titleVisibility: .visible) {
                ForEach(templates) { template in
                    Button(template.title) {
                        draftText = template.text
                    }
                }

                Button("Отмена", role: .cancel) { }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await vm.load(groupId: groupId, peerId: chat.id, token: userToken)
        }
        .onReceive(refreshTimer) { _ in
            Task {
                await vm.load(groupId: groupId, peerId: chat.id, token: userToken)
            }
        }
        .fullScreenCover(item: $fullscreenPhoto) { item in
            FullscreenPhotoScreen(imageURL: item.url)
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker { image in
                Task {
                    let sent = await photoSender.sendPhoto(
                        image: image,
                        peerId: chat.id,
                        token: userToken,
                        groupId: groupId,
                        messageText: draftText
                    )

                    if sent {
                        draftText = ""
                        await vm.load(groupId: groupId, peerId: chat.id, token: userToken)
                    }
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastId = vm.messages.last?.id else { return }

        DispatchQueue.main.async {
            if animated {
                withAnimation {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

struct ChatInfoScreen: View {
    let chat: ConversationPreview
    let userToken: String

    @StateObject private var vm = ChatInfoViewModel()
    @State private var editableComment: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    AsyncAvatar(url: chat.avatarURL, size: 72)

                    Text(chat.title)
                        .font(.system(size: 22, weight: .bold))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(vm.isOnline ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)

                        Text(vm.onlineText)
                            .font(.system(size: 14))
                            .foregroundColor(vm.isOnline ? .green : .secondary)
                    }

                    if !chat.timeText.isEmpty && !vm.isOnline {
                        Text("Последняя активность: \(chat.timeText)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 20)

                VStack(spacing: 0) {
                    InfoRow(title: "Информация", value: vm.infoText)

                    Divider()

                    InfoRow(title: "Дата подписки", value: vm.subscribeDateText)

                    Divider()

                    EditableInfoRow(
                        title: "Комментарий",
                        text: $editableComment,
                        placeholder: "Добавить комментарий"
                    )
                }
                .background(Color(.systemBackground))
                .cornerRadius(14)
                .padding(.horizontal, 16)
            }
        }
        .background(Color(.systemGray6))
        .navigationTitle("Информация")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.load(chat: chat, token: userToken)
            editableComment = vm.commentText
        }
        .onChange(of: editableComment) { newValue in
            vm.saveComment(newValue, peerId: chat.id)
        }
    }
}

// MARK: - Admin

struct AdminWebScreen: View {
    @State private var authWebView: WKWebView?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                AdminWebHeader()

                if let url = URL(string: AppConfig.adminURL) {
                    AdminWebView(
                        url: url,
                        onAuthWebViewCreated: { webView in
                            authWebView = webView
                        },
                        onAuthFinished: {
                            authWebView = nil
                        }
                    )
                } else {
                    VStack {
                        Spacer()
                        Text("Не удалось открыть admin.streamvi.io")
                            .font(.headline)
                        Spacer()
                    }
                }
            }
            .background(Color.white)

            VKBottomBar(selectedTab: .admin)
        }
        .background(Color.white)
        .sheet(isPresented: Binding(
            get: { authWebView != nil },
            set: { newValue in
                if !newValue { authWebView = nil }
            }
        )) {
            if let authWebView {
                AdminAuthScreen(webView: authWebView) {
                    self.authWebView = nil
                }
            }
        }
    }
}

struct AdminWebHeader: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Admin")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
        }
        .background(Color.white)
    }
}

struct AdminAuthScreen: View {
    let webView: WKWebView
    let onClose: () -> Void

    var body: some View {
        NavigationView {
            ExistingWebViewContainer(webView: webView)
                .navigationTitle("Вход через VK")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Закрыть", action: onClose)
                    }
                }
        }
    }
}

struct AdminWebView: UIViewRepresentable {
    let url: URL
    let onAuthWebViewCreated: (WKWebView) -> Void
    let onAuthFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onAuthWebViewCreated: onAuthWebViewCreated,
            onAuthFinished: onAuthFinished
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.load(URLRequest(url: url))
        context.coordinator.parentWebView = webView
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let onAuthWebViewCreated: (WKWebView) -> Void
        let onAuthFinished: () -> Void
        weak var parentWebView: WKWebView?

        init(
            onAuthWebViewCreated: @escaping (WKWebView) -> Void,
            onAuthFinished: @escaping () -> Void
        ) {
            self.onAuthWebViewCreated = onAuthWebViewCreated
            self.onAuthFinished = onAuthFinished
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            let popup = WKWebView(frame: .zero, configuration: configuration)
            popup.navigationDelegate = self
            popup.uiDelegate = self
            popup.allowsBackForwardNavigationGestures = true
            popup.scrollView.keyboardDismissMode = .onDrag

            DispatchQueue.main.async {
                self.onAuthWebViewCreated(popup)
            }

            return popup
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let url = navigationAction.request.url

            if webView == parentWebView, shouldOpenInAuthWindow(url) {
                openAuthWindow(with: url)
                decisionHandler(.cancel)
                return
            }

            if webView == parentWebView, navigationAction.targetFrame == nil {
                openAuthWindow(with: url)
                decisionHandler(.cancel)
                return
            }

            if webView != parentWebView, shouldCloseAuth(for: url) {
                DispatchQueue.main.async {
                    self.onAuthFinished()
                    self.parentWebView?.load(URLRequest(url: URL(string: AppConfig.adminURL)!))
                }
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if webView != parentWebView, shouldCloseAuth(for: webView.url) {
                DispatchQueue.main.async {
                    self.onAuthFinished()
                    self.parentWebView?.load(URLRequest(url: URL(string: AppConfig.adminURL)!))
                }
            }
        }

        func webViewDidClose(_ webView: WKWebView) {
            DispatchQueue.main.async {
                self.onAuthFinished()
                self.parentWebView?.load(URLRequest(url: URL(string: AppConfig.adminURL)!))
            }
        }

        private func openAuthWindow(with url: URL?) {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .default()
            config.preferences.javaScriptCanOpenWindowsAutomatically = true

            let authWebView = WKWebView(frame: .zero, configuration: config)
            authWebView.navigationDelegate = self
            authWebView.uiDelegate = self
            authWebView.allowsBackForwardNavigationGestures = true
            authWebView.scrollView.keyboardDismissMode = .onDrag

            if let url {
                authWebView.load(URLRequest(url: url))
            }

            DispatchQueue.main.async {
                self.onAuthWebViewCreated(authWebView)
            }
        }

        private func shouldOpenInAuthWindow(_ url: URL?) -> Bool {
            guard let absolute = url?.absoluteString.lowercased() else { return false }

            return absolute.contains("id.vk.com/auth") ||
                   absolute.contains("oauth.vk.com/authorize") ||
                   absolute.contains("oauth.vk.com") ||
                   absolute.contains("login.vk.com")
        }

        private func shouldCloseAuth(for url: URL?) -> Bool {
            guard let absolute = url?.absoluteString.lowercased() else { return false }
            return absolute.contains("api.streamvi.io/api/auth/auth")
        }
    }
}

// MARK: - Yandex

struct YandexMessengerScreen: View {
    @State private var authWebView: WKWebView?
    @State private var authState: YandexAuthState = .checking

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if let url = URL(string: AppConfig.yandexMessengerURL) {
                    YandexMessengerWebView(
                        url: url,
                        onAuthStateChanged: { state in
                            authState = state
                        }
                    )
                } else {
                    VStack {
                        Spacer()
                        Text("Не удалось открыть Яндекс Мессенджер")
                            .font(.headline)
                        Spacer()
                    }
                }
            }
            .background(Color.white)

            if authState == .unauthorized {
                VStack {
                    Spacer()

                    Button {
                        authState = .checking

                        let config = WKWebViewConfiguration()
                        config.websiteDataStore = .default()
                        config.processPool = SharedWebContext.processPool
                        config.preferences.javaScriptCanOpenWindowsAutomatically = true

                        let webView = WKWebView(frame: .zero, configuration: config)
                        webView.load(URLRequest(url: URL(string: AppConfig.yandexAuthURL)!))
                        authWebView = webView
                    } label: {
                        Text("Войти в Яндекс")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 180)
                }
                .zIndex(1000)
            }

            VKBottomBar(selectedTab: .yandex)
        }
        .background(Color.white)
        .sheet(isPresented: Binding(
            get: { authWebView != nil },
            set: { newValue in
                if !newValue { authWebView = nil }
            }
        )) {
            if let authWebView {
                YandexAuthScreen(webView: authWebView) {
                    self.authWebView = nil
                    self.authState = .checking
                }
            }
        }
    }
}

struct YandexAuthScreen: UIViewRepresentable {
    let webView: WKWebView
    let onClose: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onClose: onClose)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let onClose: () -> Void
        private var didClose = false

        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            handle(url: webView.url)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            handle(url: navigationAction.request.url)
            decisionHandler(.allow)
        }

        func webViewDidClose(_ webView: WKWebView) {
            closeOnce()
        }

        private func handle(url: URL?) {
            guard let absolute = url?.absoluteString.lowercased() else { return }
            if absolute.contains("messenger.360.yandex.ru") {
                closeOnce()
            }
        }

        private func closeOnce() {
            guard !didClose else { return }
            didClose = true

            DispatchQueue.main.async {
                self.onClose()
            }
        }
    }
}

struct YandexMessengerWebView: UIViewRepresentable {
    let url: URL
    let onAuthStateChanged: (YandexAuthState) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onAuthStateChanged: onAuthStateChanged)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.processPool = SharedWebContext.processPool
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 52, right: 0)
        webView.scrollView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 52, right: 0)
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white

        context.coordinator.attach(to: webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let onAuthStateChanged: (YandexAuthState) -> Void

        weak var webView: WKWebView?
        private var lastState: YandexAuthState?
        private var pendingChecks: [DispatchWorkItem] = []

        init(onAuthStateChanged: @escaping (YandexAuthState) -> Void) {
            self.onAuthStateChanged = onAuthStateChanged
        }

        func attach(to webView: WKWebView) {
            self.webView = webView
            updateState(.checking)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            cancelPendingChecks()
            updateState(.checking)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            scheduleDOMChecks()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            scheduleDOMChecks()
        }

        private func scheduleDOMChecks() {
            cancelPendingChecks()

            let delays: [Double] = [0.1, 0.5, 1.0, 1.8]

            for delay in delays {
                let work = DispatchWorkItem { [weak self] in
                    self?.checkPageState()
                }
                pendingChecks.append(work)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            }
        }

        private func cancelPendingChecks() {
            pendingChecks.forEach { $0.cancel() }
            pendingChecks.removeAll()
        }

        private func checkPageState() {
            guard let webView else { return }

            let js = """
            (() => {
                const bodyText = (document.body?.innerText || "").toLowerCase().replace(/\\s+/g, ' ').trim();

                const hasLoginText =
                    bodyText.includes("войдите в аккаунт") ||
                    bodyText.includes("войти в аккаунт");

                const clickableTexts = Array.from(document.querySelectorAll("button, a, div, span"))
                    .map(el => (el.innerText || "").toLowerCase().replace(/\\s+/g, ' ').trim())
                    .filter(Boolean);

                const hasExplicitLoginButton = clickableTexts.some(text =>
                    text === "войти в аккаунт" ||
                    text.includes("войти в аккаунт") ||
                    text.includes("войдите в аккаунт")
                );

                const hasEmptyChatsText =
                    bodyText.includes("список чатов пуст");

                const strictChatSelectors = [
                    '[data-testid*="chat-item"]',
                    '[data-testid*="dialog-item"]',
                    '[class*="chat-item"]',
                    '[class*="dialog-item"]',
                    '[class*="conversation-item"]',
                    '[class*="thread-item"]'
                ];

                let hasRealChatItems = false;
                for (const selector of strictChatSelectors) {
                    const nodes = document.querySelectorAll(selector);
                    if (nodes && nodes.length > 0) {
                        hasRealChatItems = true;
                        break;
                    }
                }

                return JSON.stringify({
                    url: window.location.href,
                    hasLoginText,
                    hasExplicitLoginButton,
                    hasEmptyChatsText,
                    hasRealChatItems
                });
            })();
            """

            webView.evaluateJavaScript(js) { [weak self] result, _ in
                guard let self else { return }

                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8),
                      let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    self.updateState(.checking)
                    return
                }

                let hasLoginText = payload["hasLoginText"] as? Bool ?? false
                let hasExplicitLoginButton = payload["hasExplicitLoginButton"] as? Bool ?? false
                let hasEmptyChatsText = payload["hasEmptyChatsText"] as? Bool ?? false
                let hasRealChatItems = payload["hasRealChatItems"] as? Bool ?? false
                let currentURL = ((payload["url"] as? String) ?? "").lowercased()

                if hasLoginText || hasExplicitLoginButton {
                    self.updateState(.unauthorized)
                    return
                }

                if hasRealChatItems {
                    self.updateState(.authorized)
                    return
                }

                if hasEmptyChatsText {
                    self.updateState(.authorized)
                    return
                }

                if currentURL.contains("passport.yandex") ||
                   currentURL.contains("id.yandex") ||
                   currentURL.contains("login.yandex") ||
                   currentURL.contains("pwl-yandex") {
                    self.updateState(.unauthorized)
                    return
                }

                self.updateState(.checking)
            }
        }

        private func updateState(_ state: YandexAuthState) {
            guard lastState != state else { return }
            lastState = state

            DispatchQueue.main.async {
                self.onAuthStateChanged(state)
            }
        }
    }
}

// MARK: - Settings

struct SettingsScreen: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                Spacer()

                Image("streamvi_settings_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)

                Text("StreamVi Support")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.top, 20)

                Text("ver. 1.4")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .padding(.top, 6)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)

            VKBottomBar(selectedTab: .settings)
        }
        .background(Color.white)
    }
}

// MARK: - UI helpers

struct ExistingWebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct VKGroupHeader: View {
    @EnvironmentObject var sessionStore: SessionStore

    let group: ManagedGroup
    let onBack: () -> Void

    @State private var showMenu = false
    @State private var showSchedule = false
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                GroupCircleAvatar(name: group.name, url: group.photoURL, size: 42)

                VStack(spacing: 2) {
                    Text("Стена")
                        .font(.system(size: 17, weight: .semibold))

                    Text(group.name)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                Button {
                    showMenu = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()
        }
        .background(Color.white)
        .confirmationDialog("Меню", isPresented: $showMenu, titleVisibility: .visible) {
            Button("Расписание") {
                showSchedule = true
            }

            Button("Выйти из аккаунта", role: .destructive) {
                sessionStore.logout()
            }

            Button("Отмена", role: .cancel) { }
        }
        .sheet(isPresented: $showSchedule) {
                    ScheduleImageScreen()
                }
            }
        }

        struct ScheduleImageScreen: View {
            @Environment(\.dismiss) private var dismiss

            @State private var imageURL: URL?
            @State private var isLoading = true
            @State private var errorText: String?

            var body: some View {
                NavigationStack {
                    ZStack {
                        Color.white.ignoresSafeArea()

                        if isLoading {
                            ProgressView("Загружаем расписание...")
                        } else if let imageURL {
                            AsyncImage(url: imageURL) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView("Загружаем изображение...")
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .padding()
                                case .failure:
                                    Text("Не удалось открыть изображение расписания")
                                        .foregroundColor(.secondary)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Text(errorText ?? "Не удалось получить расписание")
                                .foregroundColor(.secondary)
                        }
                    }
                    .navigationTitle("Расписание")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Закрыть") {
                                dismiss()
                            }
                        }
                    }
                    .task {
                        await loadScheduleURL()
                    }
                }
            }

            private func loadScheduleURL() async {
                guard let apiURL = URL(string: AppConfig.scheduleDownloadAPI) else {
                    isLoading = false
                    errorText = "Некорректный адрес расписания"
                    return
                }

                do {
                    let (data, _) = try await URLSession.shared.data(from: apiURL)
                    let response = try JSONDecoder().decode(YandexDiskDownloadResponse.self, from: data)
                    imageURL = URL(string: response.href)
                    if imageURL == nil {
                        errorText = "Не удалось получить ссылку на изображение"
                    }
                } catch {
                    errorText = "Не удалось загрузить расписание"
                }

                isLoading = false
    }
}

struct MessagesHeader: View {
    let title: String
    @Binding var searchText: String

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Сообщения")
                    .font(.system(size: 22, weight: .bold))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Поиск диалогов", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            Divider()
        }
        .background(Color.white)
    }
}

struct ChatHeader: View {
    let chat: ConversationPreview
    let userToken: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.blue)
                }

                Text(chat.title)
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            NavigationLink {
                ChatInfoScreen(chat: chat, userToken: userToken)
            } label: {
                ZStack {
                    Text("Информация")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)

                    HStack {
                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color.white)
            }
            .buttonStyle(.plain)

            Divider()
        }
        .background(Color.white)
    }
}

struct WallSearchBar: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Поиск по стене", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
    }
}

func makeAttributedPostText(_ text: String) -> AttributedString {
    var attributed = AttributedString(text)

    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
        return attributed
    }

    let nsText = text as NSString
    let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

    for match in matches {
        guard let range = Range(match.range, in: attributed),
              let url = match.url else { continue }
        attributed[range].link = url
        attributed[range].foregroundColor = .blue
        attributed[range].underlineStyle = .single
    }

    return attributed
}


struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct VKBottomBar: View {
    @EnvironmentObject var sessionStore: SessionStore
    let selectedTab: RootTab

    var body: some View {
        HStack {
            Spacer()

            Button {
                sessionStore.selectedTab = .wall
            } label: {
                Image(systemName: "rectangle.grid.1x2")
                    .foregroundColor(selectedTab == .wall ? .blue : .gray)
            }

            Spacer()

            Button {
                sessionStore.selectedTab = .messages
            } label: {
                Image(systemName: "bubble.left")
                    .foregroundColor(selectedTab == .messages ? .blue : .gray)
            }

            Spacer()

            Button {
                sessionStore.selectedTab = .admin
            } label: {
                Image("streamvi_admin_icon")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(selectedTab == .admin ? .blue : .gray)
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }

            Spacer()

            Button {
                sessionStore.selectedTab = .yandex
            } label: {
                Image(systemName: "paperplane")
                    .foregroundColor(selectedTab == .yandex ? .blue : .gray)
            }

            Spacer()

            Button {
                sessionStore.selectedTab = .settings
            } label: {
                Image(systemName: "gearshape")
                    .foregroundColor(selectedTab == .settings ? .blue : .gray)
            }

            Spacer()
        }
        .font(.system(size: 22))
        .padding(.vertical, 14)
        .background(Color.white)
    }
}

struct GroupRow: View {
    let group: ManagedGroup

    var body: some View {
        HStack(spacing: 12) {
            AsyncAvatar(url: group.photoURL, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text(group.role)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                if let screenName = group.screenName, !screenName.isEmpty {
                    Text("@\(screenName)")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct ConversationRow: View {
    let chat: ConversationPreview

    var body: some View {
        HStack(spacing: 12) {
            AsyncAvatar(url: chat.avatarURL, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)

                    Spacer()

                    Text(chat.timeText)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text(chat.subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if chat.unreadCount > 0 {
                        Text("\(chat.unreadCount)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)

            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct EditableInfoRow: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)

            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct MessageInputBar: View {
    @Binding var text: String
    let isSending: Bool
    let isUploading: Bool
    let onSend: () -> Void
    let onAttachTap: () -> Void
    let onTemplatesTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Button(action: onAttachTap) {
                    Image(systemName: "paperclip")
                        .foregroundColor(.secondary)
                }

                TextField("Сообщение", text: $text)
                    .textFieldStyle(.plain)

                Button(action: onTemplatesTap) {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color(.systemGray6))
            .cornerRadius(20)

            Button(action: onSend) {
                if isSending || isUploading {
                    ProgressView()
                        .frame(width: 34, height: 34)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(canSend ? .blue : .gray)
                }
            }
            .disabled(!canSend || isSending || isUploading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct MessageBubbleRow: View {
    let message: ChatMessage
    let onOpenPhoto: (URL) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isOutgoing {
                Spacer()
            } else {
                AsyncAvatar(url: message.avatarURL, size: 30)
            }

            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
                VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 6) {
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.system(size: 15))
                            .foregroundColor(message.isOutgoing ? .white : .primary)
                    }

                    ForEach(Array(message.attachments.enumerated()), id: \.offset) { item in
                        attachmentView(item.element)
                    }

                    if message.text.isEmpty && message.attachments.isEmpty {
                        Text("Пустое сообщение")
                            .font(.system(size: 15))
                            .foregroundColor(message.isOutgoing ? .white : .primary)
                    }
                }
                .padding(12)
                .background(message.isOutgoing ? Color.blue : Color.white)
                .cornerRadius(14)

                Text(message.timeText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            if !message.isOutgoing {
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func attachmentView(_ attachment: MessageAttachment) -> some View {
        switch attachment {
        case .photo(let url):
            Button {
                onOpenPhoto(url)
            } label: {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                            ProgressView()
                        }
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(width: 220, height: 220)
                .clipped()
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

        case .doc(let title, let ext, let size, _):
            HStack(spacing: 10) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(message.isOutgoing ? .white : .primary)
                        .lineLimit(2)

                    Text("\(ext.uppercased()), \(formattedFileSize(size))")
                        .font(.system(size: 12))
                        .foregroundColor(message.isOutgoing ? .white.opacity(0.85) : .secondary)
                }

                Spacer()
            }
            .padding(10)
            .background(message.isOutgoing ? Color.white.opacity(0.15) : Color.gray.opacity(0.12))
            .cornerRadius(10)
        }
    }

    private func formattedFileSize(_ size: Int) -> String {
        let kb = Double(size) / 1024.0
        if kb < 1024 {
            return "\(Int(kb.rounded())) КБ"
        }
        let mb = kb / 1024.0
        return String(format: "%.1f МБ", mb)
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImagePicked: (UIImage) -> Void

        init(onImagePicked: @escaping (UIImage) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let itemProvider = results.first?.itemProvider,
                  itemProvider.canLoadObject(ofClass: UIImage.self) else { return }

            itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                guard let uiImage = image as? UIImage else { return }

                DispatchQueue.main.async {
                    self.onImagePicked(uiImage)
                }
            }
        }
    }
}

struct FullscreenPhotoScreen: View {
    let imageURL: URL
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ZoomableAsyncImage(url: imageURL)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

struct ZoomableAsyncImage: View {
    let url: URL

    @State private var currentScale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)

            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(currentScale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                currentScale = max(1, min(lastScale * value, 4))
                            }
                            .onEnded { _ in
                                lastScale = currentScale
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if currentScale > 1 {
                                currentScale = 1
                                lastScale = 1
                            } else {
                                currentScale = 2
                                lastScale = 2
                            }
                        }
                    }
                    .padding()

            case .failure:
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Не удалось загрузить изображение")
                        .foregroundColor(.white.opacity(0.8))
                }

            @unknown default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WallPostCard: View {
    let post: WallPost
    let onShare: (WallPost) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(post.dateText)
                .font(.caption)
                .foregroundColor(.secondary)

            if let media = post.media {
                WallMediaView(media: media)
            }

            Text(makeAttributedPostText(post.text))
                .font(.body)
                .tint(.blue)

            HStack {
                StatView(icon: "heart", value: post.likes)
                Spacer()
                StatView(icon: "bubble.left", value: post.comments)
                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onShare(post)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.right")
                        Text("\(post.reposts)")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()
                StatView(icon: "eye", value: post.views)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 12)
    }
}

struct WallMediaView: View {
    let media: WallMedia

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            switch media {
            case .photo(let url):
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Rectangle().fill(Color.gray.opacity(0.2))
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Rectangle().fill(Color.gray.opacity(0.2))
                    @unknown default:
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(height: 220)
                .clipped()
                .cornerRadius(12)

            case .video(let previewURL, let duration):
                ZStack {
                    if let previewURL = previewURL {
                        AsyncImage(url: previewURL) { phase in
                            switch phase {
                            case .empty:
                                ZStack {
                                    Rectangle().fill(Color.gray.opacity(0.2))
                                    ProgressView()
                                }
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Rectangle().fill(Color.gray.opacity(0.2))
                            @unknown default:
                                Rectangle().fill(Color.gray.opacity(0.2))
                            }
                        }
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 54))
                        .foregroundColor(.white)
                }
                .frame(height: 220)
                .clipped()
                .cornerRadius(12)

                if let duration = duration {
                    Text(duration)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(8)
                        .padding(10)
                }
            }
        }
    }
}

struct StatView: View {
    let icon: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text("\(value)")
        }
        .font(.footnote)
        .foregroundColor(.secondary)
    }
}

struct GroupCircleAvatar: View {
    let name: String
    let url: URL?
    let size: CGFloat

    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        fallback
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallback: some View {
        Circle()
            .fill(Color.blue.opacity(0.15))
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(.blue)
            )
    }

    private var initials: String {
        let parts = name.split(separator: " ").map(String.init)
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }
}

struct AsyncAvatar: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(Color.gray.opacity(0.2))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallback: some View {
        Circle()
            .fill(Color.black.opacity(0.15))
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
            )
    }
}
