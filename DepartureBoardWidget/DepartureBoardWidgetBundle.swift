//
//  DepartureBoardWidgetBundle.swift
//  DepartureBoardWidget
//
//  Created by Daniel Breslan on 16/02/2026.
//

import WidgetKit
import SwiftUI

@main
struct DepartureBoardWidgetBundle: WidgetBundle {
    var body: some Widget {
        SingleStationWidget()
        DualStationWidget()
    }
}
