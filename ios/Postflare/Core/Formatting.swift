import Foundation
import SwiftUI

/// Number and date formatting.
enum Fmt {
    /// 950, 1.2K, 3.4M.
    static func compact(_ value: Double) -> String {
        if abs(value) < 1000 { return value.formatted(.number.precision(.fractionLength(0))) }
        return value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }

    static func count(_ value: Int) -> String { value.formatted(.number) }

    /// 0.0423 → "4.2%".
    static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0...1)))
    }

    /// "+12%" / "−3%" for a ratio change (0.12).
    static func change(_ change: Double) -> String {
        let pct = change * 100
        let text = abs(pct) >= 10 ? String(format: "%.0f%%", abs(pct)) : String(format: "%.1f%%", abs(pct))
        return (change >= 0 ? "+" : "−") + text
    }

    /// +12, −3 (true minus sign), compact.
    static func signed(_ value: Double) -> String {
        (value > 0 ? "+" : value < 0 ? "−" : "") + compact(abs(value))
    }

    static func date(ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }

    /// "Today 14:30", "Tomorrow 09:00", "Mon 20 Oct, 18:00", with the year when it is not this year.
    static func when(_ date: Date, now: Date = .now) -> String {
        let cal = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(date) { return String(localized: "Today \(time)") }
        if cal.isDateInTomorrow(date) { return String(localized: "Tomorrow \(time)") }
        if cal.isDateInYesterday(date) { return String(localized: "Yesterday \(time)") }
        var style = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated).hour().minute()
        if !cal.isDate(date, equalTo: now, toGranularity: .year) { style = style.year() }
        return date.formatted(style)
    }

    /// Section title of a day: "Today", "Tomorrow", "Monday, 20 October".
    static func day(_ date: Date, now: Date = .now) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return String(localized: "Today") }
        if cal.isDateInTomorrow(date) { return String(localized: "Tomorrow") }
        if cal.isDateInYesterday(date) { return String(localized: "Yesterday") }
        var style = Date.FormatStyle().weekday(.wide).day().month(.wide)
        if !cal.isDate(date, equalTo: now, toGranularity: .year) { style = style.year() }
        return date.formatted(style)
    }

    static func relative(ms: Double) -> String {
        date(ms: ms).formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }

    /// Video length: "0:42", "12:05", "1:02:33".
    static func duration(_ seconds: Double) -> String {
        let t = Int(seconds.rounded())
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    static func bytes(_ n: Double) -> String {
        Int64(n).formatted(.byteCount(style: .file))
    }

    private static let dayParser: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// "2026-10-16" (a day in the device's time zone, analytics `daily`) → its start.
    static func day(_ s: String) -> Date? { dayParser.date(from: String(s.prefix(10))) }
}

extension Color {
    static let brand = Color("AccentColor")
    static let positive = Color.green
    static let negative = Color.red
}

/// Change pill colour: green when the metric moved the good way.
func changeColor(_ change: Double?) -> Color {
    guard let change, abs(change) >= 0.0005 else { return .secondary }
    return change > 0 ? .positive : .negative
}

/// Relative change of `current` against `previous` (nil when there is nothing to compare with).
func relativeChange(_ current: Double?, _ previous: Double?) -> Double? {
    guard let current, let previous, previous != 0 else { return nil }
    return (current - previous) / abs(previous)
}

// MARK: - Post status

extension PostStatus {
    var title: String {
        switch self {
        case .draft: String(localized: "Draft")
        case .scheduled: String(localized: "Scheduled")
        case .publishing: String(localized: "Publishing")
        case .published: String(localized: "Published")
        case .failed: String(localized: "Failed")
        case .cancelled: String(localized: "Cancelled")
        case .needsCheck: String(localized: "Needs check")
        }
    }

    var color: Color {
        switch self {
        case .draft: .gray
        case .scheduled: .blue
        case .publishing: .purple
        case .published: .green
        case .failed: .red
        case .cancelled: .orange
        case .needsCheck: .yellow
        }
    }

    var symbol: String {
        switch self {
        case .draft: "doc.text"
        case .scheduled: "clock"
        case .publishing: "arrow.up.circle"
        case .published: "checkmark.circle.fill"
        case .failed: "exclamationmark.circle.fill"
        case .cancelled: "slash.circle"
        case .needsCheck: "questionmark.circle.fill"
        }
    }
}

// MARK: - Platforms

/// Names, colours and letter glyphs of the platforms, for places without the `/providers` catalog (widgets) and as
/// fallback. Simple letters on the brand colour, no logos.
enum Platform {
    private static let known: [String: (name: String, color: String, glyph: String)] = [
        "x": ("X", "000000", "X"),
        "bluesky": ("Bluesky", "0085FF", "Bs"),
        "threads": ("Threads", "000000", "Th"),
        "mastodon": ("Mastodon", "6364FF", "M"),
        "instagram": ("Instagram", "E4405F", "Ig"),
        "instagram_standalone": ("Instagram", "E4405F", "Ig"),
        "facebook": ("Facebook", "0866FF", "f"),
        "tiktok": ("TikTok", "000000", "Tk"),
        "tiktok_business": ("TikTok", "000000", "Tk"),
        "youtube": ("YouTube", "FF0000", "Yt"),
        "linkedin": ("LinkedIn", "0A66C2", "in"),
        "linkedin_page": ("LinkedIn Page", "0A66C2", "in"),
        "pinterest": ("Pinterest", "BD081C", "P"),
        "reddit": ("Reddit", "FF4500", "r"),
        "telegram": ("Telegram", "26A5E4", "Tg"),
        "discord": ("Discord", "5865F2", "D"),
        "slack": ("Slack", "4A154B", "S"),
        "tumblr": ("Tumblr", "36465D", "t"),
        "medium": ("Medium", "000000", "M"),
        "devto": ("DEV", "0A0A0A", "dev"),
        "hashnode": ("Hashnode", "2962FF", "H"),
        "wordpress": ("WordPress", "21759B", "W"),
        "lemmy": ("Lemmy", "00BC8C", "L"),
        "nostr": ("Nostr", "8E44AD", "N"),
        "farcaster": ("Farcaster", "855DCD", "Fc"),
        "twitch": ("Twitch", "9146FF", "Tw"),
        "kick": ("Kick", "53FC18", "K"),
        "vk": ("VK", "0077FF", "VK"),
        "gmb": ("Google Business", "4285F4", "G"),
        "dribbble": ("Dribbble", "EA4C89", "Dr"),
        "listmonk": ("Listmonk", "0055D4", "Lm"),
        "webhook": ("Webhook", "6B7280", "Wh"),
    ]

    static func name(_ id: String) -> String { known[id]?.name ?? id.capitalized }

    static func glyph(_ id: String) -> String {
        known[id]?.glyph ?? String(name(id).prefix(1)).uppercased()
    }

    static func color(_ id: String, hex: String? = nil) -> Color {
        Color(hex: hex ?? known[id]?.color ?? "6B7280")
    }
}

extension Color {
    /// "FF500A" (no '#').
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let v = UInt64(s, radix: 16) ?? 0x6B7280
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    /// Account group palette keys (shared/accountGroups.ts).
    static func group(_ key: String) -> Color {
        switch key {
        case "red": .red
        case "orange": .orange
        case "amber": .yellow
        case "green": .green
        case "teal": .teal
        case "sky": .cyan
        case "indigo": .indigo
        case "violet": .purple
        case "pink": .pink
        default: .gray
        }
    }
}
