//
//  ChatterLogView.swift
//  Debounce
//
//  Created by Timo Leisengang on 07.10.25.
//

import SwiftUI

struct ChatterLogView: View {
    @ObservedObject var blocker: ChatterBlocker

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Chatter Log")
                    .font(.headline)

                Spacer()

                if !blocker.chatterLog.isEmpty {
                    Button("Copy Log") {
                        copyLogToClipboard()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Clear") {
                    blocker.clearLog()
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            // Log entries
            if blocker.chatterLog.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("No chatter detected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(blocker.chatterLog) { event in
                    HStack {
                        // Timestamp
                        Text(formatTime(event.timestamp))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 70, alignment: .leading)

                        // Key name
                        Text(event.keyName)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 100, alignment: .leading)

                        // Delta time
                        Text("\(event.timeDelta)ms")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.red)

                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func copyLogToClipboard() {
        let lines = blocker.chatterLog.map { event in
            "\(formatTime(event.timestamp))\t\(event.keyName)\t\(event.timeDelta)ms"
        }
        let text = "Time\tKey\tDelta\n" + lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
