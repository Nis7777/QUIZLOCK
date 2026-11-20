import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Wraps every Screen Time call. In the Simulator (where FamilyControls doesn't work)
/// it runs with mocked state so every screen can be clicked through.
@MainActor
final class ScreenTimeService {
    #if targetEnvironment(simulator)
    static let isMock = true
    #else
    static let isMock = false
    #endif

    enum AuthError: LocalizedError {
        case denied
        var errorDescription: String? { "Screen Time access wasn't granted." }
    }

    /// Current authorization (the mock uses a stored flag).
    func isAuthorized(simulatorFlag: Bool) -> Bool {
        if Self.isMock { return simulatorFlag }
        return AuthorizationCenter.shared.authorizationStatus == .approved
    }

    func requestAuthorization() async throws {
        if Self.isMock {
            try await Task.sleep(nanoseconds: 700_000_000)
            return
        }
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        guard AuthorizationCenter.shared.authorizationStatus == .approved else { throw AuthError.denied }
    }

    func apply(_ state: LockState) {
        ShieldController.apply(state)
    }

    /// Schedules the re-lock. DeviceActivity needs schedules of at least 15 minutes, so for
    /// shorter unlocks the interval starts in the past: start = end − 15 min.
    func scheduleRelock(_ unlock: ActiveUnlock, now: Date = Date()) {
        if Self.isMock { return }
        let minimum: TimeInterval = 15 * 60
        let end = unlock.expiresAt
        let start = end.timeIntervalSince(now) < minimum ? end.addingTimeInterval(-minimum) : now
        let calendar = Calendar.current
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(parts, from: start),
            intervalEnd: calendar.dateComponents(parts, from: end),
            repeats: false)
        do {
            try DeviceActivityCenter().startMonitoring(DeviceActivityName(unlock.activityName), during: schedule)
        } catch {
            // The app's launch/foreground sweep re-locks expired unlocks as a safety net.
            print("DeviceActivity schedule failed: \(error)")
        }
    }
}
