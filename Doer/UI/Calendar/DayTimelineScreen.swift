import SwiftUI

struct DayTimelineScreen: View {
    @Binding var path: NavigationPath
    let date: String
    @State private var viewModel: DayTimelineViewModel

    init(path: Binding<NavigationPath>, date: String) {
        self._path = path
        self.date = date
        self._viewModel = State(initialValue: DayTimelineViewModel(date: date))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Horizontal date picker
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(viewModel.calendarDays) { dayItem in
                            DayChip(
                                item: dayItem,
                                isManager: viewModel.isManager,
                                onTap: {
                                    viewModel.selectDate(dayItem.date)
                                },
                                onLongPress: {
                                    path.append(Route.addShift(date: viewModel.selectedDateString))
                                }
                            )
                            .id(dayItem.dateString)
                            .onAppear {
                                // Only append future dates at trailing edge
                                if dayItem.dateString == viewModel.calendarDays.last?.dateString {
                                    viewModel.loadMoreFutureDates()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(height: 70)
                .background(Color(hex: "F8F9FA"))
                .onChange(of: viewModel.selectedDateString) { _, newValue in
                    withAnimation {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(viewModel.selectedDateString, anchor: .center)
                    }
                }
            }

            Divider()

            if viewModel.isLoading {
                Spacer()
            }

            if !viewModel.isLoading {
                // Total jobs header
                HStack {
                    Text("Total Jobs: \(viewModel.totalJobs)")
                        .font(.subheadline)
                        .fontWeight(.bold)

                    Spacer()

                    if viewModel.totalJobs > 0 {
                        Button("View All") {
                            path.append(Route.dayDetail(date: viewModel.selectedDateString))
                        }
                        .font(.system(size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "007AFF"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // All day jobs
                if !viewModel.allDayJobs.isEmpty {
                    HStack(alignment: .top, spacing: 0) {
                        Text("all-day")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .fontWeight(.bold)
                            .padding(10)

                        VStack(spacing: 0) {
                            let chunked = viewModel.allDayJobs.chunked(into: 2)
                            ForEach(chunked.indices, id: \.self) { rowIdx in
                                HStack(spacing: 0) {
                                    ForEach(chunked[rowIdx]) { job in
                                        HStack {
                                            Text(job.projectName)
                                                .font(.system(size: 14))
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .truncationMode(.tail)

                                            Spacer()

                                            Text(job.statusMessage)
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.9))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(job.contractColor)
                                        .clipShape(Capsule())
                                        .padding(.vertical, 2)
                                        .onTapGesture {
                                            path.append(Route.dayDetail(date: viewModel.selectedDateString, shiftId: job.shift.id))
                                        }
                                    }
                                    if chunked[rowIdx].count == 1 {
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    .padding(2)
                    .background(Color(hex: "F8F9FA"))
                }

                if viewModel.totalJobs == 0 {
                    Text("No job scheduled for this day")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(32)
                }

                // 24-hour timeline
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Hour lines
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                HStack(alignment: .top, spacing: 0) {
                                    Text(formatHourLabel(hour))
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                        .frame(width: 55, alignment: .leading)
                                        .padding(.leading, 4)
                                        .padding(.top, 2)

                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(height: 80)
                                        .contentShape(Rectangle())
                                        .simultaneousGesture(
                                            LongPressGesture(minimumDuration: 0.5)
                                                .onEnded { _ in
                                                    if viewModel.isManager {
                                                        path.append(Route.addShift(date: viewModel.selectedDateString, hour: hour))
                                                    }
                                                }
                                        )
                                }
                                .frame(height: 80)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color(hex: "E8E8E8"), lineWidth: 0.5)
                                )
                            }
                        }

                        // Timeline blocks overlay
                        let screenWidth = UIScreen.main.bounds.width
                        ForEach(viewModel.timelineBlocks) { block in
                            let topOffset = block.startHour * 80
                            let blockHeight = max(block.durationHours * 80, 40)
                            let availableWidth = screenWidth - 55
                            let colWidth = availableWidth / CGFloat(block.totalColumns)
                            let xOffset = 55 + colWidth * CGFloat(block.columnIndex) + 2
                            let width = colWidth - 4

                            VStack(alignment: .leading, spacing: 2) {
                                Text(block.projectName)
                                    .font(.system(size: 11))
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(hex: "333333"))
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                if !block.address.isEmpty {
                                    Text(block.address)
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                            .padding(6)
                            .frame(width: width, height: blockHeight, alignment: .topLeading)
                            .background(block.contractColor.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(block.contractColor, lineWidth: 2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .offset(x: xOffset, y: topOffset)
                            .onTapGesture {
                                path.append(Route.dayDetail(date: viewModel.selectedDateString, shiftId: block.shift.id))
                            }
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in
                                        if viewModel.isManager {
                                            path.append(Route.addShift(date: viewModel.selectedDateString, hour: Int(block.startHour)))
                                        }
                                    }
                            )
                        }
                    }
                    .frame(height: 24 * 80)
                }
            }
        }
        .loadingOverlay(viewModel.isLoading)
        .navigationTitle(viewModel.pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            if viewModel.calendarDays.isEmpty {
                viewModel.loadInitialData()
            } else {
                viewModel.refresh()
            }
        }
    }

    private func formatHourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12 AM"
        case 1...11: return "\(hour) AM"
        case 12: return "12 PM"
        default: return "\(hour - 12) PM"
        }
    }
}

private struct DayChip: View {
    let item: CalendarDayItem
    let isManager: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        let bgColor: Color = {
            if item.isSelected { return Color(hex: "FF3B30") }
            if item.isToday { return Color(hex: "007AFF") }
            return Color.clear
        }()

        let textColor: Color = {
            if item.isSelected || item.isToday { return .white }
            return Color(hex: "333333")
        }()

        VStack(spacing: 0) {
            Text(item.dayLetter)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "333333").opacity(0.7))

            Spacer().frame(height: 2)

            Text(item.dayNumber)
                .font(.system(size: 14))
                .fontWeight(.bold)
                .foregroundColor(textColor)
                .frame(width: 32, height: 32)
                .background(bgColor)
                .clipShape(Circle())

            Spacer().frame(height: 2)

            Text(item.monthName)
                .font(.system(size: 9))
                .foregroundColor(Color(hex: "333333").opacity(0.6))
        }
        .frame(width: 44)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    if isManager { onLongPress() }
                }
        )
    }
}

// MARK: - Array Chunking Helper
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
