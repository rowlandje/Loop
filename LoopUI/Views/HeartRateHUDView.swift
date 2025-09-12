import SwiftUI
import HealthKit

struct HeartRateHUDView: View {
    @State private var heartRate: Double? = nil

    var body: some View {
        VStack {
            Text("❤️ Heart Rate")
                .font(.headline)

            if let hr = heartRate {
                Text("\(Int(hr)) bpm")
                    .font(.title)
                    .foregroundColor(.red)
            } else {
                Text("No data")
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            fetchHeartRate()
        }
    }

    private func fetchHeartRate() {
        let healthStore = HKHealthStore()
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: sort) { _, results, _ in
            if let result = results?.first as? HKQuantitySample {
                let bpm = result.quantity.doubleValue(for: HKUnit(from: "count/min"))
                DispatchQueue.main.async {
                    self.heartRate = bpm
                }
            }
        }
        healthStore.execute(query)
    }
}
