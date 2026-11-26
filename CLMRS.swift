import SwiftUI
import UIKit

// MARK: - Model

struct Client: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var ipaURL: String
    var appScheme: String
}

enum Installer: String, CaseIterable, Identifiable {
    case share, altstore, sidestore, trollstore
    var id: String { rawValue }
    var title: String {
        switch self {
        case .share: return "Share sheet (KSign, Files…)"
        case .altstore: return "AltStore"
        case .sidestore: return "SideStore"
        case .trollstore: return "TrollStore"
        }
    }
    var prefix: String {
        switch self {
        case .share: return ""
        case .altstore: return "altstore://install?url="
        case .sidestore: return "sidestore://install?url="
        case .trollstore: return "apple-magnifier://install?url="
        }
    }
}

final class ClientStore: ObservableObject {
    private static let key = "clmrs.clients"
    @Published var clients: [Client] {
        didSet { save() }
    }
    init() {
        if let data = UserDefaults.standard.data(forKey: ClientStore.key),
           let list = try? JSONDecoder().decode([Client].self, from: data) {
            clients = list
        } else {
            clients = []
        }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(clients) {
            UserDefaults.standard.set(data, forKey: ClientStore.key)
        }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - UI

struct ContentView: View {
    @StateObject private var store = ClientStore()
    @AppStorage("installer") private var installerRaw = Installer.share.rawValue
    @State private var name = ""
    @State private var ipa = ""
    @State private var scheme = ""
    @State private var message = ""
    @State private var shareItem: ShareItem? = nil

    private var installer: Installer { Installer(rawValue: installerRaw) ?? .share }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Install with")) {
                    Picker("Install with", selection: $installerRaw) {
                        ForEach(Installer.allCases) { item in
                            Text(item.title).tag(item.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(header: Text("Add a client")) {
                    TextField("Name (e.g. 2019 Player)", text: $name)
                    TextField("Direct link to the .ipa", text: $ipa)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    TextField("App link to open it (optional, e.g. myclient://)", text: $scheme)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    Button("Save to library") { addClient() }
                }

                if !message.isEmpty {
                    Section { Text(message).foregroundColor(.red) }
                }

                Section(header: Text("Library")) {
                    if store.clients.isEmpty {
                        Text("No clients yet. Add one above.").foregroundColor(.secondary)
                    }
                    ForEach(store.clients) { client in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(client.name).font(.headline)
                            Text(client.ipaURL).font(.caption).foregroundColor(.secondary)
                            HStack(spacing: 16) {
                                Button("Install") { install(client) }
                                    .buttonStyle(.borderless)
                                if !client.appScheme.isEmpty {
                                    Button("Open app") { openApp(client.appScheme) }
                                        .buttonStyle(.borderless)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { store.clients.remove(atOffsets: $0) }
                }

                Section(footer: Text("iOS doesn’t let one app install another. Install downloads the .ipa and hands it to KSign (or the installer you picked), which signs and installs it. Open app uses the client’s URL scheme, because iOS can’t list installed apps.")) {
                    EmptyView()
                }
            }
            .navigationTitle("CLMRS")
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
        }
        .navigationViewStyle(.stack)
        .accentColor(.red)
    }

    // MARK: Actions

    private func addClient() {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let u = ipa.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = scheme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { message = "Give the client a name."; return }
        guard validHTTP(u) else { message = "The .ipa link must start with https://"; return }
        if !s.isEmpty && !validScheme(s) { message = "The app link should look like myclient://"; return }
        store.clients.append(Client(name: n, ipaURL: u, appScheme: s))
        name = ""; ipa = ""; scheme = ""; message = ""
    }

    private func validHTTP(_ text: String) -> Bool {
        guard let url = URL(string: text), let sch = url.scheme?.lowercased() else { return false }
        return sch == "http" || sch == "https"
    }

    private func validScheme(_ text: String) -> Bool {
        guard text.contains("://"), let url = URL(string: text), let sch = url.scheme?.lowercased() else { return false }
        return !["javascript", "data", "file", "http", "https"].contains(sch)
    }

    private func install(_ client: Client) {
        guard validHTTP(client.ipaURL), let url = URL(string: client.ipaURL) else {
            message = "That .ipa link isn’t valid."
            return
        }
        message = ""
        if installer == .share {
            download(client, from: url)
        } else {
            let encoded = client.ipaURL.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? client.ipaURL
            if let target = URL(string: installer.prefix + encoded) {
                UIApplication.shared.open(target) { ok in
                    if !ok { message = "\(installer.title) doesn’t seem to be installed." }
                }
            }
        }
    }

    private func download(_ client: Client, from url: URL) {
        message = "Downloading…"
        Task {
            do {
                let (tmp, response) = try await URLSession.shared.download(from: url)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    throw URLError(.badServerResponse)
                }
                let safeName = client.name.replacingOccurrences(of: "/", with: "-")
                let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).ipa")
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tmp, to: dest)
                await MainActor.run {
                    message = ""
                    shareItem = ShareItem(url: dest)
                }
            } catch {
                await MainActor.run {
                    message = "Download failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func openApp(_ text: String) {
        guard validScheme(text), let url = URL(string: text) else {
            message = "That app link isn’t valid."
            return
        }
        UIApplication.shared.open(url) { ok in
            if !ok { message = "Couldn’t open it. Is the client installed?" }
        }
    }
}

@main
struct CLMRSApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
