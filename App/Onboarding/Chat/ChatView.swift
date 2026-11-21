import Observation
import SwiftUI

// MARK: - Model

/// One thing Lockie "says": a text bubble or the app-icon grid. Text supports **coral bold** and !!red!!.
enum ChatLine: Equatable {
    case text(String)
    case appGrid
}

struct ChatReply: Identifiable, Hashable {
    let id: String
    let text: String
}

/// A group of Lockie's lines followed by reply chips. `lines` gets the id of the previous reply (for branches).
struct ChatSegment {
    let lines: (_ previousReply: String?) -> [ChatLine]
    let replies: [ChatReply]
}

enum ChatEntry: Identifiable, Equatable {
    case lockie(id: Int, line: ChatLine)
    case user(id: Int, text: String, replyID: String)

    var id: Int {
        switch self {
        case .lockie(let id, _), .user(let id, _, _): return id
        }
    }
}

/// Plays a chat script: typing indicator → bubble pops in → … → "Tap to answer" + reply chips.
@Observable
@MainActor
final class ChatController {
    private(set) var entries: [ChatEntry] = []
    private(set) var typing = false
    private(set) var replies: [ChatReply] = []
    private(set) var showCaption = false
    private(set) var finished = false

    @ObservationIgnored private let segments: [ChatSegment]
    @ObservationIgnored private var index = 0
    @ObservationIgnored private var lastReply: String?
    @ObservationIgnored private var nextID = 0
    @ObservationIgnored private var running = false
    @ObservationIgnored var reduceMotion = false
    @ObservationIgnored var onFinish: () -> Void = {}

    init(segments: [ChatSegment]) { self.segments = segments }

    func start() {
        guard !running, entries.isEmpty else { return }
        Task { await playSegment() }
    }

    /// Typing time = clamp(0.45 + chars × 0.018, 0.6, 1.4)s.
    static func typingDuration(for line: ChatLine) -> Double {
        let chars: Int
        switch line {
        case .text(let s): chars = s.count
        case .appGrid: chars = 30
        }
        return min(1.4, max(0.6, 0.45 + Double(chars) * 0.018))
    }

    private func playSegment() async {
        guard index < segments.count else { return }
        running = true
        let segment = segments[index]
        for line in segment.lines(lastReply) {
            if reduceMotion {
                append(.lockie(id: takeID(), line: line), animation: .easeOut(duration: 0.2))
                continue
            }
            withAnimation(Motion.snappy) { typing = true }
            try? await Task.sleep(nanoseconds: UInt64(Self.typingDuration(for: line) * 1_000_000_000))
            typing = false
            append(.lockie(id: takeID(), line: line), animation: Motion.snappy)
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        withAnimation(Motion.smooth) { showCaption = true }
        withAnimation(Motion.smooth) { replies = segment.replies }
        running = false
    }

    func choose(_ reply: ChatReply) {
        guard !running, replies.contains(reply) else { return }
        withAnimation(Motion.snappy) {
            entries.append(.user(id: takeID(), text: reply.text, replyID: reply.id))
            replies = []
            showCaption = false
        }
        lastReply = reply.id
        index += 1
        if index >= segments.count {
            finished = true
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                onFinish()
            }
        } else {
            Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                await playSegment()
            }
        }
    }

    private func append(_ entry: ChatEntry, animation: Animation) {
        withAnimation(animation) { entries.append(entry) }
    }

    private func takeID() -> Int {
        nextID += 1
        return nextID
    }
}

// MARK: - View

/// Chat with Lockie: header (back, avatar, "Lockie", green dot + "Online", "Skip chat"), bubbles, typing
/// indicator, "Tap to answer" caption and reply chips that turn into the user's bubble.
struct ChatView: View {
    @State private var controller: ChatController
    let onBack: () -> Void
    let onSkip: () -> Void
    @Namespace private var chips
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(segments: [ChatSegment], onBack: @escaping () -> Void, onSkip: @escaping () -> Void,
         onFinish: @escaping () -> Void) {
        let c = ChatController(segments: segments)
        c.onFinish = onFinish
        _controller = State(initialValue: c)
        self.onBack = onBack
        self.onSkip = onSkip
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(controller.entries) { entry in
                            row(entry)
                        }
                        if controller.typing {
                            TypingBubble()
                                .transition(.scale(scale: 0.9, anchor: .bottomLeading).combined(with: .opacity))
                        }
                        repliesArea
                        Color.clear.frame(height: 8).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                }
                .onChange(of: controller.entries.count) { _, _ in scrollDown(proxy) }
                .onChange(of: controller.typing) { _, _ in scrollDown(proxy) }
                .onChange(of: controller.replies.count) { _, _ in scrollDown(proxy) }
            }
        }
        .background(Color.white.ignoresSafeArea())
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: controller.entries.count)
        .onAppear {
            controller.reduceMotion = reduceMotion
            controller.start()
        }
    }

    private func scrollDown(_ proxy: ScrollViewProxy) {
        withAnimation(Motion.smooth) { proxy.scrollTo("bottom", anchor: .bottom) }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .appFont(20, .semibold)
                    .foregroundStyle(Color.textPrimary)
                    .tapTarget()
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(Text("Back"))
            ZStack {
                Circle().fill(Color.brandTint)
                LockieView(expression: .happy, size: 34, breathing: false)
            }
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "Lockie").appFont(16, .bold).foregroundStyle(Color.textPrimary)
                HStack(spacing: 4) {
                    Circle().fill(Color.correctGreen).frame(width: 7, height: 7)
                    Text("Online").appFont(12).foregroundStyle(Color.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer()
            if !controller.finished {
                Button("Skip chat", action: onSkip)
                    .appFont(15, .semibold)
                    .foregroundStyle(Color.brandDeep)
                    .tapTarget()
                    .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func row(_ entry: ChatEntry) -> some View {
        switch entry {
        case .lockie(_, let line):
            Group {
                switch line {
                case .text(let text): LockieBubble(text: text)
                case .appGrid: AppGridBubble()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.scale(scale: 0.9, anchor: .bottomLeading).combined(with: .opacity))
        case .user(_, let text, let replyID):
            Text(LocalizedStringKey(text))
                .appFont(16, .semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.brand, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .matchedGeometryEffect(id: "reply-\(replyID)", in: chips)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var repliesArea: some View {
        if controller.showCaption {
            Text("Tap to answer")
                .appFont(12)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 10)
                .transition(.opacity)
        }
        ForEach(Array(controller.replies.enumerated()), id: \.element.id) { i, reply in
            Button {
                controller.choose(reply)
            } label: {
                Text(LocalizedStringKey(reply.text))
                    .appFont(16, .semibold)
                    .foregroundStyle(Color.brandDeep)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.brandTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .matchedGeometryEffect(id: "reply-\(reply.id)", in: chips)
            }
            .buttonStyle(PressableButtonStyle())
            .frame(maxWidth: .infinity, alignment: .trailing)
            .staggeredAppear(i, baseDelay: 0.05)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .accessibilityIdentifier("chat.reply")
        }
    }
}

/// Lockie's grey bubble with **coral bold** and !!red!! emphasis.
struct LockieBubble: View {
    let text: String

    var body: some View {
        Text(Self.styled(text))
            .appFont(16, .medium)
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(hex: 0xEFEFF2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: 290, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Parses `**coral bold**` and `!!red text!!` markers.
    static func styled(_ raw: String) -> AttributedString {
        var result = AttributedString()
        var rest = Substring(raw)
        while !rest.isEmpty {
            let boldRange = rest.range(of: "**")
            let redRange = rest.range(of: "!!")
            let next = [boldRange, redRange].compactMap { $0 }.min { $0.lowerBound < $1.lowerBound }
            guard let open = next else {
                result += AttributedString(String(rest))
                break
            }
            let marker = String(rest[open])
            result += AttributedString(String(rest[rest.startIndex..<open.lowerBound]))
            let afterOpen = rest[open.upperBound...]
            guard let close = afterOpen.range(of: marker) else {
                result += AttributedString(String(rest[open.lowerBound...]))
                break
            }
            var styled = AttributedString(String(afterOpen[afterOpen.startIndex..<close.lowerBound]))
            if marker == "**" {
                styled.foregroundColor = Color.brand
                styled.font = Font.system(size: 17, weight: .heavy)
            } else {
                styled.foregroundColor = Color.errorRed
                styled.font = Font.system(size: 16, weight: .bold)
            }
            result += styled
            rest = afterOpen[close.upperBound...]
        }
        return result
    }
}

/// Three bouncing dots.
struct TypingBubble: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color(hex: 0x9A9AA0))
                        .frame(width: 8, height: 8)
                        .offset(y: -3 * max(0, sin((t * 2 * .pi / 0.9) - Double(i) * 0.7)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(hex: 0xEFEFF2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .accessibilityLabel(Text("Lockie is typing"))
    }
}

/// The 8 apps built to keep you scrolling, as their real home-screen icons.
struct AppGridBubble: View {
    private let apps = ["tiktok", "youtube", "instagram", "x", "facebook", "threads", "reddit", "snapchat"]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(48), spacing: 10), count: 4), spacing: 10) {
            ForEach(0..<apps.count, id: \.self) { i in
                BrandAppIcon(name: apps[i], size: 48)
                    .staggeredAppear(i, baseDelay: 0)
            }
        }
        .padding(12)
        .background(Color(hex: 0xEFEFF2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityLabel(Text("TikTok, YouTube, Instagram, X, Facebook, Threads, Reddit and Snapchat"))
    }
}
