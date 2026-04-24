import WidgetKit
import SwiftUI

@main
struct SignalVoidWidgetBundle: WidgetBundle {
    var body: some Widget {
        ProgressWidget()
        LeaderboardWidget()
        PlanetPassWidget()
    }
}
