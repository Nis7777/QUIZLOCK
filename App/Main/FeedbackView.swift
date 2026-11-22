import MessageUI
import SwiftUI
import UIKit

enum FeedbackType: String, CaseIterable, Identifiable {
    case suggestion = "Suggestion"
    case bug = "Bug report"
    case question = "Question"
    case other = "Other"
    var id: String { rawValue }
}

/// The feedback text, kept out of the tab's own state so a keystroke re-renders only the editor and the
/// send button (not the whole tab). Saved on this device as it's typed.
@Observable
final class FeedbackDraft {
    private static let key = "feedback.draft"
    private(set) var text = UserDefaults.standard.string(forKey: FeedbackDraft.key) ?? ""
    private(set) var hasText = false

    init() { hasText = Self.hasContent(text) }

    func set(_ value: String) {
        guard value != text else { return }
        text = value
        UserDefaults.standard.set(value, forKey: Self.key)
        let has = Self.hasContent(value)
        if has != hasText { hasText = has }
    }

    private static func hasContent(_ s: String) -> Bool { !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// Feedback tab.
struct FeedbackTab: View {
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @State private var draft = FeedbackDraft()
    @AppStorage("feedback.type") private var typeRaw = FeedbackType.suggestion.rawValue
    @State private var showMail = false
    @State private var copied = false
    @FocusState private var editorFocused: Bool

    private var type: FeedbackType { FeedbackType(rawValue: typeRaw) ?? .suggestion }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Feedback")
                    .appFont(17, .semibold)
                    .foregroundStyle(palette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                Text("Help improve \(Brand.appName)")
                    .appFont(34, .bold)
                    .foregroundStyle(palette.textPrimary)
                    .padding(.top, 6)
                Text("Found a problem or have an idea? Send me a note.")
                    .appFont(17)
                    .foregroundStyle(palette.textSecondary)
                formCard
                PrimaryButton(title: "Continue to email", systemImage: "envelope", isEnabled: draft.hasText) { sendEmail() }
                Text("Your draft is saved on this device. You'll review and send from your email account, so I can reply.")
                    .appFont(14)
                    .foregroundStyle(palette.textSecondary)
                directCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .overlay(alignment: .top) {
            if copied {
                Toast(text: String(localized: "Copied")).padding(.top, 8)
            }
        }
        .sheet(isPresented: $showMail) {
            MailComposer(recipient: Brand.supportEmail, subject: subject, body: mailBody) { showMail = false }
                .ignoresSafeArea()
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("What's on your mind?").appFont(17, .semibold).foregroundStyle(palette.textPrimary)
                Spacer()
                Menu {
                    Picker("Type", selection: $typeRaw) {
                        ForEach(FeedbackType.allCases) { t in Text(LocalizedStringKey(t.rawValue)).tag(t.rawValue) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey(type.rawValue))
                        Image(systemName: "chevron.up.chevron.down").appFont(12, .semibold)
                    }
                    .appFont(16, .semibold)
                    .foregroundStyle(palette.accentText)
                }
            }
            Divider()
            FeedbackEditor(draft: draft, focused: $editorFocused)
        }
        .card()
    }

    private var directCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Email me directly").appFont(17, .semibold).foregroundStyle(palette.textPrimary)
            Text(Brand.supportEmail).appFont(16, .medium).foregroundStyle(palette.accentText)
                .textSelection(.enabled)
            Button {
                UIPasteboard.general.string = Brand.supportEmail
                Haptics.success()
                withAnimation { copied = true }
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    withAnimation { copied = false }
                }
            } label: {
                Label("Copy email address", systemImage: "doc.on.doc")
                    .appFont(16, .medium)
                    .foregroundStyle(palette.textPrimary)
            }
            .buttonStyle(.plain)
        }
        .card()
    }

    private var subject: String { "[\(Brand.appName)] " + String(localized: String.LocalizationValue(type.rawValue)) }

    private var mailBody: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let ios = UIDevice.current.systemVersion
        return "\(draft.text)\n\n—\n\(Brand.appName) \(version) (\(build)) · iOS \(ios)"
    }

    private func sendEmail() {
        editorFocused = false
        if MFMailComposeViewController.canSendMail() {
            showMail = true
        } else {
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = Brand.supportEmail
            components.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: mailBody)]
            if let url = components.url { openURL(url) }
        }
    }
}

/// The text editor and its placeholder: the only part of the tab that re-renders while typing.
private struct FeedbackEditor: View {
    let draft: FeedbackDraft
    var focused: FocusState<Bool>.Binding
    @Environment(\.palette) private var palette

    var body: some View {
        let current = draft.text
        ZStack(alignment: .topLeading) {
            if current.isEmpty {
                Text("Tell me what happened or what you'd like to see…")
                    .appFont(16)
                    .foregroundStyle(palette.textSecondary.opacity(0.7))
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: Binding(get: { current }, set: { draft.set($0) }))
                .appFont(16)
                .foregroundStyle(palette.textPrimary)
                .scrollContentBackground(.hidden)
                .focused(focused)
                .frame(minHeight: 150)
        }
        .transaction { $0.animation = nil }
    }
}

struct MailComposer: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            onFinish()
        }
    }
}
