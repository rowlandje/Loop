import UIKit
import HealthKit
import LoopKitUI

// Een eenvoudige HUD die laatste hartslag (bpm) toont.
final class HeartRateHUDView: BaseHUDView {

    // MARK: - UI

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "❤️ Heart Rate"
        l.font = UIFont.preferredFont(forTextStyle: .caption1)
        l.textAlignment = .center
        l.setContentHuggingPriority(.required, for: .vertical)
        return l
    }()

    private let valueLabel: UILabel = {
        let l = UILabel()
        l.text = "–"
        l.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        l.textAlignment = .center
        l.adjustsFontForContentSizeCategory = true
        return l
    }()

    private let unitLabel: UILabel = {
        let l = UILabel()
        l.text = "bpm"
        l.font = UIFont.preferredFont(forTextStyle: .footnote)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        return l
    }()

    private let vStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.alignment = .fill
        s.distribution = .fill
        s.spacing = 2
        return s
    }()

    // MARK: - HealthKit

    private let healthStore = HKHealthStore()
    private var query: HKAnchoredObjectQuery?

    // Toon max 6 uur terug (alleen voor filtering)
    private let lookbackHours: Int = 6

    // MARK: - BaseHUDView

    // Hoe eerder in de rij hoe “belangrijker”. Lager getal = links/boven.
    // Als jouw Build een andere enum gebruikt, kun je dit gerust weghalen.
    override var orderPriority: HUDViewPriority {
        // plaats 'm na glucose/basal; kies een relatief lage prioriteit
        return .low
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        startHeartRate()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        startHeartRate()
    }

    private func setupUI() {
        isAccessibilityElement = true
        accessibilityLabel = "Heart Rate"

        vStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(vStack)

        vStack.addArrangedSubview(titleLabel)
        vStack.addArrangedSubview(valueLabel)
        vStack.addArrangedSubview(unitLabel)

        NSLayoutConstraint.activate([
            vStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            vStack.topAnchor.constraint(equalTo: topAnchor),
            vStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - HealthKit

    private func startHeartRate() {
        guard HKHealthStore.isHealthDataAvailable(),
              let hrType = HKObjectType.quantityType(forIdentifier: .heartRate)
        else { return }

        healthStore.requestAuthorization(toShare: [], read: [hrType]) { [weak self] ok, _ in
            guard ok, let self else { return }
            DispatchQueue.main.async { self.beginQuery(type: hrType) }
        }
    }

    private func beginQuery(type: HKQuantityType) {
        let start = Calendar.current.date(byAdding: .hour, value: -lookbackHours, to: Date())
                   ?? Date().addingTimeInterval(-6*3600)

        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)

        // Eérste fetch
        query = HKAnchoredObjectQuery(type: type,
                                      predicate: predicate,
                                      anchor: nil,
                                      limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, _, _ in
            self?.consume(samples)
        }

        // Live updates
        query?.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.consume(samples)
        }

        if let q = query { healthStore.execute(q) }
    }

    private func consume(_ samples: [HKSample]?) {
        guard let qty = samples as? [HKQuantitySample], !qty.isEmpty else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        // Neem de laatste meting
        if let last = qty.sorted(by: { $0.endDate < $1.endDate }).last {
            let bpm = Int(round(last.quantity.doubleValue(for: unit)))
            DispatchQueue.main.async { [weak self] in
                self?.updateValue(bpm)
            }
        }
    }

    private func updateValue(_ bpm: Int) {
        valueLabel.text = "\(bpm)"
        accessibilityValue = "\(bpm) bpm"
    }
}
