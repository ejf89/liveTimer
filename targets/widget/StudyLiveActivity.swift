import ActivityKit
import SwiftUI
import WidgetKit

// M1: minimal-but-real Live Activity so the target compiles and links.
// The lock-screen layout, Dynamic Island regions, and progress ring are
// fleshed out in later milestones.
@available(iOS 16.2, *)
struct StudyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyAttributes.self) { context in
            // Lock screen / banner presentation
            HStack {
                Text("📚")
                Text(context.attributes.sessionName)
                    .font(.headline)
                Spacer()
                Text(timerInterval: context.state.startAnchor...Date.distantFuture,
                     countsDown: false)
                    .monospacedDigit()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.sessionName)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startAnchor...Date.distantFuture,
                         countsDown: false)
                        .monospacedDigit()
                }
            } compactLeading: {
                Text("📚")
            } compactTrailing: {
                Text(timerInterval: context.state.startAnchor...Date.distantFuture,
                     countsDown: false)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Text("⏱")
            }
        }
    }
}
