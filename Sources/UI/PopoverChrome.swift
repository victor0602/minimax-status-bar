import Foundation
import SwiftUI

/// Shared formatters / motion for the quota popover — avoids per-tick `DateFormatter` allocation; springs use `response` + `dampingFraction` for predictable settling on 60/120 Hz displays.
enum PopoverChrome {
    static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = .current
        return f
    }()

    static let exitSpring = Animation.spring(response: 0.28, dampingFraction: 0.92)
    static let exitTerminateDelay: TimeInterval = 0.32
    static let aboutSpring = Animation.spring(response: 0.22, dampingFraction: 0.88)
    static let rowExpandSpring = Animation.spring(response: 0.2, dampingFraction: 0.9)

    static func relativeTime(_ date: Date, now: Date) -> String {
        let diff = Int(now.timeIntervalSince(date))
        if diff < 10 { return "刚刚" }
        if diff < 60 { return "\(diff)s 前" }
        if diff < 3600 { return "\(diff / 60)m 前" }
        return clockFormatter.string(from: date)
    }
}
