import Charts
import SwiftUI

/// KPIs with the change against the previous period, a daily chart, platforms and top posts
/// (`GET /analytics/summary`, `GET /analytics/posts`).
struct AnalyticsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var range: Range = .days30
    @State private var metric: Metric = .views
    @State private var summary = Loader<AnalyticsSummary>()
    @State private var top = Loader<[AnalyticsPost]>()
    @State private var selectedDay: Date?

    enum Range: Int, CaseIterable, Identifiable {
        case days7 = 7, days30 = 30, days90 = 90
        var id: Int { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .days7: "7 days"
            case .days30: "30 days"
            case .days90: "90 days"
            }
        }
    }

    enum Metric: String, CaseIterable, Identifiable {
        case views, engagements, posts
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .views: "Views"
            case .engagements: "Engagements"
            case .posts: "Posts"
            }
        }
        func value(_ d: AnalyticsDay) -> Double {
            switch self {
            case .views: d.views
            case .engagements: d.engagements
            case .posts: d.posts
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                if let error = summary.error { ErrorBanner(message: error) { Task { await load() } } }

                if let s = summary.value {
                    kpis(s)
                    chartCard(s)
                    if !s.byProvider.isEmpty { platforms(s) }
                    topPosts
                    UpdatedLabel(date: summary.updatedAt, offline: summary.offline)
                } else if summary.loading {
                    ProgressView().controlSize(.large).padding(.top, 80)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Analytics")
        .toolbarTitleDisplayMode(.inlineLarge)
        .refreshable { await load() }
        .task(id: TaskKey(range: range, version: model.dataVersion)) { await load() }
    }

    private struct TaskKey: Hashable { var range: Range; var version: Int }

    private var interval: (Date, Date) {
        let to = Date.now
        let from = Calendar.current.date(byAdding: .day, value: -range.rawValue, to: Calendar.current.startOfDay(for: to).addingTimeInterval(86400)) ?? to
        return (from, to)
    }

    private func load() async {
        guard let client = model.client else { return }
        let (from, to) = interval
        summary.use(cacheKey: ResponseCache.key("analytics", String(range.rawValue)))
        top.use(cacheKey: ResponseCache.key("top", String(range.rawValue)))
        async let a: Void = summary.load { try await client.analyticsSummary(from: from, to: to) }
        async let b: Void = top.load { try await client.topPosts(from: from, to: to) }
        _ = await (a, b)
    }

    // MARK: KPIs

    private func kpis(_ s: AnalyticsSummary) -> some View {
        let t = s.totals, p = s.previous
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 2)
        return LazyVGrid(columns: columns, spacing: 10) {
            KPITile(title: "Views", value: Fmt.compact(t.views), change: relativeChange(t.views, p.views), systemImage: "eye")
            KPITile(title: "Engagements", value: Fmt.compact(t.engagements), change: relativeChange(t.engagements, p.engagements), systemImage: "hand.thumbsup")
            KPITile(title: "Engagement rate", value: t.engagementRate.map(Fmt.percent) ?? "—", change: relativeChange(t.engagementRate, p.engagementRate), systemImage: "percent")
            KPITile(title: "Posts published", value: Fmt.compact(t.posts), change: relativeChange(t.posts, p.posts), systemImage: "paperplane")
            if let followers = t.followers {
                KPITile(title: "Followers", value: Fmt.compact(followers), change: nil, systemImage: "person.2",
                        detail: t.followersChange.map { String(localized: "\(Fmt.signed($0)) in this period") })
            }
            if let clicks = t.clicks, (t.campaignPosts ?? 0) > 0 {
                KPITile(title: "Link clicks", value: Fmt.compact(clicks), change: relativeChange(clicks, p.clicks), systemImage: "cursorarrow.click")
            }
        }
    }

    // MARK: Chart

    private func chartCard(_ s: AnalyticsSummary) -> some View {
        let days = s.daily.compactMap { d in Fmt.day(d.day).map { (date: $0, value: metric.value(d)) } }
        let selected = selectedDay.flatMap { sel in days.first { Calendar.current.isDate($0.date, inSameDayAs: sel) } }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Per day").font(.headline)
                Spacer()
                Picker("Metric", selection: $metric) {
                    ForEach(Metric.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
            }
            if days.isEmpty || days.allSatisfy({ $0.value == 0 }) {
                Text("No published posts with numbers in this period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    ForEach(days, id: \.date) { d in
                        BarMark(x: .value("Day", d.date, unit: .day), y: .value("Value", d.value), width: .ratio(0.7))
                            .foregroundStyle(Color.chart.opacity(selected == nil || selected?.date == d.date ? 1 : 0.35))
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
                    }
                    if let selected {
                        RuleMark(x: .value("Day", selected.date, unit: .day))
                            .foregroundStyle(.secondary.opacity(0.4))
                            .zIndex(-1)
                            .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                VStack(spacing: 2) {
                                    Text(selected.date.formatted(.dateTime.day().month(.abbreviated))).font(.caption2).foregroundStyle(.secondary)
                                    Text(Fmt.compact(selected.value)).font(.caption.weight(.bold)).monospacedDigit()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                    }
                }
                .chartXSelection(value: $selectedDay)
                .chartYAxis {
                    AxisMarks(position: .leading) { v in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                        AxisValueLabel { if let n = v.as(Double.self) { Text(Fmt.compact(n)) } }
                    }
                }
                .chartXAxis {
                    // About four labels, none at the very end (they would be cut off at the edge).
                    let step = max(1, days.count / 4)
                    let ticks = days.enumerated().filter { $0.offset % step == 0 && $0.offset <= days.count - 1 - step / 2 }.map(\.element.date)
                    AxisMarks(values: ticks) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 190)
                .accessibilityLabel(Text("\(Text(metric.title)) per day"))
                Text("Numbers count for the day a post was published.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    // MARK: Platforms and top posts

    private func platforms(_ s: AnalyticsSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "By platform", systemImage: "square.grid.2x2")
            VStack(spacing: 0) {
                ForEach(Array(s.byProvider.sorted { $0.views > $1.views }.enumerated()), id: \.element.id) { i, b in
                    HStack(spacing: 12) {
                        PlatformGlyph(provider: b.provider, size: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(b.name).font(.subheadline.weight(.medium))
                            Text("\(Fmt.compact(b.posts)) posts").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(Fmt.compact(b.views)) views").font(.subheadline).monospacedDigit()
                            if let r = b.engagementRate { Text("\(Fmt.percent(r)) engagement").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    if i < s.byProvider.count - 1 { Divider().padding(.leading, 58) }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var topPosts: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Top posts", systemImage: "trophy")
            VStack(spacing: 0) {
                let posts = top.value ?? []
                if posts.isEmpty {
                    Text(top.loading ? "Loading…" : "No published posts in this period.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                ForEach(Array(posts.enumerated()), id: \.element.id) { i, p in
                    NavigationLink(value: Route.post(id: p.id)) {
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                                .monospacedDigit()
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    PlatformGlyph(provider: p.provider, size: 16)
                                    Text(p.accountName).font(.caption.weight(.semibold)).lineLimit(1)
                                    Spacer()
                                    Text(Fmt.date(ms: p.publishedAt).formatted(.dateTime.day().month(.abbreviated))).font(.caption).foregroundStyle(.secondary)
                                }
                                Text(p.excerpt.isEmpty ? String(localized: "No text") : p.excerpt).font(.subheadline).lineLimit(2)
                                HStack(spacing: 12) {
                                    Label(Fmt.compact(p.metrics?.exposure ?? 0), systemImage: "eye")
                                    Label(Fmt.compact(p.engagements), systemImage: "hand.thumbsup")
                                    if let r = p.engagementRate { Label(Fmt.percent(r), systemImage: "percent") }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .labelStyle(CompactLabelStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if i < posts.count - 1 { Divider().padding(.leading, 48) }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

struct KPITile: View {
    var title: LocalizedStringKey
    var value: String
    var change: Double?
    var systemImage: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let change {
                HStack(spacing: 4) {
                    ChangePill(change: change)
                    Text("vs previous").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            } else if let detail {
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            } else {
                Text(" ").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

extension Color {
    /// Chart marks: the brand orange, a step darker in dark mode (validated against both surfaces).
    static let chart = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.949, green: 0.298, blue: 0.039, alpha: 1) : UIColor(red: 1, green: 0.314, blue: 0.039, alpha: 1) })
}
