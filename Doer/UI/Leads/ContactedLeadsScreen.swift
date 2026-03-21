import SwiftUI

private let headerBg = Color(hex: "#F3F4F6")
private let borderColor = Color.gray.opacity(0.5)
private let yellowAccent = Color(hex: "#FFCB00")

// Column widths matching MAUI ContactedLeads.xaml
private let colProjectDesc: CGFloat = 220
private let colClientName: CGFloat = 180
private let colClientEmail: CGFloat = 200
private let colCost: CGFloat = 150
private let colLocation: CGFloat = 220
private let colCreatedDate: CGFloat = 150
private let colView: CGFloat = 100

struct ContactedLeadsScreen: View {
    let onOpenDrawer: () -> Void
    let onViewLead: (Int) -> Void

    @State private var viewModel = ContactedLeadsViewModel()
    @State private var showSnackbar = false
    @State private var snackbarMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.leads.isEmpty && !viewModel.isLoading {
                Spacer()
                Text("No contacted leads found")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                Spacer()
            } else {
                // Card with yellow left stripe
                HStack(spacing: 0) {
                    // Yellow left stripe
                    Rectangle()
                        .fill(yellowAccent)
                        .frame(width: 5)

                    // Table content
                    ScrollView(.horizontal, showsIndicators: true) {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 0) {
                                // Header
                                HStack(spacing: 0) {
                                    SortableHeaderCell(title: "Project Description", width: colProjectDesc, column: "JobDescription", currentSortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending) { viewModel.sortBy($0) }
                                    SortableHeaderCell(title: "Client Name", width: colClientName, column: "ClientName", currentSortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending) { viewModel.sortBy($0) }
                                    SortableHeaderCell(title: "Client Email", width: colClientEmail, column: "ClientEmail", currentSortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending) { viewModel.sortBy($0) }
                                    SortableHeaderCell(title: "Cost From Quote", width: colCost, column: "CostFromQuote", currentSortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending) { viewModel.sortBy($0) }
                                    SortableHeaderCell(title: "Location", width: colLocation, column: "Location", currentSortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending) { viewModel.sortBy($0) }
                                    SortableHeaderCell(title: "Created Date", width: colCreatedDate, column: "CreatedDate", currentSortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending) { viewModel.sortBy($0) }
                                    // Empty header for View column
                                    Text("")
                                        .frame(width: colView, height: 40)
                                        .overlay(Rectangle().stroke(Color.gray, lineWidth: 0.5))
                                }
                                .background(headerBg)

                                // Data rows - all read-only matching MAUI
                                ForEach(viewModel.leads) { lead in
                                    HStack(spacing: 0) {
                                        DataCellView(text: lead.jobDescription, width: colProjectDesc)
                                        DataCellView(text: lead.clientName, width: colClientName)
                                        DataCellView(text: lead.clientEmail, width: colClientEmail)
                                        DataCellView(text: lead.costFromQuote != nil ? "\(lead.costFromQuote!)" : "", width: colCost)
                                        DataCellView(text: lead.location, width: colLocation)
                                        DataCellView(text: viewModel.formatDate(lead.createdDate), width: colCreatedDate)
                                        // View button
                                        ZStack {
                                            Rectangle().stroke(borderColor, lineWidth: 0.5)
                                            Button(action: { onViewLead(lead.id) }) {
                                                Text("View")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 6)
                                                    .background(Color(hex: "007AFF"))
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .frame(width: colView, height: 50)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.leading, 5)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
        }
        .loadingOverlay(viewModel.isLoading)
        .navigationTitle("Contacted Leads")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.loadInitialData() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onOpenDrawer) {
                    Image(systemName: "line.3.horizontal")
                }
            }
        }
        .onChange(of: viewModel.errorMessage) { _, msg in
            if let msg = msg {
                snackbarMessage = msg
                showSnackbar = true
                viewModel.clearError()
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
