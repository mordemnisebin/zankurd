import SwiftUI
import WidgetKit

// ZanKurd ana ekran widget'ı. Bütün görünür metin Dart'tan gelir
// (lib/src/services/home_widget_sync.dart): burada çeviri YOK.
// Renkler lib/src/theme/sahne.dart (night/day) belirteçleridir.

private let appGroupId = "group.com.zankurd.app"

struct ZanKurdEntry: TimelineEntry {
    let date: Date
    let hasData: Bool
    let streak: Int
    let dailyPrompt: String
    let labelStreak: String
    let labelUnit: String
    let labelDaily: String
}

struct ZanKurdProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZanKurdEntry {
        ZanKurdEntry(date: Date(), hasData: true, streak: 7, dailyPrompt: "ZanKurd",
                     labelStreak: "ZanKurd", labelUnit: "", labelDaily: "ZanKurd")
    }

    func getSnapshot(in context: Context, completion: @escaping (ZanKurdEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZanKurdEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [load()], policy: .after(next)))
    }

    private func load() -> ZanKurdEntry {
        let d = UserDefaults(suiteName: appGroupId)
        let hasData = d?.object(forKey: "updatedAt") != nil
        return ZanKurdEntry(
            date: Date(),
            hasData: hasData,
            streak: d?.integer(forKey: "streak") ?? 0,
            dailyPrompt: d?.string(forKey: "dailyPrompt") ?? "",
            labelStreak: d?.string(forKey: "labelStreak") ?? "",
            labelUnit: d?.string(forKey: "labelUnit") ?? "",
            labelDaily: d?.string(forKey: "labelDaily") ?? ""
        )
    }
}

private enum Brand {
    static func dyn(_ day: UInt32, _ night: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: night) : UIColor(hex: day) })
    }
    static let bg = dyn(0xF4F6FA, 0x121214)
    static let card = dyn(0xFFFFFF, 0x222328)
    static let text = dyn(0x0E1433, 0xF5F3EF)
    static let text2 = dyn(0x454E79, 0xD0D2D8)
    static let gold = dyn(0x8A5A00, 0xF5C24C)
    static let goldTint = dyn(0xFBF0D2, 0x362E1C)
    static let act = dyn(0xFF8A3D, 0xF08A4A)
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

private extension View {
    @ViewBuilder func widgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(Brand.bg, for: .widget)
        } else {
            self.background(Brand.bg)
        }
    }
}

struct StreakBadge: View {
    let entry: ZanKurdEntry
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill").foregroundColor(Brand.act).font(.system(size: 22, weight: .bold))
            VStack(alignment: .leading, spacing: 0) {
                Text("\(entry.streak)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(Brand.gold)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(entry.labelUnit.isEmpty ? entry.labelStreak : "\(entry.labelStreak) · \(entry.labelUnit)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Brand.text2).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }
}

struct DailyBlock: View {
    let entry: ZanKurdEntry
    let lines: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.labelDaily.uppercased())
                .font(.system(size: 10, weight: .heavy)).tracking(0.6)
                .foregroundColor(Brand.act).lineLimit(1)
            Text(entry.dailyPrompt)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Brand.text).lineLimit(lines).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ZanKurdWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: ZanKurdEntry

    var body: some View {
        Group {
            if !entry.hasData {
                VStack(spacing: 6) {
                    Image(systemName: "questionmark.bubble.fill").font(.system(size: 30)).foregroundColor(Brand.act)
                    Text("ZanKurd").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundColor(Brand.text)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if family == .systemMedium {
                HStack(spacing: 14) {
                    StreakBadge(entry: entry)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Brand.goldTint))
                    DailyBlock(entry: entry, lines: 4)
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    StreakBadge(entry: entry)
                    if !entry.dailyPrompt.isEmpty { DailyBlock(entry: entry, lines: 3) }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(entry.hasData ? 4 : 0)
        .widgetBackground()
    }
}

@main
struct ZanKurdWidget: Widget {
    let kind = "ZanKurdWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZanKurdProvider()) { entry in
            ZanKurdWidgetView(entry: entry)
        }
        .configurationDisplayName("ZanKurd")
        .description("ZanKurd")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
