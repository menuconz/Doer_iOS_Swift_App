import SwiftUI

private let FilterBg = Color(hex: "#667685")
private let FilterText = Color(hex: "#667685")
private let BlueLabel = Color(hex: "#4D4BA3")
private let HeaderBorderColor = Color.gray
private let CellBorderColor = Color(hex: "#D3D3D3")
private let SearchBorderColor = Color(hex: "#ECECEC")

private let ColName: CGFloat = 200
private let ColEmail: CGFloat = 180
private let ColPhone: CGFloat = 150
private let ColAddress: CGFloat = 200
private let ColDate: CGFloat = 200
private let ColNotes: CGFloat = 200
private let ColAmount: CGFloat = 150
private let ColSkills: CGFloat = 200
private let ColAction: CGFloat = 100

struct ViewQuotationsScreen: View {
    var onBack: () -> Void

    @State private var viewModel: ViewQuotationsViewModel

    init(shiftId: Int, onBack: @escaping () -> Void) {
        self.onBack = onBack
        _viewModel = State(initialValue: ViewQuotationsViewModel(shiftId: shiftId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                // Search bar
                HStack(spacing: 0) {
                    Text("\u{1F50D}").font(.system(size: 16))
                    TextField("Type a location to find nearby contractors...", text: Binding(
                        get: { viewModel.searchAddress },
                        set: { viewModel.onSearchAddressChanged($0) }
                    ))
                    .font(.system(size: 14))
                    .foregroundColor(BlueLabel)
                    .padding(.leading, 10)
                    if !viewModel.searchAddress.isEmpty {
                        Button(action: { viewModel.clearSearchLocation() }) {
                            Text("\u{2716}").font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(SearchBorderColor, lineWidth: 4))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

                // Google Places list
                if viewModel.showPlaceList && !viewModel.placeList.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(viewModel.placeList, id: \.placeId) { prediction in
                            Text(prediction.description)
                                .font(.system(size: 15))
                                .foregroundColor(BlueLabel)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(5)
                                .onTapGesture { viewModel.selectPlace(prediction) }
                        }
                    }
                    .background(Color.white)
                    .padding(.vertical, 4)
                }

                // Filter button
                HStack {
                    Button(action: { viewModel.showFilter() }) {
                        HStack(spacing: 8) {
                            Text("\u{2195}").font(.system(size: 14)).foregroundColor(.white)
                                .padding(6)
                                .background(FilterBg)
                                .cornerRadius(12)
                            Text("Filter")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(FilterText)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(radius: 1)
                    }
                    Spacer()
                }
                .padding(10)

                if viewModel.quotations.isEmpty {
                    Spacer()
                    Text("No quotations found").foregroundColor(.gray).font(.system(size: 16))
                    Spacer()
                } else {
                    ScrollView(.horizontal, showsIndicators: true) {
                      ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header row
                            HStack(spacing: 0) {
                                QuotationHeaderCell("Contractor Name", ColName, "ContractorName", viewModel)
                                QuotationHeaderCell("Contractor Email", ColEmail, "ContractorEmail", viewModel)
                                QuotationHeaderCell("Contractor Phone", ColPhone, "ContractorPhone", viewModel)
                                QuotationHeaderCell("Contractor Address", ColAddress, "ContractorAddress", viewModel)
                                QuotationHeaderCell("Quotation Date", ColDate, "QuotedDate", viewModel)
                                QuotationHeaderCell("Quotation Message", ColNotes, "Notes", viewModel)
                                QuotationHeaderCell("Quoted Price ($)", ColAmount, "QuotedAmount", viewModel)
                                QuotationHeaderCell("Skills", ColSkills, "Skills", viewModel)
                                Text("")
                                    .frame(width: ColAction, height: 40)
                                    .overlay(Rectangle().stroke(HeaderBorderColor, lineWidth: 1))
                            }

                            // Data rows
                            ForEach(viewModel.quotations, id: \.id) { quotation in
                                HStack(spacing: 0) {
                                    QuotationDataCell(quotation.contractorName, ColName)
                                    QuotationDataCell(quotation.contractorEmail, ColEmail)
                                    QuotationDataCell(quotation.contractorPhone, ColPhone)
                                    QuotationDataCell(quotation.contractorAddress, ColAddress)
                                    QuotationDataCell(viewModel.formatDate(quotation.quotedDate), ColDate)
                                    QuotationDataCell(quotation.notes, ColNotes)
                                    QuotationDataCell(String(format: "$%.2f", quotation.quotedAmount), ColAmount)
                                    QuotationDataCell(quotation.skills, ColSkills)

                                    Button(action: { viewModel.hireContractor(quotation) }) {
                                        Text("Hire")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(DoerTheme.primary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 6)
                                            .background(Color.white)
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(DoerTheme.primary, lineWidth: 1))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: ColAction, height: 50)
                                    .overlay(Rectangle().stroke(CellBorderColor, lineWidth: 1))
                                    .disabled(viewModel.isHiring)
                                }
                            }
                        }
                      }
                    }
                    .padding(.horizontal, 15)
                }
            }
        }
        .navigationTitle("Quotations")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.loadInitialData() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) { Image(systemName: "chevron.left") }
            }
        }
        .sheet(isPresented: $viewModel.showFilterSheet) {
            FilterQuotationsSheet(viewModel: viewModel)
        }
        .overlay {
            if viewModel.isHiring {
                Color.black.opacity(0.1).ignoresSafeArea()
                ProgressView()
            }
        }
        .alert("Hire Contractor", isPresented: $viewModel.showHireConfirmation) {
            Button("Yes") { viewModel.confirmHire() }
            Button("No", role: .cancel) { viewModel.cancelHire() }
        } message: {
            Text("Do you want to hire this contractor?")
        }
        .alert("Success", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )) {
            Button("OK") {
                viewModel.successMessage = nil
                onBack()
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .snackbar(message: Binding(
            get: { viewModel.errorMessage },
            set: { _ in viewModel.clearError() }
        ))
    }
}

// MARK: - Filter Sheet
private struct FilterQuotationsSheet: View {
    let viewModel: ViewQuotationsViewModel

    private let BorderStrokeColor = Color(hex: "#667685")
    private let BlueLabel = Color(hex: "#4D4BA3")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("FILTER CONTRACTORS").font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { viewModel.dismissFilter() }) {
                    Text("X").frame(width: 40, height: 40)
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.bottom, 15)

            Text("Search By Skill: ").font(.system(size: 15)).padding(5)
            TextField("Search contractors By Skill...", text: Binding(
                get: { viewModel.searchSkills },
                set: { viewModel.onSearchSkillsChanged($0) }
            ))
            .font(.system(size: 16))
            .foregroundColor(.blue)
            .frame(height: 55)
            .padding(.horizontal, 10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(BorderStrokeColor, lineWidth: 1))

            Spacer().frame(height: 15)

            Text("Search By Name: ").font(.system(size: 15)).padding(5)
            TextField("Search contractors By Name...", text: Binding(
                get: { viewModel.searchName },
                set: { viewModel.onSearchNameChanged($0) }
            ))
            .font(.system(size: 16))
            .foregroundColor(BlueLabel)
            .frame(height: 55)
            .padding(.horizontal, 10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(BorderStrokeColor, lineWidth: 1))

            Spacer().frame(height: 10)

            HStack {
                Spacer()
                Button("Clear All") { viewModel.clearFilter() }
                    .foregroundColor(Color(hex: "FF3B30"))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: "#DDDDDD"), lineWidth: 1))
                Button(action: { viewModel.applyFilter() }) {
                    Text("Apply")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "007AFF"))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                Spacer()
            }

            Spacer().frame(height: 20)
        }
        .padding(15)
    }
}

// MARK: - Sortable Header Cell
private struct QuotationHeaderCell: View {
    let title: String
    let width: CGFloat
    let column: String
    let viewModel: ViewQuotationsViewModel

    init(_ title: String, _ width: CGFloat, _ column: String, _ viewModel: ViewQuotationsViewModel) {
        self.title = title
        self.width = width
        self.column = column
        self.viewModel = viewModel
    }

    var body: some View {
        let sortIcon = viewModel.sortColumn == column ? (viewModel.sortAscending ? " \u{25B2}" : " \u{25BC}") : ""
        Text("\(title)\(sortIcon)")
            .font(.system(size: 14, weight: .bold))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(width: width, height: 40)
            .clipped()
            .overlay(Rectangle().stroke(HeaderBorderColor, lineWidth: 1))
            .onTapGesture { viewModel.sortBy(column) }
    }
}

// MARK: - Data Cell
private struct QuotationDataCell: View {
    let text: String
    let width: CGFloat

    init(_ text: String, _ width: CGFloat) {
        self.text = text
        self.width = width
    }

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(width: width, height: 50)
            .clipped()
            .overlay(Rectangle().stroke(CellBorderColor, lineWidth: 1))
    }
}
