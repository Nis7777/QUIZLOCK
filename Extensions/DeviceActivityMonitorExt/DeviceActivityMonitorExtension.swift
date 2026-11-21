import DeviceActivity
import Foundation
import ManagedSettings

/// Re-locks an app when its unlock window ends.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    /// Lock-schedule boundaries ("schedule.start" / "schedule.end") re-evaluate the shield.
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if activity.rawValue.hasPrefix("schedule.") {
            ShieldController.apply(SharedStore.lockState)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let raw = activity.rawValue
        if raw.hasPrefix("schedule.") {
            ShieldController.apply(SharedStore.lockState)
            return
        }
        guard raw.hasPrefix("unlock.") else { return }
        let id = String(raw.dropFirst("unlock.".count))
        ShieldController.relock(unlockID: id)
    }
}
