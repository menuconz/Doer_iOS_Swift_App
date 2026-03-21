import SwiftUI

struct CalendarScreen: View {
    @Binding var path: NavigationPath
    @State private var viewModel = CalendarViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Month navigation header
            HStack {
                Button(action: { viewModel.previousMonth() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(hex: "333333"))
                }
                .padding(.horizontal, 8)

                Spacer()

                Text(viewModel.currentMonthYear)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { viewModel.nextMonth() }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color(hex: "333333"))
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(hex: "F8F9FA"))

            // Weekday headers
            HStack(spacing: 0) {
                let days = ["M", "T", "W", "T", "F", "S", "S"]
                ForEach(days.indices, id: \.self) { index in
                    Text(days[index])
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "333333"))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .background(Color.white)

            // Calendar grid
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.weeks) { week in
                        CalendarWeekRow(
                            week: week,
                            isManager: viewModel.isManager,
                            onDayTapped: { dateStr in
                                path.append(Route.dayTimeline(date: dateStr))
                            },
                            onDayLongPressed: { dateStr in
                                path.append(Route.addShift(date: dateStr))
                            }
                        )
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .loadingOverlay(viewModel.isLoading)
        .onAppear {
            viewModel.refreshOnAppear()
        }
    }
}

private struct CalendarWeekRow: View {
    let week: CalendarWeek
    let isManager: Bool
    let onDayTapped: (String) -> Void
    let onDayLongPressed: (String) -> Void

    private let calendar = Calendar.current

    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let cellWidth = screenWidth / 7.0

        ZStack(alignment: .topLeading) {
            // Day cells
            HStack(spacing: 0) {
                ForEach(week.days) { day in
                    dayCellView(day: day)
                        .frame(maxWidth: .infinity)
                        .frame(height: 110)
                        .overlay(
                            Rectangle()
                                .stroke(Color(hex: "E0E0E0"), lineWidth: 0.5)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if day.isCurrentMonth {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yyyy-MM-dd"
                                onDayTapped(formatter.string(from: day.date))
                            }
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    if day.isCurrentMonth && isManager {
                                        let formatter = DateFormatter()
                                        formatter.dateFormat = "yyyy-MM-dd"
                                        onDayLongPressed(formatter.string(from: day.date))
                                    }
                                }
                        )
                }
            }
            .frame(height: 110)

            // Multi-day events overlay
            ForEach(week.multiDayEvents) { event in
                let xOffset = CGFloat(event.startColumn) * cellWidth + 1
                let width = CGFloat(event.columnSpan) * cellWidth - 2
                let yOffset = CGFloat(30 + event.level * 22)

                HStack(spacing: 0) {
                    Text(event.title)
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 4)
                .frame(width: width, height: 18, alignment: .leading)
                .background(event.color)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .offset(x: xOffset, y: yOffset)
                .allowsHitTesting(false)
            }
        }
        .frame(height: 110)
    }

    @ViewBuilder
    private func dayCellView(day: CalendarDay) -> some View {
        VStack(spacing: 0) {
            if !day.dayNumber.isEmpty {
                // Day number
                HStack {
                    Spacer()
                    if day.isToday {
                        Text(day.dayNumber)
                            .font(.system(size: 12))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color(hex: "007AFF"))
                            .clipShape(Circle())
                    } else {
                        Text(day.dayNumber)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "333333"))
                    }
                    Spacer()
                }
                .padding(.top, 2)

                Spacer()

                // Extra events count
                if day.extraEventsCount > 0 {
                    Text("+\(day.extraEventsCount) more")
                        .font(.system(size: 9))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .frame(height: 18)
                        .background(Color(hex: "8E8E93"))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.horizontal, 1)
                        .padding(.bottom, 2)
                }
            } else {
                Spacer()
            }
        }
        .padding(2)
    }
}
