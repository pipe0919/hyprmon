import Foundation
import Observation

@MainActor
@Observable
public final class SystemSampler {
    public private(set) var cpu: Double = 0
    public private(set) var ram: Double = 0
    public private(set) var battery: BatteryState = .init(percent: 0, isCharging: false, isPresent: false, timeToEmptyMinutes: nil)
    public private(set) var topProcs: [ProcessSampler.Aggregate] = []

    private let cpuS = CPUSampler()
    private let memS = MemorySampler()
    private let batS = BatterySampler()
    private let procS = ProcessSampler()
    private var timer: Timer?
    private var intervalMs: Int = 1000
    private var procCount: Int = 5

    public init() {}

    public func start(intervalMs: Int, processCount: Int) {
        self.intervalMs = intervalMs
        self.procCount = processCount
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Double(intervalMs) / 1000.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
        tick()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        if let v = cpuS.sample() { cpu = v }
        if let v = memS.sample() { ram = v.usedFraction }
        battery = batS.sample()
        topProcs = procS.sample(count: procCount)
    }
}
