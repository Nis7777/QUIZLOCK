import DeviceActivity
import Foundation
import ManagedSettings

/// Re-locks an app when its unlock window ends.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let raw = activity.rawValue
        guard raw.hasPrefix("unlock.") else { return }
        let id = String(raw.dropFirst("unlock.".count))
        ShieldController.relock(unlockID: id)
    }
}
