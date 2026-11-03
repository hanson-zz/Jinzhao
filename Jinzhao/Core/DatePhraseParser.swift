import Foundation

/// 中文日期口语解析（任务输入框用）：
/// 日期词：今天 / 明天 / 后天 / 大后天、周几 / 星期几 / 礼拜几、下周几
/// 时间词：上午/下午/晚上等 + 数字或中文数字「点」+ 可选「半 / X分」，或 15:30
/// 返回抠掉日期时间词后的标题，和解析出的截止时间（一个都没命中时 due 为 nil）。
enum DatePhraseParser {
    struct Result {
        let title: String
        let due: Date?
    }

    static func parse(_ raw: String, now: Date = Date()) -> Result {
        let cal = Calendar(identifier: .gregorian)
        var cuts: [Range<String.Index>] = []
        var day: Date? = nil
        var hour: Int? = nil
        var minute = 0

        // 1) 星期（「下周几」单独判定）
        if let m = matchWeekday(in: raw) {
            cuts.append(m.range)
            let todayW = cal.component(.weekday, from: now)
            let delta: Int
            if m.nextWeek {
                // 到下周的周几：先到下周日，再加周内偏移（周日 = 0）
                delta = ((8 - todayW) % 7) + (m.weekday - 1)
            } else {
                delta = (m.weekday - todayW + 7) % 7
            }
            day = cal.date(byAdding: .day, value: delta, to: cal.startOfDay(for: now))
        }

        // 2) 日偏移词（长词先匹配，避免「大后天」被「后天」截胡）
        if day == nil {
            for (word, off) in [("大后天", 3), ("后天", 2), ("明天", 1), ("今天", 0)] {
                if let r = raw.range(of: word) {
                    cuts.append(r)
                    day = cal.date(byAdding: .day, value: off, to: cal.startOfDay(for: now))
                    break
                }
            }
        }

        // 3) 时间
        if let t = matchTime(in: raw) {
            cuts.append(t.range)
            hour = t.hour
            minute = t.minute
        }

        var due: Date? = nil
        if day != nil || hour != nil {
            let base = day ?? cal.startOfDay(for: now)
            var c = cal.dateComponents([.year, .month, .day], from: base)
            c.hour = hour ?? 9 // 只给日期没给时间，默认早上 9 点
            c.minute = hour == nil ? 0 : minute
            var candidate = cal.date(from: c)
            if day == nil, let cd = candidate, cd < now {
                // 只给了时间且今天这个点已过，顺延到明天
                candidate = cal.date(byAdding: .day, value: 1, to: cd)
            }
            due = candidate
        }

        // 抠词：从后往前删，避免索引失效；抠完只剩空就保留原文
        var title = raw
        for r in cuts.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            title.removeSubrange(r)
        }
        title = title.replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if title.isEmpty { title = raw.trimmingCharacters(in: .whitespaces) }
        return Result(title: title, due: due)
    }

    // MARK: 星期匹配（weekday 用 Calendar 编号：周日 1 … 周六 7）

    private static func matchWeekday(in text: String) -> (range: Range<String.Index>, weekday: Int, nextWeek: Bool)? {
        let dayChars: [(String, Int)] = [("一", 2), ("二", 3), ("三", 4), ("四", 5), ("五", 6), ("六", 7), ("日", 1), ("天", 1)]
        var best: (Range<String.Index>, Int, Bool)? = nil
        for prefix in ["下周", "这周", "星期", "礼拜", "周"] {
            for (ch, wd) in dayChars {
                if let r = text.range(of: prefix + ch),
                   best == nil || r.lowerBound < best!.0.lowerBound {
                    best = (r, wd, prefix == "下周")
                }
            }
        }
        return best
    }

    // MARK: 时间匹配

    private static func matchTime(in text: String) -> (range: Range<String.Index>, hour: Int, minute: Int)? {
        let full = NSRange(location: 0, length: text.utf16.count)
        // 形式一：15:30
        if let re = try? NSRegularExpression(pattern: #"(\d{1,2}):(\d{2})"#),
           let m = re.firstMatch(in: text, range: full),
           let r = Range(m.range, in: text),
           let hr = Range(m.range(at: 1), in: text), let mr = Range(m.range(at: 2), in: text),
           let h = Int(text[hr]), let mi = Int(text[mr]), h <= 23, mi <= 59 {
            return (r, h, mi)
        }
        // 形式二：（凌晨/上午/中午/下午/晚上）X点（半 / X分）
        let pattern = #"(凌晨|早上|上午|中午|下午|晚上|夜里)?\s*(十[一二]?|[一二三四五六七八九两]|\d{1,2})\s*点\s*(半|(\d{1,2})\s*分)?"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: text, range: full),
              let r = Range(m.range, in: text),
              let nr = Range(m.range(at: 2), in: text),
              var h = chineseNumber(String(text[nr])) else { return nil }
        var minute = 0
        if let br = Range(m.range(at: 3), in: text) {
            if String(text[br]).hasPrefix("半") {
                minute = 30
            } else if let fr = Range(m.range(at: 4), in: text), let v = Int(text[fr]) {
                minute = v
            }
        }
        let period = Range(m.range(at: 1), in: text).map { String(text[$0]) } ?? ""
        switch period {
        case "下午", "晚上", "夜里": if h < 12 { h += 12 }
        case "中午": if h < 12 { h += 12 }
        case "上午", "早上", "凌晨": if h == 12 { h = 0 }
        default: break
        }
        guard h <= 23, minute <= 59 else { return nil }
        return (r, h, minute)
    }

    private static func chineseNumber(_ s: String) -> Int? {
        if let v = Int(s) { return v }
        let map: [String: Int] = ["一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5,
                                  "六": 6, "七": 7, "八": 8, "九": 9, "十": 10, "十一": 11, "十二": 12]
        return map[s]
    }
}
