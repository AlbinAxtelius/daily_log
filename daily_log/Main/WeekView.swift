//
//  WeekView.swift
//  daily_log
//
//  The primary surface: you report weekly, looking back. Read-only —
//  drill into a day to edit.
//

import SwiftUI

struct WeekView: View {
    @Environment(Store.self) private var store
    @Environment(Navigation.self) private var navigation

    let anchor: Date

    private static let dayColumn: CGFloat = 116
    private static let barColumn: CGFloat = 96
    private static let valueColumn: CGFloat = 72
    private static let totalColumn: CGFloat = 80

    var body: some View {
        let grid = store.weekGrid(containing: anchor)
        let days = visibleDays(grid)
        let dayTotals = Dictionary(uniqueKeysWithValues: days.map { ($0, total(of: grid.hours[$0])) })
        let peak = max(dayTotals.values.max() ?? 0, 1)

        VStack(alignment: .leading, spacing: 0) {
            header(weekTotal: dayTotals.values.reduce(0, +))

            if grid.keys.isEmpty {
                EmptyPane(
                    symbol: "calendar",
                    title: "Nothing logged this week.",
                    message: "Hit \(HotKeyDisplay.string(keyCode: store.settings.hotKeyCode, modifiers: store.settings.hotKeyModifiers)) to jot something down."
                )
            } else {
                ScrollView([.horizontal, .vertical]) {
                    VStack(spacing: 0) {
                        columnHeader(grid.keys)
                        Divider().opacity(0.6)

                        ForEach(days, id: \.self) { day in
                            dayRow(
                                day,
                                keys: grid.keys,
                                row: grid.hours[day] ?? [:],
                                total: dayTotals[day] ?? 0,
                                peak: peak
                            )
                        }

                        Divider()
                        totalsRow(days: days, keys: grid.keys, hours: grid.hours)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .card()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                caveat
            }
        }
    }

    // MARK: - Chrome

    private func header(weekTotal: Double) -> some View {
        PageHeader(title: "Week \(store.weekNumber(of: anchor))", subtitle: subtitle(weekTotal)) {
            HStack(spacing: 6) {
                Button { navigation.route = .week(store.shiftWeek(anchor, by: -1)) } label: {
                    Image(systemName: "chevron.left")
                }
                .help("Previous week")

                Button("Today") { navigation.route = .week(store.today) }
                    .disabled(store.week(containing: anchor).contains(store.today))

                Button { navigation.route = .week(store.shiftWeek(anchor, by: 1)) } label: {
                    Image(systemName: "chevron.right")
                }
                .help("Next week")
            }
            .controlSize(.small)
        }
    }

    private func subtitle(_ weekTotal: Double) -> String {
        let days = store.week(containing: anchor)
        guard let first = days.first, let last = days.last else { return "" }
        let range = "\(Fmt.dayCompact.string(from: first)) – \(Fmt.dayCompact.string(from: last))"
        return weekTotal > 0 ? "\(range) · \(Fmt.approxHours(weekTotal))" : range
    }

    private var caveat: some View {
        Text("Totals are hints. Entries are capped at \(store.settings.capMinutes)m and gaps are never filled in, so a full week reads low.")
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
    }

    // MARK: - Grid

    private func columnHeader(_ keys: [String]) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Self.dayColumn + Self.barColumn, height: 1)

            ForEach(keys, id: \.self) { key in
                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    ProjectDot(key: key, size: 6)
                    Text(store.displayName(key))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(width: Self.valueColumn, alignment: .trailing)
                .help(store.displayName(key))
            }

            Text("Total")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: Self.totalColumn, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func dayRow(_ day: Date, keys: [String], row: [String: Double], total: Double, peak: Double) -> some View {
        let isToday = day == store.today

        return Button {
            navigation.route = .day(day)
        } label: {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(Fmt.weekdayShort.string(from: day))
                        .font(.system(size: 12, weight: isToday ? .semibold : .medium))
                        .foregroundStyle(isToday ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary))
                    Text(Fmt.dayCompact.string(from: day))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .frame(width: Self.dayColumn, alignment: .leading)

                StackedBar(segments: keys.compactMap { key in
                    row[key].map { (key: key, hours: $0) }
                }, scale: peak)
                .frame(width: Self.barColumn - 16)
                .padding(.trailing, 16)

                ForEach(keys, id: \.self) { key in
                    Text(row[key].map { Fmt.hours($0) } ?? "·")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(row[key] == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                        .frame(width: Self.valueColumn, alignment: .trailing)
                }

                Text(total > 0 ? Fmt.hours(total) : "·")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(total > 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                    .frame(width: Self.totalColumn, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowRadius, style: .continuous)
                .fill(Color.accentColor.opacity(isToday ? 0.08 : 0))
        )
        .hoverHighlight()
        .help("Open \(Fmt.dayFull.string(from: day))")
    }

    private func totalsRow(days: [Date], keys: [String], hours: [Date: [String: Double]]) -> some View {
        HStack(spacing: 0) {
            Text("Total")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: Self.dayColumn + Self.barColumn, alignment: .leading)

            ForEach(keys, id: \.self) { key in
                let sum = days.reduce(0.0) { $0 + (hours[$1]?[key] ?? 0) }
                Text(Fmt.hours(sum))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .frame(width: Self.valueColumn, alignment: .trailing)
            }

            let grand = days.reduce(0.0) { $0 + total(of: hours[$1]) }
            Text(Fmt.hours(grand))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(width: Self.totalColumn, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    // MARK: - Helpers

    /// Non-working days only earn a row once something lands on them.
    private func visibleDays(_ grid: (days: [Date], keys: [String], hours: [Date: [String: Double]])) -> [Date] {
        grid.days.filter { day in
            let weekday = Calendar.current.component(.weekday, from: day)
            return store.settings.workDays.contains(weekday) || !(grid.hours[day]?.isEmpty ?? true)
        }
    }

    private func total(of row: [String: Double]?) -> Double {
        row?.values.reduce(0, +) ?? 0
    }
}
