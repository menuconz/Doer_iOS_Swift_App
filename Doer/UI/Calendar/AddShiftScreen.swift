import SwiftUI

struct AddShiftScreen: View {
    @Binding var path: NavigationPath
    var date: String? = nil
    var hour: Int? = nil
    @State private var viewModel: AddShiftViewModel
    @State private var toastMessage: String? = nil
    @State private var boardConfigCache: BoardConfigCache = DIContainer.shared.boardConfigCache

    init(path: Binding<NavigationPath>, date: String? = nil, hour: Int? = nil) {
        self._path = path
        self.date = date
        self.hour = hour
        self._viewModel = State(initialValue: AddShiftViewModel(date: date ?? "", hour: hour))
    }

    @State private var showFromDatePicker = false
    @State private var showFromTimePicker = false
    @State private var showToDatePicker = false
    @State private var showToTimePicker = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 8)

                    // Project Name
                    LabeledTextField(
                        label: "Project Name",
                        placeholder: "Enter Project Name",
                        text: $viewModel.projectName
                    )

                    Spacer().frame(height: 12)

                    // Client Dropdown
                    DropdownField(
                        label: "Client",
                        options: viewModel.clients.map { $0.name },
                        selectedIndex: viewModel.selectedClientIndex,
                        onSelected: { viewModel.onClientChange($0) }
                    )

                    Spacer().frame(height: 12)

                    // All Day Toggle
                    HStack {
                        Text("All Day")
                            .font(.system(size: 16))
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "4D4BA3"))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { viewModel.isAllDay },
                            set: { viewModel.onAllDayChange($0) }
                        ))
                        .labelsHidden()
                    }

                    Spacer().frame(height: 12)

                    // Duration From
                    Text("From")
                        .fontWeight(.semibold)
                        .font(.system(size: 14))
                    Spacer().frame(height: 4)
                    HStack(spacing: 8) {
                        // Date
                        Button {
                            showFromDatePicker = true
                        } label: {
                            DateFieldDisplay(
                                label: "Date",
                                value: formatDate(viewModel.durationFromDate)
                            )
                        }

                        if !viewModel.isAllDay {
                            // Time
                            Button {
                                showFromTimePicker = true
                            } label: {
                                DateFieldDisplay(
                                    label: "Time",
                                    value: formatTime(viewModel.durationFromTime)
                                )
                            }
                        }
                    }

                    Spacer().frame(height: 12)

                    // Duration To
                    Text("To")
                        .fontWeight(.semibold)
                        .font(.system(size: 14))
                    Spacer().frame(height: 4)
                    HStack(spacing: 8) {
                        // Date
                        Button {
                            showToDatePicker = true
                        } label: {
                            DateFieldDisplay(
                                label: "Date",
                                value: formatDate(viewModel.durationToDate)
                            )
                        }

                        if !viewModel.isAllDay {
                            // Time
                            Button {
                                showToTimePicker = true
                            } label: {
                                DateFieldDisplay(
                                    label: "Time",
                                    value: formatTime(viewModel.durationToTime)
                                )
                            }
                        }
                    }

                    Spacer().frame(height: 12)

                    // Job Address with Google Places Autocomplete
                    LabeledTextField(
                        label: "Job Address",
                        placeholder: "Enter Job Address",
                        text: Binding(
                            get: { viewModel.searchAddress },
                            set: { viewModel.onSearchAddressChange($0) }
                        )
                    )
                    if viewModel.showSuggestions {
                        VStack(spacing: 0) {
                            ForEach(viewModel.placeSuggestions, id: \.placeId) { prediction in
                                Text(prediction.description)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemBackground))
                                    .onTapGesture {
                                        viewModel.onPlaceSelected(prediction)
                                    }
                            }
                        }
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }

                    Spacer().frame(height: 12)

                    // Contract Type Dropdown
                    DropdownField(
                        label: "Contract Type",
                        options: viewModel.contractTypes.map { $0.name },
                        selectedIndex: viewModel.selectedContractTypeIndex,
                        onSelected: { viewModel.onContractTypeChange($0) }
                    )

                    Spacer().frame(height: 12)

                    // Reminder Dropdown
                    DropdownField(
                        label: "Select Reminder",
                        options: viewModel.reminderOptions.map { $0.label },
                        selectedIndex: viewModel.selectedReminderIndex,
                        onSelected: { viewModel.onReminderChange($0) }
                    )

                    Spacer().frame(height: 12)

                    // Job Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Job Description")
                            .font(.caption)
                            .foregroundColor(.gray)
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: Binding(
                                get: { viewModel.instructions },
                                set: { viewModel.onInstructionsChange($0) }
                            ))
                            .frame(minHeight: 100, maxHeight: 160)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            )
                            if viewModel.instructions.isEmpty {
                                Text("Enter the Job Description")
                                    .font(.body)
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                    }

                    Spacer().frame(height: 24)

                    // Create Button
                    Button {
                        viewModel.createShift()
                    } label: {
                        HStack {
                            if viewModel.isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(width: 24, height: 24)
                            } else {
                                Text("Create Job")
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(viewModel.isSubmitting ? Color.gray : DoerTheme.primary)
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.isSubmitting)

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            // Toast message
            if let message = toastMessage {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Add Job")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .onAppear { viewModel.loadInitialData() }
        .onChange(of: boardConfigCache.version) { _, _ in
            // Re-render so AddShiftViewModel.contractTypes (cache-aware) refreshes.
        }
        .onChange(of: viewModel.isSuccess) { _, newValue in
            if newValue {
                // Pop back to Calendar screen (matching Android behavior)
                path.removeLast(path.count)
            }
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            if let msg = newValue {
                showToast(msg)
                viewModel.clearError()
            }
        }
        .sheet(isPresented: $showFromDatePicker) {
            DatePickerSheet(
                title: "From Date",
                selection: $viewModel.durationFromDate,
                displayedComponents: .date,
                onDone: { showFromDatePicker = false }
            )
        }
        .sheet(isPresented: $showFromTimePicker) {
            DatePickerSheet(
                title: "From Time",
                selection: $viewModel.durationFromTime,
                displayedComponents: .hourAndMinute,
                onDone: { showFromTimePicker = false }
            )
        }
        .sheet(isPresented: $showToDatePicker) {
            DatePickerSheet(
                title: "To Date",
                selection: $viewModel.durationToDate,
                displayedComponents: .date,
                onDone: { showToDatePicker = false }
            )
        }
        .sheet(isPresented: $showToTimePicker) {
            DatePickerSheet(
                title: "To Time",
                selection: $viewModel.durationToTime,
                displayedComponents: .hourAndMinute,
                onDone: { showToTimePicker = false }
            )
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func showToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                toastMessage = nil
            }
        }
    }
}

// MARK: - Labeled Text Field

private struct LabeledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
        }
    }
}

// MARK: - Date Field Display

private struct DateFieldDisplay: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
        }
    }
}

// MARK: - Dropdown Field

private struct DropdownField: View {
    let label: String
    let options: [String]
    let selectedIndex: Int
    let onSelected: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Menu {
                ForEach(options.indices, id: \.self) { index in
                    Button {
                        onSelected(index)
                    } label: {
                        Text(options[index])
                    }
                }
            } label: {
                HStack {
                    Text(options.indices.contains(selectedIndex) ? options[selectedIndex] : "")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Date Picker Sheet

private struct DatePickerSheet: View {
    let title: String
    @Binding var selection: Date
    let displayedComponents: DatePickerComponents
    let onDone: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    title,
                    selection: $selection,
                    displayedComponents: displayedComponents
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
