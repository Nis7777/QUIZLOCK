import SwiftUI
import UIKit

// MARK: - The art

/// Lockie's poses (Assets: mascot_<name>). Missing art falls back to `mascot_pointing`.
enum MascotExpression: String, CaseIterable, Equatable {
    case wave, happy, worried, sad, thinking, clipboard, celebrate, calm, pointing

    var assetName: String { "mascot_\(rawValue)" }

    var image: UIImage? {
        UIImage(named: assetName) ?? UIImage(named: MascotExpression.pointing.assetName)
    }

    /// The eyes in the 780×780 art (x, y, width, height), for blinking. Measured by
    /// `Scripts/make_mascot_lids.py`, which also makes the matching `mascot_<name>_lids` layer: the
    /// same art with the eyes filled in with Lockie's own skin shading. nil = the eyes are already
    /// closed or squinting in the art (happy, celebrate, calm), so that pose never blinks.
    var eyes: [CGRect]? {
        switch self {
        case .wave: return [CGRect(x: 261, y: 300, width: 76, height: 95), CGRect(x: 427, y: 327, width: 79, height: 96)]
        case .worried: return [CGRect(x: 248, y: 316, width: 73, height: 90), CGRect(x: 399, y: 333, width: 76, height: 93)]
        case .sad: return [CGRect(x: 216, y: 398, width: 93, height: 76), CGRect(x: 372, y: 406, width: 98, height: 84)]
        case .thinking: return [CGRect(x: 228, y: 294, width: 85, height: 100), CGRect(x: 381, y: 338, width: 91, height: 96)]
        case .clipboard: return [CGRect(x: 239, y: 311, width: 79, height: 97), CGRect(x: 396, y: 338, width: 82, height: 98)]
        case .pointing: return [CGRect(x: 270, y: 302, width: 74, height: 90), CGRect(x: 435, y: 340, width: 76, height: 93)]
        case .happy, .celebrate, .calm: return nil
        }
    }

    var lidsAssetName: String { "mascot_\(rawValue)_lids" }

    /// The celebrate art has its floor shadow painted in below the feet (rows 744–780 of 780). It's
    /// drawn separately so it stays on the floor while Lockie is in the air.
    static let celebrateShadowTop: CGFloat = 744.0 / 780.0
    static let celebrateShadowCentre = UnitPoint(x: 0.513, y: 0.974)
}

// MARK: - States and triggers

/// What Lockie is doing. Blinking runs on its own on every pose with open eyes.
enum MascotAnimation: String, CaseIterable, Equatable {
    /// Gentle floating and breathing.
    case idle
    /// Two happy hops with squash and stretch (the happy art).
    case happy
    /// A big jump with arms raised (the celebrate art), a wiggle in the air and a squashy landing.
    case celebrate
    /// Slumped and leaning, with slow, heavy breaths and a sigh now and then (the sad art).
    case sad
    /// Eyes closed (the calm art), slow deep breathing and "z"s drifting up.
    case sleeping

    /// The art each state shows when the caller doesn't pick one.
    var defaultExpression: MascotExpression {
        switch self {
        case .idle: return .pointing
        case .happy: return .happy
        case .celebrate: return .celebrate
        case .sad: return .sad
        case .sleeping: return .calm
        }
    }

    /// How long it plays as a one-off reaction (`Mascot.play`), in ms.
    var reactionLength: Double {
        switch self {
        case .idle: return 0
        case .happy: return 1500
        case .celebrate: return 2000
        case .sad: return 3600
        case .sleeping: return 5200
        }
    }
}

/// Make Lockie react from anywhere in the app:
///
///     Mascot.play(.celebrate)            // every Lockie on screen
///     Mascot.play(.sad, tag: "unlock")   // only MascotView(..., tag: "unlock")
///
/// Lockie switches to that state's art, acts it out once, then glides back to what it was doing.
/// For a lasting state, pass it to the view instead: `MascotView(animation: .sleeping)`.
enum Mascot {
    static func play(_ animation: MascotAnimation, tag: String? = nil) {
        MascotDirector.shared.play(animation, tag: tag)
    }
}

/// Carries `Mascot.play` requests to every MascotView.
@Observable
final class MascotDirector {
    static let shared = MascotDirector()

    struct Request: Equatable {
        let animation: MascotAnimation
        let tag: String?
        let id = UUID()
    }

    private(set) var request: Request?

    func play(_ animation: MascotAnimation, tag: String?) {
        request = Request(animation: animation, tag: tag)
    }
}

// MARK: - Motion math

/// The helpers from rossark-motion-skill's Motion.swift, namespaced so they can't clash with app names.
enum MascotMath {
    /// Things that travel (a lid closing, settling into a pose): a strong ease-in-out.
    static let travel = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.77, y: 0), endControlPoint: UnitPoint(x: 0.175, y: 1))
    /// Things that arrive or open (a lid reopening, a blend finishing): a strong ease-out.
    static let arrive = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.23, y: 1), endControlPoint: UnitPoint(x: 0.32, y: 1))

    /// A smooth -1…1 back-and-forth.
    static func wave(_ t: Double, _ period: Double, _ phase: Double = 0) -> Double {
        sin((t / period + phase) * .pi * 2)
    }

    /// Progress through a loop, 0…1.
    static func loop(_ t: Double, _ period: Double, _ phase: Double = 0) -> Double {
        let p = (t / period + phase).truncatingRemainder(dividingBy: 1)
        return p < 0 ? p + 1 : p
    }

    /// 0 at both ends, 1 in the middle.
    static func bell(_ p: Double) -> Double { sin(.pi * min(1, max(0, p))) }

    /// 0 before `a`, 1 after `b`, eased in between.
    static func seg(_ t: Double, _ a: Double, _ b: Double, _ curve: UnitCurve = arrive) -> Double {
        if t <= a { return 0 }
        if t >= b { return 1 }
        return curve.value(at: (t - a) / (b - a))
    }

    /// Stable pseudo-random 0…1 for item `i`: the same on every frame.
    static func seeded(_ i: Int, _ salt: Double = 0) -> Double {
        let x = sin(Double(i) * 12.9898 + salt * 78.233) * 43758.5453
        return x - floor(x)
    }

    /// A smooth path through key poses (ms, value) that never stops dead or overshoots a key.
    static func flow(_ t: Double, _ k: [(Double, Double)]) -> Double {
        let n = k.count
        if t <= k[0].0 { return k[0].1 }
        if t >= k[n - 1].0 { return k[n - 1].1 }
        var i = 0
        while k[i + 1].0 < t { i += 1 }
        func slope(_ j: Int) -> Double { (k[j + 1].1 - k[j].1) / (k[j + 1].0 - k[j].0) }
        func tangent(_ j: Int) -> Double {
            guard j > 0, j < n - 1 else { return 0 }
            let a = slope(j - 1), b = slope(j)
            guard a * b > 0 else { return 0 }
            let h0 = k[j].0 - k[j - 1].0, h1 = k[j + 1].0 - k[j].0
            let w0 = 2 * h1 + h0, w1 = h1 + 2 * h0
            return (w0 + w1) / (w0 / a + w1 / b)
        }
        let h = k[i + 1].0 - k[i].0
        let s = (t - k[i].0) / h
        let s2 = s * s, s3 = s2 * s
        return (2 * s3 - 3 * s2 + 1) * k[i].1 + (s3 - 2 * s2 + s) * h * tangent(i)
            + (-2 * s3 + 3 * s2) * k[i + 1].1 + (s3 - s2) * h * tangent(i + 1)
    }
}

// MARK: - Poses

/// Lockie's whole-body transform. The art is one picture, so it moves as one piece around its feet.
struct MascotPose {
    /// Up, as a fraction of the mascot's size.
    var lift = 0.0
    var sx = 1.0
    var sy = 1.0
    /// Degrees, around the feet.
    var tilt = 0.0
    /// Sideways, as a fraction of the size.
    var dx = 0.0

    static let rest = MascotPose()

    /// Squash (< 1) or stretch (> 1) that keeps the volume: width = 1 / height^0.6.
    mutating func squash(_ s: Double) {
        sy *= s
        sx /= pow(s, 0.6)
    }

    func mixed(with o: MascotPose, _ w: Double) -> MascotPose {
        MascotPose(lift: lift + (o.lift - lift) * w, sx: sx + (o.sx - sx) * w, sy: sy + (o.sy - sy) * w,
                   tilt: tilt + (o.tilt - tilt) * w, dx: dx + (o.dx - dx) * w)
    }
}

/// Every number that shapes the motion, in one place. Times in ms; distances as a fraction of the size.
enum MascotTuning {
    // Idle
    static let floatHeight = 0.016, floatPeriod = 3600.0
    static let breath = 0.011, breathPeriod = 2600.0
    static let sway = 1.1, swayPeriod = 5300.0
    // Happy: two hops, then a rest, as a loop
    static let happyLoop = 2200.0
    // Celebrate: one big jump and a shimmy, as a loop
    static let celebrateLoop = 2400.0
    // Blinks: one every 2.6–5 s, 20% of them doubles
    static let blinkGapMin = 2600.0, blinkGapRange = 2400.0, doubleBlink = 0.2
    static let blinkClose = 115.0, blinkHold = 45.0, blinkOpen = 200.0
    // Blending between states
    static let stateBlend = 450.0, reactionIn = 180.0, reactionOut = 380.0
}

enum MascotChoreo {
    typealias T = MascotTuning

    /// Floating and breathing. At t = 0 it is exactly the rest pose (frame 0 is the still image).
    static func idle(_ g: Double, amount: Double = 1) -> MascotPose {
        var p = MascotPose()
        p.lift = T.floatHeight * (MascotMath.wave(g, T.floatPeriod, 0.75) + 1) / 2 * amount
        let b = T.breath * MascotMath.wave(g, T.breathPeriod) * amount
        p.sy = 1 + b
        p.sx = 1 + b * 0.45              // the chest fills out a little as it rises
        p.tilt = T.sway * MascotMath.wave(g, T.swayPeriod) * amount
        return p
    }

    /// One hop starting at `start`: crouch, stretch on take-off, an arc, squash on landing, one small
    /// overshoot, settle. Returns the lift and the squash/stretch factor (1 outside the hop).
    static func hop(_ t: Double, start: Double, height: Double, air: Double, crouch: Double, stretch: Double, land: Double) -> (lift: Double, s: Double) {
        let r = t - start
        let c = 130.0
        guard r > 0, r < c + air + 360 else { return (0, 1) }
        let s = MascotMath.flow(r, [
            (0, 1), (c, crouch), (c + 70, 1 + stretch), (c + air * 0.5, 1),
            (c + air - 40, 1 + stretch * 0.6), (c + air + 80, land),
            (c + air + 210, 1 + (1 - land) * 0.25), (c + air + 360, 1),
        ])
        var lift = 0.0
        if r > c, r < c + air {
            let u = (r - c) / air
            lift = height * 4 * u * (1 - u)
        }
        return (lift, s)
    }

    static func happy(_ t: Double, g: Double) -> MascotPose {
        var p = idle(g, amount: 0.35)
        let h1 = hop(t, start: 0, height: 0.075, air: 300, crouch: 0.92, stretch: 0.06, land: 0.9)
        let h2 = hop(t, start: 620, height: 0.05, air: 260, crouch: 0.94, stretch: 0.045, land: 0.92)
        p.lift += h1.lift + h2.lift
        p.squash(h1.s * h2.s)
        // Lean into each hop, a different way each time.
        p.tilt += -3.5 * MascotMath.bell((t - 130) / 300) + 3 * MascotMath.bell((t - 750) / 260)
        return p
    }

    static func celebrate(_ t: Double, g: Double) -> MascotPose {
        var p = idle(g, amount: 0.35)
        let j = hop(t, start: 0, height: 0.17, air: 540, crouch: 0.86, stretch: 0.1, land: 0.84)
        p.lift += j.lift
        p.squash(j.s)
        // A wiggle in the air, then a happy shimmy after landing that fades out.
        p.tilt += 5 * MascotMath.wave(t - 130, 300) * MascotMath.bell((t - 130) / 540)
        let shimmy = MascotMath.seg(t, 700, 820) * (1 - MascotMath.seg(t, 1250, 1650, MascotMath.travel))
        p.tilt += 3 * MascotMath.wave(t - 700, 340) * shimmy
        p.dx += 0.012 * MascotMath.wave(t - 700, 680) * shimmy
        return p
    }

    static func sad(_ t: Double, g: Double) -> MascotPose {
        var p = MascotPose()
        let settle = MascotMath.seg(t, 0, 650, MascotMath.travel)
        // Slumped: shorter and a little wider, leaning to one side, head hanging.
        p.sy = 1 - 0.035 * settle
        p.sx = 1 + 0.012 * settle
        p.tilt = 2.5 * settle + 0.8 * MascotMath.wave(g, 6200)
        // Slow, heavy breathing with a sigh every 6.4 s.
        let breath = 0.008 * MascotMath.wave(g, 4200)
        let sigh = MascotMath.flow(MascotMath.loop(g, 6400) * 6400, [(0, 0), (3900, 0), (4500, 0.022), (5400, -0.012), (6400, 0)])
        p.sy += breath + sigh
        p.sx += 0.45 * (breath + sigh)
        p.lift = 0.004 * (MascotMath.wave(g, 4200, 0.75) + 1) / 2
        return p
    }

    static func sleeping(_ t: Double, g: Double) -> MascotPose {
        var p = MascotPose()
        let settle = MascotMath.seg(t, 0, 800, MascotMath.travel)
        // Deep, slow breaths and a slow nod to one side.
        let breath = 0.022 * MascotMath.wave(g, 4600)
        p.sy = 1 + breath
        p.sx = 1 + 0.6 * breath
        p.tilt = (1.5 + 1.8 * MascotMath.wave(g, 9200)) * settle
        return p
    }

    /// `t`: ms since this state started. `g`: ms since the view appeared (drives the idle loops,
    /// so they never jump when the state changes). `once`: a reaction plays its action once.
    static func pose(_ a: MascotAnimation, t: Double, g: Double, once: Bool = false) -> MascotPose {
        switch a {
        case .idle: return idle(g)
        case .happy: return happy(once ? t : t.truncatingRemainder(dividingBy: T.happyLoop), g: g)
        case .celebrate: return celebrate(once ? t : t.truncatingRemainder(dividingBy: T.celebrateLoop), g: g)
        case .sad: return sad(t, g: g)
        case .sleeping: return sleeping(t, g: g)
        }
    }

    /// Reduce Motion / not live: a still that still reads (slumped when sad, leaning when asleep).
    static func still(_ a: MascotAnimation) -> MascotPose {
        switch a {
        case .idle, .happy, .celebrate: return .rest
        case .sad: return sad(10_000, g: 0)
        case .sleeping: return sleeping(10_000, g: 0)
        }
    }

    /// One blink, 0 (open) → 1 (closed) → 0: closes fast, holds, reopens slower with ease-out.
    static func blinkShape(_ dt: Double, slow: Bool) -> Double {
        let k = slow ? 1.4 : 1
        let close = T.blinkClose * k, hold = T.blinkHold * k, open = T.blinkOpen * k
        if dt <= 0 || dt >= close + hold + open { return 0 }
        if dt < close { return MascotMath.seg(dt, 0, close, MascotMath.travel) }
        if dt < close + hold { return 1 }
        return 1 - MascotMath.seg(dt, close + hold, close + hold + open)
    }

    /// Eye closure at `g`: blinks at seeded, irregular gaps (each Lockie has its own seed, so two on
    /// one screen never blink together), now and then a double blink.
    static func blink(_ g: Double, seed: Int, slow: Bool) -> Double {
        var starts: [Double] = []
        var cycle = 1400.0
        for i in 0..<8 {
            starts.append(cycle)
            cycle += T.blinkGapMin + T.blinkGapRange * MascotMath.seeded(i, Double(seed))
        }
        let tm = g.truncatingRemainder(dividingBy: cycle)
        var c = 0.0
        for (i, s) in starts.enumerated() {
            c = max(c, blinkShape(tm - s, slow: slow))
            if MascotMath.seeded(i, Double(seed) + 7) < T.doubleBlink {
                c = max(c, blinkShape(tm - s - 340, slow: slow))
            }
        }
        return c
    }
}

// MARK: - MascotView

/// Lockie, alive. Use it anywhere:
///
///     MascotView()                                   // idle: floats, breathes, blinks
///     MascotView(animation: .sleeping, size: 160)    // a lasting state
///     MascotView(expression: .thinking)              // any pose, idling
///     MascotView(expression: .pointing, entrance: .happy)   // hops once when it appears
///
/// Trigger reactions from anywhere with `Mascot.play(.celebrate)`. One clock per Lockie, paused when
/// it's off screen, the app is in the background or Reduce Motion is on (then it's a still picture).
struct MascotView: View {
    var animation: MascotAnimation = .idle
    /// The art. nil = the state's own art (`animation.defaultExpression`).
    var expression: MascotExpression?
    var size: CGFloat = 200
    /// false = a still picture (small avatars).
    var isLive = true
    /// Only `Mascot.play(_:tag:)` calls with this tag (or no tag) reach this Lockie.
    var tag: String?
    /// Played once when the view appears, keeping its own art (e.g. a hop on a welcome screen).
    var entrance: MascotAnimation?
    /// Arriving at the happy or celebrate art plays that action once (used by the onboarding Lockie).
    var actsOnArrival = false
    /// The bouncy pop-in from 0.6 when it first appears.
    var popsIn = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var director = MascotDirector.shared
    @State private var seed = Int.random(in: 0..<10_000)
    @State private var bornAt = Date()
    @State private var change = StateChange(from: nil, at: .distantPast)
    @State private var reaction: Reaction?
    @State private var stillReaction: MascotExpression?
    @State private var visible = false
    @State private var appeared = false

    private struct StateChange { var from: MascotAnimation?; var at: Date }
    private struct Reaction { let animation: MascotAnimation; let usesItsArt: Bool; let at: Date }

    private var resting: MascotExpression { stillReaction ?? expression ?? animation.defaultExpression }
    private var live: Bool { isLive && !reduceMotion && visible && scenePhase == .active }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !live)) { context in
            rig(frame(at: context.date))
        }
        .frame(width: size, height: size)
        .modifier(MascotSquash(trigger: resting, enabled: !reduceMotion))
        .scaleEffect(appeared || reduceMotion || !popsIn ? 1 : 0.6)
        .opacity(appeared || !popsIn ? 1 : 0)
        .animation(Motion.respecting(reduceMotion, Motion.smooth), value: resting)
        .sensoryFeedback(.impact(weight: .light), trigger: resting)
        .onAppear {
            visible = true
            if popsIn {
                withAnimation(Motion.respecting(reduceMotion, Motion.bouncy)) { appeared = true }
            } else {
                appeared = true
            }
            if let first = entrance ?? arrivalAction(for: resting) {
                // After the pop-in (ours, or the screen's own when popsIn is false).
                start(first, usesItsArt: false, delay: 0.3)
            }
        }
        .onDisappear { visible = false }
        .onChange(of: animation) { old, _ in
            change = StateChange(from: old, at: Date())
        }
        .onChange(of: expression) { _, new in
            if let new, let action = arrivalAction(for: new) { start(action, usesItsArt: false) }
        }
        .onChange(of: director.request) { _, request in
            guard let request, request.tag == nil || request.tag == tag else { return }
            start(request.animation, usesItsArt: true)
        }
        .accessibilityLabel(Text("Lockie"))
    }

    private func arrivalAction(for e: MascotExpression) -> MascotAnimation? {
        guard actsOnArrival else { return nil }
        switch e {
        case .celebrate: return .celebrate
        case .happy: return .happy
        default: return nil
        }
    }

    private func start(_ a: MascotAnimation, usesItsArt: Bool, delay: Double = 0) {
        guard a != .idle else { return }
        if reduceMotion || !isLive {
            // No motion: just show that state's art for a moment.
            guard usesItsArt else { return }
            withAnimation(.easeOut(duration: 0.2)) { stillReaction = a.defaultExpression }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(Int(a.reactionLength)))
                withAnimation(.easeOut(duration: 0.2)) { stillReaction = nil }
            }
            return
        }
        reaction = Reaction(animation: a, usesItsArt: usesItsArt, at: Date().addingTimeInterval(delay))
    }

    // MARK: Frame

    private struct Frame {
        var pose = MascotPose.rest
        var art: MascotExpression
        var reactionArt: MascotExpression?
        var reactionArtWeight = 0.0
        var closure = 0.0
        var zzz = 0.0
        /// ms since the view appeared.
        var g = 0.0
    }

    private func frame(at date: Date) -> Frame {
        var f = Frame(art: resting)
        guard live else {
            f.pose = MascotChoreo.still(animation)
            return f
        }
        let g = date.timeIntervalSince(bornAt) * 1000
        f.g = g
        let since = date.timeIntervalSince(max(change.at, bornAt)) * 1000

        // The lasting state, blended from the previous one after a change, so nothing jumps.
        f.pose = MascotChoreo.pose(animation, t: since, g: g)
        if let from = change.from, since < MascotTuning.stateBlend {
            f.pose = MascotChoreo.pose(from, t: g, g: g)
                .mixed(with: f.pose, MascotMath.seg(since, 0, MascotTuning.stateBlend, MascotMath.travel))
        }
        if animation == .sleeping { f.zzz = MascotMath.seg(since, 300, 1200) }
        var extraBlink = change.from != nil ? MascotChoreo.blinkShape(since, slow: false) : 0

        // A one-off reaction on top, faded in and out of the lasting state.
        if let r = reaction {
            let rt = date.timeIntervalSince(r.at) * 1000
            let len = r.animation.reactionLength
            if rt >= 0, rt < len {
                let w = min(MascotMath.seg(rt, 0, MascotTuning.reactionIn),
                            1 - MascotMath.seg(rt, len - MascotTuning.reactionOut, len, MascotMath.travel))
                f.pose = f.pose.mixed(with: MascotChoreo.pose(r.animation, t: rt, g: g, once: true), w)
                if r.usesItsArt, r.animation.defaultExpression != f.art {
                    f.reactionArt = r.animation.defaultExpression
                    f.reactionArtWeight = min(MascotMath.seg(rt, 0, 160), 1 - MascotMath.seg(rt, len - 300, len))
                }
                if r.animation == .sleeping { f.zzz = max(f.zzz, w) }
                extraBlink = max(extraBlink, MascotChoreo.blinkShape(rt, slow: false))
            }
        }

        let slow = animation == .sad || f.art == .sad || f.reactionArt == .sad
        f.closure = max(MascotChoreo.blink(g, seed: seed, slow: slow), extraBlink)
        return f
    }

    // MARK: Drawing

    @ViewBuilder
    private func rig(_ f: Frame) -> some View {
        let celebrateWeight = (f.art == .celebrate ? 1 - f.reactionArtWeight : 0)
            + (f.reactionArt == .celebrate ? f.reactionArtWeight : 0)
        ZStack {
            // The celebrate art's floor shadow stays on the floor and shrinks as Lockie rises.
            if celebrateWeight > 0, let image = MascotExpression.celebrate.image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .mask(alignment: .bottom) { MascotBand(from: MascotExpression.celebrateShadowTop, to: 1) }
                    .scaleEffect(1 - min(0.45, f.pose.lift * 2.4), anchor: MascotExpression.celebrateShadowCentre)
                    .opacity(celebrateWeight)
            }
            ZStack {
                MascotArt(expression: f.art, closure: f.closure)
                    .id(f.art)
                    .transition(.opacity)
                    .opacity(1 - f.reactionArtWeight)
                if let other = f.reactionArt {
                    MascotArt(expression: other, closure: f.closure)
                        .opacity(f.reactionArtWeight)
                }
            }
            .scaleEffect(x: f.pose.sx, y: f.pose.sy, anchor: .bottom)
            .rotationEffect(.degrees(f.pose.tilt), anchor: .bottom)
            .offset(x: f.pose.dx * size, y: -f.pose.lift * size)
            if f.zzz > 0.001 {
                MascotSleepZs(g: f.g, amount: f.zzz, size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

/// A horizontal band of a view, from `from` to `to` (fractions of its height), for masking.
private struct MascotBand: View {
    let from: CGFloat
    let to: CGFloat

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .frame(height: geo.size.height * (to - from))
                .offset(y: geo.size.height * from)
        }
    }
}

/// One pose of the art, with its eyelids when it blinks.
private struct MascotArt: View {
    let expression: MascotExpression
    let closure: Double

    var body: some View {
        if let image = expression.image {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .mask { MascotBand(from: 0, to: expression == .celebrate ? MascotExpression.celebrateShadowTop : 1) }
                .overlay {
                    if closure > 0.002, let eyes = expression.eyes, UIImage(named: expression.lidsAssetName) != nil {
                        MascotLids(eyes: eyes, asset: expression.lidsAssetName, closure: closure)
                    }
                }
        } else {
            Image(systemName: "lock.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(Color.brand)
                .padding(20)
        }
    }
}

/// The blink. The upper lid comes down to 62% of the eye with a curved edge and the lower lid rises to
/// meet it, both cut from the `_lids` layer (the same art with the eyes filled in with skin), so the
/// lids are Lockie's own shading. A dark lash rides the upper lid's edge and becomes the closed eye,
/// in the same style as the closed eyes in the calm art.
private struct MascotLids: View {
    let eyes: [CGRect]
    let asset: String
    let closure: Double

    private static let meet = 0.62, sag = 0.2
    private static let lash = Color(red: 52 / 255, green: 26 / 255, blue: 22 / 255)

    var body: some View {
        Canvas { ctx, canvas in
            let k = canvas.width / 780
            func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * k, y: y * k) }
            let skin = ctx.resolve(Image(asset))
            let p = min(1, max(0, closure))
            for e in eyes {
                let x = Double(e.minX), y = Double(e.minY), w = Double(e.width), h = Double(e.height)
                let pad = 6.0
                let x0 = x - pad, x1 = x + w + pad, mid = (x0 + x1) / 2
                let bulge = Self.sag * p * h
                let edge = y - pad + p * (Self.meet * h + pad)
                let low = y + h + pad - p * ((1 - Self.meet) * h + pad)

                var lids = Path()
                lids.move(to: pt(x0, y - pad - 20))
                lids.addLine(to: pt(x1, y - pad - 20))
                lids.addLine(to: pt(x1, edge))
                lids.addQuadCurve(to: pt(x0, edge), control: pt(mid, edge + 2 * bulge))
                lids.closeSubpath()
                lids.move(to: pt(x0, y + h + pad + 20))
                lids.addLine(to: pt(x1, y + h + pad + 20))
                lids.addLine(to: pt(x1, low))
                lids.addQuadCurve(to: pt(x0, low), control: pt(mid, low + 2 * 0.6 * bulge))
                lids.closeSubpath()
                ctx.drawLayer { layer in
                    layer.clip(to: lids)
                    layer.draw(skin, in: CGRect(origin: .zero, size: canvas))
                }

                guard p > 0.05 else { continue }
                // The lash: a tapered crescent along the upper lid's edge.
                let thick = 0.12 * w * (0.35 + 0.65 * p)
                var top: [CGPoint] = [], bottom: [CGPoint] = []
                for i in 0...24 {
                    let s = 0.1 + 0.8 * Double(i) / 24
                    let cx = x0 + (x1 - x0) * s
                    let cy = edge + bulge * (1 - pow(2 * s - 1, 2))
                    let taper = pow(max(0, sin(.pi * (s - 0.1) / 0.8)), 0.6)   // max: rounding can dip below 0 at the end
                    top.append(pt(cx, cy - 0.25 * thick * taper))
                    bottom.append(pt(cx, cy + 0.75 * thick * taper))
                }
                var lash = Path()
                lash.addLines(top + bottom.reversed())
                lash.closeSubpath()
                ctx.fill(lash, with: .color(Self.lash.opacity(min(1, p * 1.4))))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Three "z"s drifting up from the sleeping Lockie's head, each on its own phase.
private struct MascotSleepZs: View {
    let g: Double
    let amount: Double
    let size: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let p = MascotMath.loop(g, 3900, Double(i) / 3)
                Text(verbatim: "z")
                    .font(.system(size: size * (0.075 + 0.025 * Double(i % 2)), weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 92 / 255, green: 48 / 255, blue: 38 / 255))
                    .scaleEffect(0.6 + 0.6 * p)
                    .opacity(MascotMath.bell(p) * amount)
                    // From beside the head, up and out to the right, clear of the shackle.
                    .position(x: size * (0.80 + 0.12 * p + 0.02 * MascotMath.wave(g, 1700, Double(i) * 0.3)),
                              y: size * (0.40 - 0.28 * p))
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - LockieView (the existing API)

/// Lockie as the app has always used it: pick a pose and a size. It now floats, breathes and blinks;
/// the sad pose slumps; arriving at the happy or celebrate pose plays that action once.
/// `breathing: false` keeps it a still picture (small chat avatars).
struct LockieView: View {
    let expression: MascotExpression
    var size: CGFloat = 200
    var breathing = true

    var body: some View {
        MascotView(animation: expression == .sad ? .sad : .idle, expression: expression, size: size,
                   isLive: breathing, actsOnArrival: true)
    }
}

/// 0.92 → 1.04 → 1.0 on every change of art.
private struct MascotSquash: ViewModifier {
    let trigger: MascotExpression
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
                view.scaleEffect(x: 2 - scale, y: scale, anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(0.92, duration: 0.09, spring: .snappy)
                    SpringKeyframe(1.04, duration: 0.16, spring: .bouncy)
                    SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
                }
            }
        } else {
            content
        }
    }
}

#Preview("Mascot animations") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 24) {
            ForEach(MascotAnimation.allCases, id: \.self) { a in
                VStack {
                    MascotView(animation: a, size: 150)
                    Text(a.rawValue).font(.caption)
                }
            }
            VStack {
                MascotView(expression: .thinking, size: 150)
                Text("thinking, idle").font(.caption)
            }
        }
        .padding()
        HStack {
            ForEach(MascotAnimation.allCases.filter { $0 != .idle }, id: \.self) { a in
                Button(a.rawValue) { Mascot.play(a) }.buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Shared mascot between onboarding screens

/// A screen reserves a spot for Lockie with `MascotSlot`; the onboarding container draws ONE Lockie at
/// that spot, so it glides between consecutive screens instead of disappearing and reappearing.
struct MascotSlotEntry {
    let expression: MascotExpression
    let anchor: Anchor<CGRect>
}

struct MascotSlotKey: PreferenceKey {
    static let defaultValue: [MascotSlotEntry] = []
    static func reduce(value: inout [MascotSlotEntry], nextValue: () -> [MascotSlotEntry]) {
        value.append(contentsOf: nextValue())
    }
}

/// Empty space of `size` where the container's Lockie appears.
struct MascotSlot: View {
    let expression: MascotExpression
    var size: CGFloat = 200

    var body: some View {
        Color.clear
            .frame(width: size, height: size)
            .anchorPreference(key: MascotSlotKey.self, value: .bounds) { [MascotSlotEntry(expression: expression, anchor: $0)] }
            .accessibilityElement()
            .accessibilityLabel(Text("Lockie"))
    }
}

/// Draws the shared Lockie at the newest slot. Moves with Motion.smooth when the slot moves.
struct SharedMascotOverlay: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(MascotSlotKey.self) { slots in
            GeometryReader { proxy in
                if let slot = slots.last {
                    let rect = proxy[slot.anchor]
                    LockieView(expression: slot.expression, size: max(rect.width, 1))
                        .position(x: rect.midX, y: rect.midY)
                        .animation(Motion.respecting(reduceMotion, Motion.smooth), value: rect)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}
