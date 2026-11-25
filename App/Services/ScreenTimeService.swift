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

    /// Registers daily "schedule.start" / "schedule.end" activities whose boundaries make the monitor
    /// extension re-apply the shield. With no schedule (Always) they're removed.
    func registerSchedule(_ schedule: LockSchedule?) {
        if Self.isMock { return }
        let center = DeviceActivityCenter()
        center.stopMonitoring([DeviceActivityName("schedule.start"), DeviceActivityName("schedule.end")])
        guard let schedule else { return }
        for (name, minute) in [("schedule.start", schedule.startMinute), ("schedule.end", schedule.endMinute)] {
            let end = (minute + 15) % (24 * 60)
            let activity = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: minute / 60, minute: minute % 60),
                intervalEnd: DateComponents(hour: end / 60, minute: end % 60),
                repeats: true)
            do {
                try center.startMonitoring(DeviceActivityName(name), during: activity)
            } catch {
                print("Schedule monitoring failed: \(error)")
            }
        }
    }

    /// "Reset all data": removes every shield and stops all DeviceActivity monitoring (schedules and re-locks).
    func removeAllShieldsAndMonitoring() {
        ShieldController.clear()
        if Self.isMock { return }
        DeviceActivityCenter().stopMonitoring()
    }

    /// Wakes the monitor extension when the subscription ends, so the locks are lifted even if Lockie
    /// isn't opened ("schedule.*" activities make it re-evaluate the shield). nil cancels it.
    func scheduleSubscriptionEnd(_ end: Date?, now: Date = Date()) {
        if Self.isMock { return }
        let center = DeviceActivityCenter()
        let name = DeviceActivityName("schedule.subscriptionEnd")
        center.stopMonitoring([name])
        guard let end, end > now else { return }
        let start = max(now, end.addingTimeInterval(-20 * 60))
        let calendar = Calendar.current
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(parts, from: start),
            intervalEnd: calendar.dateComponents(parts, from: end.addingTimeInterval(60)),
            repeats: false)
        do {
            try center.startMonitoring(name, during: schedule)
        } catch {
            print("Subscription-end schedule failed: \(error)")
        }
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
