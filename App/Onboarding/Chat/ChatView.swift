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
    /// The reply just tapped: it takes the sent-bubble look in place, then flies into the conversation.
    private(set) var sending: String?

    @ObservationIgnored private let segments: [ChatSegment]
    @ObservationIgnored private var index = 0
    @ObservationIgnored private var lastReply: String?
    @ObservationIgnored private var nextID = 0
    @ObservationIgnored private var running = false
    @ObservationIgnored var reduceMotion = false
    @ObservationIgnored var onFinish: () -> Void = {}

    init(segments: [ChatSegment]) { self.segments = segments }

    /// Every change in the chat (dots, bubbles, chips) and the scroll that follows it ride this one
    /// curve, so they move as a single glide instead of separate jumps.
    static let flow = Animation.spring(response: 0.42, dampingFraction: 0.9)

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
            withAnimation(Self.flow) { typing = true }
            try? await Task.sleep(nanoseconds: UInt64(Self.typingDuration(for: line) * 1_000_000_000))
            // The dots turn into the message in ONE change, so the chat never shrinks then grows.
            let entry = ChatEntry.lockie(id: takeID(), line: line)
            withAnimation(Self.flow) {
                typing = false
                entries.append(entry)
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        withAnimation(Self.flow) {
            showCaption = true
            replies = segment.replies
        }
        running = false
    }

    /// Two beats, so the reply never snaps: (1) the tapped chip turns coral with white text in place
    /// while the other chips and the caption fade; (2) it moves into the conversation as the user's
    /// bubble (matched geometry, Motion.mascot). Then Lockie's typing indicator shows before he answers.
    func choose(_ reply: ChatReply) {
        guard !running, sending == nil, replies.contains(reply) else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : Motion.snappy) {
            sending = reply.id
            showCaption = false
        }
        Task {
            try? await Task.sleep(nanoseconds: reduceMotion ? 0 : 160_000_000)
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Self.flow) {
                entries.append(.user(id: takeID(), text: reply.text, replyID: reply.id))
                replies = []
            }
            lastReply = reply.id
            index += 1
            if index >= segments.count {
                finished = true
                try? await Task.sleep(nanoseconds: 500_000_000)
                onFinish()
            } else {
                // Let the bubble land before Lockie starts typing.
                try? await Task.sleep(nanoseconds: 450_000_000)
                sending = nil
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
            // Pinned to the bottom like Messages: when a bubble, the typing dots or the reply chips arrive,
            // the scroll view keeps its bottom edge in place, so the new item appears fully at the bottom and
            // everything above slides up in the same animation. There's no separate scroll afterwards (that
            // used to show the new bubble half cut off, then jump).
            GeometryReader { viewport in
            ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(controller.entries) { entry in
                        row(entry)
                    }
                    if controller.typing {
                        TypingBubble()
                            .transition(.scale(scale: 0.85, anchor: .bottomLeading).combined(with: .opacity))
                    }
                    repliesArea
                    Color.clear.frame(height: 8).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                // At least as tall as the screen, top-aligned: the first messages start at the top, and
                // once the chat fills the screen it stays pinned to the bottom as new ones arrive.
                .frame(minHeight: viewport.size.height, alignment: .top)
            }
            .modifier(PinnedToBottom())
            // Glide to the newest item on the same curve as its arrival (same frame, same spring).
            .onChange(of: controller.entries.count) { _, _ in glide(proxy) }
            .onChange(of: controller.typing) { _, _ in glide(proxy) }
            .onChange(of: controller.replies.count) { _, _ in glide(proxy) }
            }
            }
        }
        .background(Color.white.ignoresSafeArea())
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: controller.entries.count)
        .onAppear {
            controller.reduceMotion = reduceMotion
            controller.start()
        }
    }

    private func glide(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : ChatController.flow) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
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
            .transition(.scale(scale: 0.85, anchor: .bottomLeading).combined(with: .opacity))
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
                .transition(.identity)   // it moves in from the chip via matched geometry
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
            let isSending = controller.sending == reply.id
            let otherSending = controller.sending != nil && !isSending
            Button {
                controller.choose(reply)
            } label: {
                Text(LocalizedStringKey(reply.text))
                    .appFont(16, .semibold)
                    .foregroundStyle(isSending ? Color.white : Color.brandDeep)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isSending ? Color.brand : Color.brandTint,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .matchedGeometryEffect(id: "reply-\(reply.id)", in: chips)
            }
            .buttonStyle(PressableButtonStyle())
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(otherSending ? 0 : 1)
            .scaleEffect(otherSending ? 0.95 : 1, anchor: .trailing)
            .staggeredAppear(i, baseDelay: 0.05)
            // The tapped chip hands over to the sent bubble (same frame, same look): no fade, no double.
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: isSending ? .identity : .opacity))
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

/// Keeps a scroll view's bottom edge in place: where it starts, and whenever its content grows.
private struct PinnedToBottom: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .defaultScrollAnchor(.bottom)
                .defaultScrollAnchor(.bottom, for: .sizeChanges)
        } else {
            content.defaultScrollAnchor(.bottom)
        }
    }
}
