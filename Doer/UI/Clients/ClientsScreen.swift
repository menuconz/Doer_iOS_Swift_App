import SwiftUI

private let orangeAccent = Color(hex: "#FF9500")
private let bgColor = Color(hex: "#F8F9FA")
private let headerBg = Color(hex: "#F3F4F6")
private let borderColor = Color.gray.opacity(0.5)
private let blueButton = Color(hex: "#007AFF")
private let borderStrokeColor = Color(hex: "#667685")

// Column widths matching MAUI DataGridColumn WidthRequest
private let colName: CGFloat = 200
private let colEmail: CGFloat = 250
private let colProjects: CGFloat = 150
private let colActions: CGFloat = 50

struct ClientsScreen: View {
    let onOpenDrawer: () -> Void
    let onAddClient: () -> Void

    @State private var viewModel = ClientsViewModel()
    @State private var showSnackbar = false
    @State private var snackbarMessage = ""

    var body: some View {
        VStack(spacing: 0) {
                if viewModel.clients.isEmpty && !viewModel.isLoading {
                    Spacer()
                    Text("No clients found")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                    Spacer()
                } else {
                    // Horizontally scrollable table
                    HStack(spacing: 0) {
                        // MAUI: orange accent bar on left
                        Rectangle()
                            .fill(orangeAccent)
                            .frame(width: 5)

                        ScrollView(.horizontal, showsIndicators: true) {
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(spacing: 0) {
                                    // Header Row
                                    HStack(spacing: 0) {
                                        ClientSortableHeader(title: "Client Name", width: colName, column: "Name", viewModel: viewModel)
                                        ClientSortableHeader(title: "Client Email", width: colEmail, column: "Email", viewModel: viewModel)
                                        // Projects header (not sortable)
                                        Text("Projects")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: "#374151"))
                                            .frame(width: colProjects, height: 40)
                                            .overlay(Rectangle().stroke(borderColor, lineWidth: 0.5))
                                        // Delete header
                                        Text("Delete")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color(hex: "#374151"))
                                            .frame(width: colActions, height: 40)
                                            .overlay(Rectangle().stroke(borderColor, lineWidth: 0.5))
                                    }
                                    .background(headerBg)

                                    // Data Rows
                                    ForEach(viewModel.clients) { client in
                                        HStack(spacing: 0) {
                                            // Name cell - tappable to edit
                                            Button(action: { viewModel.editClientName(client) }) {
                                                Text(client.name)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color(hex: "#374151"))
                                                    .lineLimit(2)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(.horizontal, 8)
                                            }
                                            .frame(width: colName, height: 50)
                                            .clipped()
                                            .overlay(Rectangle().stroke(borderColor, lineWidth: 0.5))

                                            // Email cell - tappable to edit
                                            Button(action: { viewModel.editClientEmail(client) }) {
                                                Text(client.email)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color(hex: "#374151"))
                                                    .lineLimit(2)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(.horizontal, 8)
                                            }
                                            .frame(width: colEmail, height: 50)
                                            .clipped()
                                            .overlay(Rectangle().stroke(borderColor, lineWidth: 0.5))

                                            // Projects cell - "View" button
                                            ZStack {
                                                Rectangle().stroke(borderColor, lineWidth: 0.5)
                                                Button(action: { viewModel.viewClientProjects(client) }) {
                                                    Text("View")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white)
                                                }
                                                .frame(height: 35)
                                                .padding(.horizontal, 16)
                                                .background(blueButton)
                                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                            }
                                            .frame(width: colProjects, height: 50)

                                            // Delete cell
                                            ZStack {
                                                Rectangle().stroke(borderColor, lineWidth: 0.5)
                                                Button(action: { viewModel.openDeleteDialog(client) }) {
                                                    Image(systemName: "trash")
                                                        .foregroundColor(.red)
                                                }
                                            }
                                            .frame(width: colActions, height: 50)
                                        }
                                    }
                                }
                            }
                        }
                    }

                Spacer().frame(height: 16)

                // "Add Client" button
                Button(action: onAddClient) {
                    Text("Add Client")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 150, height: 40)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Spacer().frame(height: 16)
            }
        }
        .background(bgColor)
        .loadingOverlay(viewModel.isLoading)
        .navigationTitle("Clients")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.refreshData() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onOpenDrawer) {
                    Image(systemName: "line.3.horizontal")
                }
            }
        }
        // Edit bottom sheet
        .sheet(isPresented: Binding(
            get: { viewModel.editingClient != nil },
            set: { if !$0 { viewModel.dismissEditSheet() } }
        )) {
            ClientEditorSheetContent(
                title: viewModel.editorTitle,
                text: $viewModel.editorText,
                onSave: { viewModel.saveEdit() },
                onClose: { viewModel.dismissEditSheet() },
                isSaving: viewModel.isSaving
            )
            .presentationDetents([.medium, .large])
        }
        // Projects bottom sheet
        .sheet(isPresented: Binding(
            get: { viewModel.projectsClient != nil },
            set: { if !$0 { viewModel.dismissProjectsSheet() } }
        )) {
            ClientProjectsSheetContent(
                searchText: $viewModel.searchText,
                onSearchChange: { viewModel.onSearchTextChange($0) },
                jobs: viewModel.filteredJobs,
                isLoading: viewModel.isLoadingProjects,
                isSaving: viewModel.isSavingProjects,
                onToggle: { viewModel.toggleJobAssignment($0) },
                onSave: { viewModel.saveProjectAssignments() },
                onClose: { viewModel.dismissProjectsSheet() }
            )
            .presentationDetents([.large])
        }
        // Delete confirmation dialog
        .alert("Delete Client", isPresented: Binding(
            get: { viewModel.deletingClient != nil },
            set: { if !$0 { viewModel.dismissDeleteDialog() } }
        )) {
            Button("No", role: .cancel) { viewModel.dismissDeleteDialog() }
            Button("Yes", role: .destructive) { viewModel.confirmDelete() }
        } message: {
            Text("Do you really want to delete this Client?")
        }
        .onChange(of: viewModel.errorMessage) { _, msg in
            if let msg = msg {
                snackbarMessage = msg
                showSnackbar = true
                viewModel.clearError()
            }
        }
        .onChange(of: viewModel.successMessage) { _, msg in
            if let msg = msg {
                snackbarMessage = msg
                showSnackbar = true
                viewModel.clearSuccess()
            }
        }
        .overlay(alignment: .bottom) {
            if showSnackbar {
                Text(snackbarMessage)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showSnackbar = false }
                    }
            }
        }
    }
}

// MARK: - Client Sortable Header

private struct ClientSortableHeader: View {
    let title: String
    let width: CGFloat
    let column: String
    let viewModel: ClientsViewModel

    var body: some View {
        let sortIcon: String = {
            if viewModel.sortColumn == column {
                return viewModel.sortAscending ? "\u{25B2}" : "\u{25BC}"
            }
            return ""
        }()

        Button(action: { viewModel.sortBy(column) }) {
            HStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "#374151"))
                    .lineLimit(1)
                Spacer()
                if !sortIcon.isEmpty {
                    Text(sortIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#374151"))
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(width: width, height: 40)
        .clipped()
        .contentShape(Rectangle())
        .overlay(Rectangle().stroke(borderColor, lineWidth: 0.5))
    }
}

// MARK: - Client Editor Bottom Sheet

private struct ClientEditorSheetContent: View {
    let title: String
    @Binding var text: String
    let onSave: () -> Void
    let onClose: () -> Void
    let isSaving: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top row
            HStack {
                Button(action: onClose) {
                    Text("\u{26CC}")
                        .font(.system(size: 18))
                }
                Spacer()
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                Spacer()
                Button(action: onSave) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Save")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                }
                .frame(width: 100, height: 40)
                .background(Color(hex: "#007AFF"))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .disabled(isSaving)
            }
            .padding(16)

            // Divider
            Rectangle()
                .fill(Color(hex: "#667685"))
                .frame(height: 1)

            // Editor
            TextEditor(text: $text)
                .font(.system(size: 16))
                .frame(height: 150)
                .padding(.horizontal, 10)
                .padding(.top, 8)

            Spacer()
        }
    }
}

// MARK: - Client Projects Bottom Sheet

private struct ClientProjectsSheetContent: View {
    @Binding var searchText: String
    let onSearchChange: (String) -> Void
    let jobs: [ClientJobDto]
    let isLoading: Bool
    let isSaving: Bool
    let onToggle: (ClientJobDto) -> Void
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            ZStack {
                Color(hex: "#007AFF")
                Text("Projects")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 16)
                }
            }
            .frame(height: 60)

            // Search bar
            TextField("Search projects...", text: Binding(
                get: { searchText },
                set: { onSearchChange($0) }
            ))
            .font(.system(size: 14))
            .padding()
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Job list
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if jobs.isEmpty {
                Spacer()
                Text("No projects available")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(jobs, id: \.id) { job in
                            Button(action: { onToggle(job) }) {
                                HStack {
                                    Text(job.projectName)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.black)
                                    Spacer()
                                    Image(systemName: job.isAssigned ? "checkmark.square.fill" : "square")
                                        .foregroundColor(Color(hex: "#007AFF"))
                                        .font(.system(size: 22))
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // "SAVE CHANGES" button
            Button(action: onSave) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("SAVE CHANGES")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(hex: "#007AFF"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .disabled(isSaving || isLoading)
            .padding(16)
        }
    }
}
