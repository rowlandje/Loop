import SwiftUI
import HealthKit

fileprivate struct HRPoint: Identifiable {
    let id = UUID()
    let t: Date
    let bpm: Int
}

fileprivate final class HRStore: ObservableObject {
    @Published var points: [HRPoint] = []
    @Published var latest: Int?

    private let hk = HKHealthStore()
    private var query: HKAnchoredObjectQuery?

    func start(hours: Int = 6) {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        hk.requestAuthorization(toShare: [], read: [type]) { [weak self] ok, _ in
            guard ok else { return }
            DispatchQueue.main.async { self?.begin(type: type, hours: hours) }
        }
    }

    private func begin(type: HKQuantityType, hours: Int) {
        let start = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date().addingTimeInterval(-Double(hours)*3600)
        let pred = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)

        query = HKAnchoredObjectQuery(type: type, predicate: pred, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, _, _ in
            self?.ingest(samples)
        }
        query?.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.ingest(samples)
        }
        if let q = query { hk.execute(q) }
    }

    private func ingest(_ samples: [HKSample]?) {
        guard let qs = samples as? [HKQuantitySample], !qs.isEmpty else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())

        var all = points
        for s in qs {
            all.append(HRPoint(t: s.endDate, bpm: Int(round(s.quantity.doubleValue(for: unit)))))
        }
        all.sort { $0.t < $1.t }
        let last = all.last?.bpm

        DispatchQueue.main.async {
            self.points = all
            self.latest = last
        }
    }
}

public struct HeartRateChartView: View {
    @StateObject private var hr = HRStore()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Heart Rate", systemImage: "heart.fill").font(.headline)
                Spacer()
                if let bpm = hr.latest {
                    Text("\(bpm) bpm").foregroundStyle(.secondary)
                }
            }

            // Gebruik Apple Charts als beschikbaar (iOS 16+); anders fallback met lijn via Path
            if #available(iOS 16.0, *) {
                import Charts
                Chart(hr.points) { p in
                    LineMark(x: .value("Time", p.t), y: .value("BPM", p.bpm))
                    PointMark(x: .value("Time", p.t), y: .value("BPM", p.bpm)).symbolSize(8)
                }
                .chartYScale(domain: 40...180)
                .frame(height: 160)
            } else {
                // eenvoudige fallback
                HRBasicLine(points: hr.points).frame(height: 160)
            }
        }
        .padding(.vertical, 8)
        .onAppear { hr.start() }
    }
}

// Fallback eenvoudige lijn (geen Charts nodig)
fileprivate struct HRBasicLine: View {
    let points: [HRPoint]
    var body: some View {
        GeometryReader { geo in
            if points.count >= 2 {
                let xs = points.map(\.t.timeIntervalSince1970)
                let ys = points.map(\.bpm)
                let minX = xs.min()!, maxX = xs.max()!
                let minY = 40.0, maxY = 180.0

                Path { path in
                    func px(_ i: Int) -> CGFloat {
                        let t = (xs[i]-minX)/max(1, maxX-minX)
                        return CGFloat(t)*geo.size.width
                    }
                    func py(_ i: Int) -> CGFloat {
                        let n = (Double(ys[i])-minY)/(maxY-minY)
                        return geo.size.height*(1-CGFloat(n))
                    }
                    path.move(to: CGPoint(x: px(0), y: py(0)))
                    for i in 1..<points.count { path.addLine(to: CGPoint(x: px(i), y: py(i))) }
                }
                .stroke(Color.primary, lineWidth: 1.5)
            } else {
                Text("No recent heart rate").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
