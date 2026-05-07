import SwiftUI

struct BoardSettingsScreen: View {
    @State private var viewModel = BoardSettingsViewModel()
    @State private var hasLoaded = false

    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.97, blue: 0.98).ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Board name editor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Board")
                                .font(.title3.bold())
                                .foregroundColor(Color(red: 0.07, green: 0.09, blue: 0.15))

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Board Name")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                TextField(
                                    "Board name",
                                    text: Binding(
                                        get: { viewModel.boardNameDraft },
                                        set: { viewModel.boardNameDraft = $0 }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)
                                Button("Save Name") {
                                    viewModel.saveBoardName()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(red: 0.10, green: 0.46, blue: 0.82))
                                .foregroundColor(.white)
                                .disabled(
                                    viewModel.boardNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                    viewModel.boardNameDraft.trimmingCharacters(in: .whitespacesAndNewlines) == (viewModel.board?.name ?? "")
                                )
                            }
                            .padding(12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Dropdowns section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dropdowns")
                                .font(.title3.bold())
                                .foregroundColor(Color(red: 0.07, green: 0.09, blue: 0.15))
                            Text("Tap a column to expand and edit option labels")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        ForEach(viewModel.optionsByColumn.keys.sorted(), id: \.self) { columnName in
                            ColumnCard(
                                columnName: columnName,
                                options: viewModel.optionsByColumn[columnName] ?? [],
                                expanded: viewModel.expandedColumns.contains(columnName),
                                onToggle: { viewModel.toggleColumn(columnName) },
                                onEdit: { viewModel.beginEdit($0) },
                                onDelete: { viewModel.confirmDelete($0) },
                                onAdd: { viewModel.beginAdd(columnName: columnName) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("Board Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !hasLoaded {
                hasLoaded = true
                viewModel.load()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.clearError() }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            if let success = viewModel.successMessage {
                Text(success)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.green.opacity(0.85))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 24)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            viewModel.clearSuccess()
                        }
                    }
            }
        }
        .sheet(item: Binding(
            get: { viewModel.editing },
            set: { viewModel.editing = $0 }
        )) { editing in
            EditOptionSheet(
                option: editing,
                onChange: { viewModel.editing = $0 },
                onSave: { viewModel.saveEdit() },
                onDismiss: { viewModel.cancelEdit() }
            )
        }
        .alert("Delete option", isPresented: Binding(
            get: { viewModel.pendingDelete != nil },
            set: { if !$0 { viewModel.cancelDelete() } }
        )) {
            Button("Delete", role: .destructive) { viewModel.deleteOption() }
            Button("Cancel", role: .cancel) { viewModel.cancelDelete() }
        } message: {
            if let target = viewModel.pendingDelete {
                Text("Remove \"\(target.displayName)\" from \(target.columnName)? Existing records using this value will keep working but won't be selectable.")
            }
        }
    }
}

private struct ColumnCard: View {
    let columnName: String
    let options: [DropdownOptionDto]
    let expanded: Bool
    let onToggle: () -> Void
    let onEdit: (DropdownOptionDto) -> Void
    let onDelete: (DropdownOptionDto) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(columnName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(red: 0.07, green: 0.09, blue: 0.15))
                Spacer()
                Text("\(options.count) options")
                    .font(.caption)
                    .foregroundColor(.gray)
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.gray)
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture { onToggle() }

            if expanded {
                Divider()
                ForEach(options) { option in
                    OptionRowView(
                        option: option,
                        onEdit: { onEdit(option) },
                        onDelete: { onDelete(option) }
                    )
                }
                // Add new option row
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color(red: 0.10, green: 0.46, blue: 0.82))
                    Text("Add Option")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(red: 0.10, green: 0.46, blue: 0.82))
                    Spacer()
                }
                .padding(14)
                .contentShape(Rectangle())
                .onTapGesture { onAdd() }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct OptionRowView: View {
    let option: DropdownOptionDto
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(Color(argb: BoardConfigCache.parseHexColor(option.color) ?? 0xFFC4C4C4))
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(option.displayName).font(.subheadline)
                Text("Value: \(option.value)").font(.caption2).foregroundColor(.gray)
            }
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(Color(red: 0.10, green: 0.46, blue: 0.82))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(Color(red: 0.94, green: 0.27, blue: 0.27))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }
}

private struct EditOptionSheet: View {
    @State var option: DropdownOptionDto
    let onChange: (DropdownOptionDto) -> Void
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Edit \(option.columnName)") {
                    TextField("Display Name", text: Binding(
                        get: { option.displayName },
                        set: {
                            option.displayName = $0
                            onChange(option)
                        }
                    ))
                    TextField("Color (e.g. #1976D2)", text: Binding(
                        get: { option.color ?? "" },
                        set: {
                            option.color = $0
                            onChange(option)
                        }
                    ))
                    Stepper(value: Binding(
                        get: { option.sortOrder },
                        set: {
                            option.sortOrder = $0
                            onChange(option)
                        }
                    ), in: 0...100) {
                        Text("Sort Order: \(option.sortOrder)")
                    }
                }
            }
            .navigationTitle(option.id == 0 ? "Add Option" : "Edit Option")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { onSave() }
                        .disabled(option.displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
