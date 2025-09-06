//
//  RunnerWidget.swift
//  RunTogether
//
//  Created by Kenneth Alvarez on 9/6/25.
//

import WidgetKit
import SwiftUI

struct RunnerEntry: TimelineEntry {
    let date: Date
    let distance: Int
    let position: Int
    let pace: String
}

struct RunnerProvider: TimelineProvider {
    func placeholder(in context: Context) -> RunnerEntry {
        RunnerEntry(date: Date(), distance: 0, position: 0, pace: "0:00")
    }

    func getSnapshot(in context: Context, completion: @escaping (RunnerEntry) -> ()) {
        let entry = fetchCurrentData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RunnerEntry>) -> ()) {
        let entry = fetchCurrentData()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(5)))
        completion(timeline)
    }

    private func fetchCurrentData() -> RunnerEntry {
        let defaults = UserDefaults(suiteName: "group.com.kenneth.RunTogether")
        let widgetData = defaults?.dictionary(forKey: "CurrentRunnerData") ?? [:]
        
        let distance = widgetData["distance"] as? Int ?? 0
        let position = widgetData["position"] as? Int ?? 0
        let pace = widgetData["pace"] as? String ?? "0:00"
        
        return RunnerEntry(date: Date(), distance: distance, position: position, pace: pace)
    }
}

struct RunnerWidgetEntryView: View {
    var entry: RunnerProvider.Entry

    var body: some View {
        VStack(alignment: .leading) {
            Text("Distance: \(entry.distance)m")
            Text("Position: \(entry.position)")
            Text("Pace: \(entry.pace)")
        }
        .padding()
    }
}

struct RunnerWidget: Widget {
    let kind: String = "RunnerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RunnerProvider()) { entry in
            RunnerWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.accessoryRectangular, .accessoryInline]) // Lock screen supported
        .configurationDisplayName("RunTogether")
        .description("Shows your current run stats on the lock screen.")
    }
}
