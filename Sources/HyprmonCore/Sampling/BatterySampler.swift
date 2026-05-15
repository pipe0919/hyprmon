import Foundation
import IOKit
import IOKit.ps

public struct BatteryState: Sendable, Equatable {
    public var percent: Int
    public var isCharging: Bool
    public var isPresent: Bool
    public var timeToEmptyMinutes: Int?
}

public final class BatterySampler: @unchecked Sendable {
    public init() {}

    public func sample() -> BatteryState {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let src = list.first,
              let desc = IOPSGetPowerSourceDescription(blob, src)?.takeUnretainedValue() as? [String: Any]
        else {
            return BatteryState(percent: 0, isCharging: false, isPresent: false, timeToEmptyMinutes: nil)
        }
        let percent  = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 0
        let charging = desc[kIOPSIsChargingKey as String] as? Bool ?? false
        let toEmpty  = desc[kIOPSTimeToEmptyKey as String] as? Int
        let isPresent = (desc[kIOPSTypeKey as String] as? String) == kIOPSInternalBatteryType as String
        return BatteryState(
            percent: percent,
            isCharging: charging,
            isPresent: isPresent,
            timeToEmptyMinutes: (toEmpty.flatMap { $0 > 0 ? $0 : nil })
        )
    }
}
