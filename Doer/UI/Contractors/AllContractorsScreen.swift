import SwiftUI

private let FilterBg = Color(hex: "#667685")
private let FilterText = Color(hex: "#667685")
private let BlueLabel = Color(hex: "#4D4BA3")
private let BorderStroke = Color(hex: "#667685")
private let HeaderBorderColor = Color.gray
private let CellBorderColor = Color(hex: "#D3D3D3")
private let BgColor = Color(hex: "#F8F9FA")

private let ColName: CGFloat = 150
private let ColEmail: CGFloat = 180
private let ColPhone: CGFloat = 150
private let ColDob: CGFloat = 150
private let ColAddress: CGFloat = 200
private let ColWorkExp: CGFloat = 200
private let ColSkills: CGFloat = 200
private let ColAction: CGFloat = 150

struct AllContractorsScreen: View {
    var onOpenDrawer: () -> Void
    var onViewContractorDetail: (String) -> Void

    @State private var viewModel = AllContractorsViewModel()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        // Filter button
                        HStack {
                            Button(action: { viewModel.showFilter() }) {
                                HStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(FilterBg)
                                            .frame(width: 30, height: 30)
                                        Text("\u{2195}")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    }
                                    Text("Filter")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(FilterText)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(20)
                                .shadow(radius: 2)
                            }
                            Spacer()
                        }
                        .padding(15)

                        if viewModel.contractors.isEmpty {
                            Spacer()
                            Text("No contractors found")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                            Spacer()
                        } else {
                            // Scrollable table
                            ScrollView(.horizontal, showsIndicators: true) {
                              ScrollView(.vertical, showsIndicators: true) {
                                VStack(alignment: .leading, spacing: 0) {
                                    // Header Row
                                    HStack(spacing: 0) {
                                        ContractorHeaderCell(title: "Name", width: ColName, column: "DisplayName", sortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending, onSort: viewModel.sortBy)
                                        ContractorHeaderCell(title: "Email", width: ColEmail, column: "Email", sortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending, onSort: viewModel.sortBy)
                                        ContractorHeaderCell(title: "Phone Number", width: ColPhone, column: "PhoneNumber", sortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending, onSort: viewModel.sortBy)
                                        ContractorHeaderCell(title: "Date of Birth", width: ColDob, column: "DateofBirthString", sortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending, onSort: viewModel.sortBy)
                                        ContractorHeaderCell(title: "Address", width: ColAddress, column: "Address", sortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending, onSort: viewModel.sortBy)
                                        ContractorHeaderCell(title: "Work Experience", width: ColWorkExp, column: "WorkExperience", sortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending, onSort: viewModel.sortBy)
                                        ContractorHeaderCell(title: "Skills", width: ColSkills, column: "Skills", sortColumn: viewModel.sortColumn, sortAscending: viewModel.sortAscending, onSort: viewModel.sortBy)
                                        // Empty action header
                                        Text("")
                                            .font(.system(size: 14, weight: .bold))
                                            .frame(width: ColAction, height: 40)
                                            .border(HeaderBorderColor, width: 1)
                                    }
                                    .background(Color(hex: "EEEEEE"))

                                    // Data Rows
                                    ForEach(viewModel.contractors, id: \.id) { contractor in
                                        HStack(spacing: 0) {
                                            ContractorDataCell(text: contractor.displayName, width: ColName)
                                            ContractorDataCell(text: contractor.email, width: ColEmail)
                                            ContractorDataCell(text: contractor.phoneNumber, width: ColPhone)
                                            ContractorDataCell(text: viewModel.formatDateOfBirth(contractor.dateOfBirth), width: ColDob)
                                            ContractorDataCell(text: contractor.address, width: ColAddress)
                                            ContractorDataCell(text: contractor.workExperience, width: ColWorkExp)
                                            ContractorDataCell(text: contractor.skills, width: ColSkills)
                                            // View Detail button
                                            ZStack {
                                                Rectangle()
                                                    .stroke(CellBorderColor, lineWidth: 1)
                                                Button(action: { onViewContractorDetail(contractor.id) }) {
                                                    Text("View Detail")
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(FilterText)
                                                }
                                                .frame(height: 30)
                                                .padding(.horizontal, 5)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(Color.black, lineWidth: 1)
                                                )
                                            }
                                            .frame(width: ColAction, height: 50)
                                        }
                                    }
                                }
                                .padding(.horizontal, 15)
                              }
                            }
                        }
                    }
                    .background(BgColor)
            }
            .loadingOverlay(viewModel.isLoading)
            .navigationTitle("All Contractors")
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
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showFilterSheet },
            set: { if !$0 { viewModel.dismissFilter() } }
        )) {
            FilterContractorsSheet(viewModel: viewModel)
        }
        .snackbar(message: $viewModel.errorMessage)
    }
}

// MARK: - Filter Sheet
private struct FilterContractorsSheet: View {
    @Bindable var viewModel: AllContractorsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("FILTER CONTRACTORS")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: { viewModel.dismissFilter() }) {
                    Text("X")
                        .frame(width: 40, height: 40)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }

            Spacer().frame(height: 10)

            // Location search
            TextField("Filter contractors by searched location...", text: Binding(
                get: { viewModel.searchAddress },
                set: { viewModel.onSearchAddressChanged($0) }
            ))
            .textFieldStyle(.roundedBorder)

            if viewModel.showPlaceList && !viewModel.placeList.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.placeList, id: \.placeId) { prediction in
                        Text(prediction.description)
                            .font(.system(size: 15))
                            .foregroundColor(.blue)
                            .padding(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onTapGesture { viewModel.selectPlace(prediction) }
                    }
                }
            }

            Spacer().frame(height: 15)

            Text("Search By Skill: ")
                .font(.system(size: 15))
                .padding(5)
            TextField("Search By Skill...", text: Binding(
                get: { viewModel.searchSkills },
                set: { viewModel.onSearchSkillsChanged($0) }
            ))
            .textFieldStyle(.roundedBorder)

            Spacer().frame(height: 15)

            Text("Search By Name: ")
                .font(.system(size: 15))
                .padding(5)
            TextField("Search By Name...", text: Binding(
                get: { viewModel.searchName },
                set: { viewModel.onSearchNameChanged($0) }
            ))
            .textFieldStyle(.roundedBorder)

            Spacer().frame(height: 10)

            HStack {
                Spacer()
                Button("Clear All") { viewModel.clearFilter() }
                    .foregroundColor(Color(hex: "#FF3B30"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: "#DDDDDD"), lineWidth: 1))
                Button("Apply") { viewModel.applyFilter() }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(5)
                Spacer()
            }

            Spacer().frame(height: 20)
        }
        .padding(15)
    }
}

// MARK: - Helper Views
private struct ContractorHeaderCell: View {
    let title: String
    let width: CGFloat
    let column: String
    let sortColumn: String
    let sortAscending: Bool
    let onSort: (String) -> Void

    var sortIcon: String {
        if sortColumn == column {
            return sortAscending ? "\u{25B2}" : "\u{25BC}"
        }
        return ""
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .lineLimit(1)
            Spacer()
            if !sortIcon.isEmpty {
                Text(sortIcon)
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .padding(.horizontal, 8)
        .frame(width: width, height: 40)
        .clipped()
        .contentShape(Rectangle())
        .overlay(Rectangle().stroke(HeaderBorderColor, lineWidth: 1))
        .onTapGesture { onSort(column) }
    }
}

private struct ContractorDataCell: View {
    let text: String
    let width: CGFloat

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

