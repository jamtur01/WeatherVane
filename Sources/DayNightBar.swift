import AppKit
import SwiftUI

struct DayNightBar: View {
    let timeZone: TimeZone
    let effectiveNow: Date
    var onDrag: (Date) -> Void
    var onReset: () -> Void

    @State private var lastTapTime: Date = .distantPast
    @State private var isDragging = false

    private let totalHeight: CGFloat = Constants.dayNightBarHeight
    private let markerSize: CGFloat = Constants.dayNightBarMarkerSize
    private let tickCount: Int = Constants.dayNightBarTickCount

    // Cached once rather than allocated per tick on every re-render. The nighttime
    // color stays appearance-adaptive — the provider is evaluated by the system.
    private static let daytimeTickColor = Color.orange.opacity(0.85)
    private static let nighttimeTickColor = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua]) == .darkAqua
        return isDark ? NSColor(white: 0.5, alpha: 1) : NSColor(white: 0.3, alpha: 1)
    }))

    var body: some View {
        GeometryReader { geo in
            ZStack {
                tickMarks(width: geo.size.width)
                marker(width: geo.size.width)
            }
            .frame(height: totalHeight)
            .contentShape(Rectangle())
            .gesture(dragGesture(width: geo.size.width))
        }
        .frame(height: totalHeight)
    }

    private func tickMarks(width: CGFloat) -> some View {
        ForEach(0 ..< tickCount, id: \.self) { tick in
            let hour = Double(tick) / 4.0
            let x = CGFloat(tick) / CGFloat(tickCount - 1) * width
            let isMajor = tick % 24 == 0
            let isHour = tick % 4 == 0
            let height: CGFloat = isMajor ? 14 : (isHour ? 9 : 5)
            let isDaytime = hour >= 6 && hour <= 18
            let color = isDaytime ? Self.daytimeTickColor : Self.nighttimeTickColor

            Rectangle()
                .fill(color)
                .frame(width: 1, height: height)
                .position(x: x, y: totalHeight / 2)
        }
    }

    private func marker(width: CGFloat) -> some View {
        let x = markerPosition(in: width)
        return ZStack {
            Circle()
                .fill(Color(white: 0.92))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            HStack(spacing: 1) {
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
            }
            .font(.system(size: 7, weight: .bold))
            .foregroundColor(Color(white: 0.35))
        }
        .frame(width: markerSize, height: markerSize)
        .position(x: x, y: totalHeight / 2)
    }

    private func markerPosition(in width: CGFloat) -> CGFloat {
        var cal = Calendar.current
        cal.timeZone = timeZone
        let hour = cal.component(.hour, from: effectiveNow)
        let minute = cal.component(.minute, from: effectiveNow)
        let fraction = (Double(hour) + Double(minute) / 60.0) / 24.0
        return CGFloat(fraction) * width
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Ignore a press until it actually moves, so a tap doesn't silently
                // enter virtual time. Once dragging starts it stays active.
                let moved = hypot(value.translation.width, value.translation.height)
                guard isDragging || moved >= Constants.dayNightBarDragThreshold else { return }
                isDragging = true

                let fraction = max(0, min(value.location.x / width, 1.0))
                onDrag(Self.targetDate(
                    forFraction: fraction,
                    on: effectiveNow,
                    in: timeZone
                ))
            }
            .onEnded { value in
                isDragging = false
                let dragDistance = hypot(value.translation.width, value.translation.height)
                if dragDistance < Constants.dayNightBarDragThreshold {
                    let now = Date()
                    if now.timeIntervalSince(lastTapTime) < 0.3 {
                        onReset()
                        lastTapTime = .distantPast
                    } else {
                        lastTapTime = now
                    }
                }
            }
    }

    static func targetDate(
        forFraction fraction: Double,
        on day: Date,
        in timeZone: TimeZone
    ) -> Date {
        let clampedFraction = max(0, min(fraction, 1))
        let totalMinutes = min(Int((clampedFraction * 1440).rounded()), 1439)
        let hour = totalMinutes / 60
        let minute = totalMinutes % 60

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let target = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: day,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) else {
            return day
        }
        return target
    }
}
