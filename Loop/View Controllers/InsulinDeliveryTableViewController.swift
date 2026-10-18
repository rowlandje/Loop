//
//  InsulinDeliveryTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/30/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import CoreData
import LoopCore
import LoopKit
import LoopKitUI

private let ReuseIdentifier = "Right Detail"


public final class InsulinDeliveryTableViewController: UITableViewController {
    
    private static let historicDataDisplayTimeInterval = TimeInterval.hours(24)

    private static let dailyTotalDays = 7

    private var dailyTotals: [(date: Date, units: Double?)] = []
    private var isLoadingDailyTotals = false
   
    private lazy var dailyInsulinStore = DailyInsulinStore()

    private lazy var dailyTotalDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
    return formatter
}()

private lazy var dailyTotalNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 1
    return formatter
}()

    @IBOutlet var needsConfigurationMessageView: ErrorBackgroundView!

    @IBOutlet weak var iobValueLabel: UILabel! {
        didSet {
            iobValueLabel.textColor = headerValueLabelColor
        }
    }

    @IBOutlet weak var iobDateLabel: UILabel!

    @IBOutlet weak var totalValueLabel: UILabel! {
        didSet {
            totalValueLabel.textColor = headerValueLabelColor
        }
    }

    @IBOutlet weak var totalDateLabel: UILabel!

    @IBOutlet weak var dataSourceSegmentedControl: UISegmentedControl! {
        didSet {
            let titleFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
            dataSourceSegmentedControl.setTitleTextAttributes([NSAttributedString.Key.font: titleFont], for: .normal)
            dataSourceSegmentedControl.setTitle(NSLocalizedString("Event History", comment: "Segmented button title for insulin delivery log event history"), forSegmentAt: 0)
            dataSourceSegmentedControl.setTitle(NSLocalizedString("Reservoir", comment: "Segmented button title for insulin delivery log reservoir history"), forSegmentAt: 1)
        }
    }
    
    public var enableEntryDeletion: Bool = true
    
    var deviceManager: DeviceDataManager? {
        didSet {
            doseStore = deviceManager?.doseStore
        }
    }

    public var doseStore: DoseStore? {
        didSet {
            if let doseStore = doseStore {
                doseStoreObserver = NotificationCenter.default.addObserver(forName: nil, object: doseStore, queue: OperationQueue.main, using: { [weak self] (note) -> Void in

                    switch note.name {
                    case DoseStore.valuesDidChange:
                        if self?.isViewLoaded == true {
                            self?.reloadData()
                        }
                    default:
                        break
                    }
                })
            } else {
                doseStoreObserver = nil
            }
        }
    }
