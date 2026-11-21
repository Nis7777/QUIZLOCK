# QuizLock motion & feel spec ("premium, like Duolingo / Opal")

Apply this to the WHOLE app, and especially to onboarding and the paywall. Native SwiftUI only (iOS 17+): no third-party animation libraries.

## 0. Principles
- **Everything moves with springs**, never linear or easeInOut. Things should feel physical: a slight overshoot, then settle.
- **Nothing pops in all at once.** Content enters in a **stagger**, top to bottom, 50–70ms apart.
- **Every tap gets feedback**: a press-down scale, a haptic, and a visual state change, all within 100ms.
- **Transitions keep context.** Elements that exist on both screens (mascot, progress bar, buttons) move instead of disappearing.
- **60/120 fps, no hitches.** No heavy work on the main thread during transitions. Pre-render images, and pre-load the next onboarding screen.
- **Respect Reduce Motion.** If it's on, replace movement with simple opacity fades.

## 1. Motion tokens (create `App/Design/Motion.swift` and use ONLY these)
```swift
enum Motion {
    static let snappy   = Animation.spring(response: 0.32, dampingFraction: 0.82) // taps, toggles, selections
    static let smooth   = Animation.spring(response: 0.45, dampingFraction: 0.86) // screen content, cards
    static let bouncy   = Animation.spring(response: 0.50, dampingFraction: 0.62) // celebrations, mascot, success
    static let gentle   = Animation.spring(response: 0.70, dampingFraction: 0.90) // big layout changes, paywall
    static let stagger: Double = 0.06                                              // delay between list items
}
```
Delete any `.easeInOut`, `.linear` or fixed `withAnimation(.default)` in the app and replace it with these.

## 2. Reusable building blocks (in `App/Design/`)
1. **`PressableButtonStyle`**: scale to 0.96 + opacity 0.9 on press (Motion.snappy), plus `.sensoryFeedback(.impact(weight: .light), trigger:)` on tap. Use it for EVERY button and tappable card.
2. **`.staggeredAppear(index:)` modifier**: the view starts at opacity 0, offset y +18 and blur 4, then animates in with Motion.smooth after `index * Motion.stagger`. Use it on every onboarding screen's title, subtitle, cards and button, in order.
3. **`SelectableCard`** (onboarding answers, plans, game picker):
   - Selecting animates the border to coral 2pt, the background to a peach tint, and a checkmark scaling in from 0.5 with Motion.bouncy.
   - Unselected cards dim slightly (opacity 0.85).
   - Haptic: `.selection`.
4. **`AnimatedNumber`**: numbers use `.contentTransition(.numericText(value:))` with Motion.smooth (screen time, streak, years on phone, prices, "X of 5 unlocks").
5. **`ConfettiView`**: coral/yellow/green/purple rounded confetti burst with gravity (built with Canvas + TimelineView), max 1.2s. Pair it with `.sensoryFeedback(.success, ...)`.
6. **`Shimmer`**: a subtle moving light sweep across the main CTA every 3s (paywall "Start 7-day free trial", onboarding final button).

## 3. Onboarding
- **Container:** one `OnboardingContainer` holding the progress bar and the back button. They NEVER re-render between steps; only the content area changes.
- **Progress bar:** a coral capsule whose width animates with Motion.smooth to the new value on each step, plus a tiny glow at the leading edge.
- **Step transition:** forward = the new content slides in from the right 40pt + fades, and the old content slides left 40pt + fades. Back = mirrored. Use `.transition(.asymmetric(...))` with Motion.smooth. Never use a plain push-navigation slide.
- **Each screen's content:** staggered appear (title → subtitle → options → button).
- **Single-choice answer:** card select animation + haptic, wait 0.35s, then auto-advance.
- **Mascot:** whenever it's on screen, it has a gentle idle "breathing" (scale 1.0 ↔ 1.02, 2.4s loop, `phaseAnimator`) plus a slight rotation wobble (±2°). When it appears, it pops in with Motion.bouncy from scale 0.6. Use `matchedGeometryEffect` for the mascot between screens where it appears consecutively, so it moves instead of reappearing.
- **"Calculating" screen:**
  - The ring fills with Motion.gentle over ~2.4s using `.trim`.
  - Each step label ticks: the circle turns into a checkmark with `.symbolEffect(.bounce)`, plus a light haptic.
  - Percentage numbers use numericText.
- **Reality check ("X years"):** the number counts up from 0 using numericText over ~1s, with a heavy haptic when it lands. The comparison bars grow from 0 width with a stagger.
- **"Hold to commit":**
  - The ring fills while pressing, with continuous light haptics that get stronger as it fills.
  - The button scales down to 0.94 while held.
  - Releasing early makes the ring spring back to 0.
  - On complete: the button morphs into a checkmark, confetti, and a `.success` haptic.
- **"How it works" phone animation:** use `keyframeAnimator` for a timed sequence: finger tap, shield slides up with Motion.smooth, puzzle solves, unlock bounce. Everything is on one timeline, not chained `DispatchQueue` delays.

## 4. Paywall
- Plans enter staggered, and the yearly plan has a soft coral glow pulse (2s loop) and a "BEST VALUE" badge that drops in with Motion.bouncy.
- Switching plans makes the selection ring slide between cards (`matchedGeometryEffect`), and the button text/price changes with numericText.
- The trial timeline icons appear one by one (stagger), connected by a line that draws itself (trim).
- The CTA has the Shimmer effect and PressableButtonStyle.
- Exit offer: the screen springs up from the bottom (Motion.gentle), then "25%" counts up with numericText and confetti lightly bursts once.

## 5. App-wide
- **Tab switch:** a cross-fade + the selected pill sliding between tabs (`matchedGeometryEffect`), plus a `.selection` haptic.
- **Toggles:** Motion.snappy + a light haptic.
- **Lists/cards on each tab:** staggered appear only the FIRST time the tab is shown per launch, not on every switch.
- **Scrolling:** cards use `.scrollTransition` with a slight scale (0.97) and opacity (0.8) at the edges.
- **Success moments** (puzzle solved, unlock, streak milestone): mascot bounce + confetti + `.success` haptic.
- **Errors** (wrong answer): horizontal shake (keyframes: 0, -10, 10, -6, 6, 0 over 0.35s) + an `.error` haptic.
- **Sheets:** use `.presentationCornerRadius(28)`, and the sheet content staggers in.
- **SF Symbols:** use `.symbolEffect(.bounce, value:)` when a state changes (lock, checkmark, flame), and `.contentTransition(.symbolEffect(.replace))` when an icon swaps.

## 6. Performance checklist
- Scale every image asset down to display size (no 1536px images rendered at 115pt). Use pre-sized asset variants or `preparingThumbnail`.
- No `GeometryReader` inside long lists. Animations must not trigger whole-screen re-layouts.
- Use `.drawingGroup()` on confetti/Canvas effects.
- Test on device in Release mode: onboarding and paywall must hold 60fps with no dropped frames when scrolling and transitioning.

## 7. Done when
- Every tap has a haptic + a visual response.
- No content appears without a spring/stagger.
- The onboarding progress bar and mascot never "jump".
- Reduce Motion is respected.
