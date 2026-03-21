import SwiftUI

private let bgColor = Color(hex: "#F8F9FA")
private let blueLabel = Color(hex: "#4D4BA3")
private let borderStrokeColor = Color(hex: "#667685")
private let orangeStatus = Color(hex: "#FF9500")
private let suggestionBg = Color(hex: "#F8F9FA")
private let suggestionBorder = Color(hex: "#E0E0E0")

struct AddNewLeadScreen: View {
    let onBack: () -> Void
    let onSuccess: () -> Void

    @State private var viewModel = AddNewLeadViewModel()
    @State private var showSnackbar = false
    @State private var snackbarMessage = ""
    @State private var showClientPicker = false
    @State private var showOwnerPicker = false
    @State private var showContractTypePicker = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                // Scrollable form
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        // Select Client
                        AddLeadFieldLabel(emoji: "\u{1F464}", label: "Select Client:")
                        clientPickerView

                        // Project Name
                        AddLeadFieldLabel(emoji: "\u{1F4DD}", label: "Name:")
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Enter Project Name", text: Binding(
                                get: { viewModel.projectName },
                                set: { viewModel.onProjectNameChange($0) }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .padding()
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderStrokeColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            if viewModel.projectName.isEmpty {
                                Text("Project Name Required")
                                    .foregroundColor(.red)
                                    .font(.system(size: 12))
                            }
                        }

                        // Job Description
                        AddLeadFieldLabel(emoji: "\u{1F4DD}", label: "Job Description:")
                        VStack(alignment: .leading, spacing: 4) {
                            TextEditor(text: Binding(
                                get: { viewModel.jobDescription },
                                set: { viewModel.onJobDescriptionChange($0) }
                            ))
                            .font(.system(size: 16))
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderStrokeColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            if viewModel.jobDescription.isEmpty {
                                Text("Job Description Required")
                                    .foregroundColor(.red)
                                    .font(.system(size: 12))
                            }
                        }

                        // Owner
                        ownerPickerView

                        // Contract Type
                        AddLeadFieldLabel(emoji: "\u{1F4CB}", label: "Contract Type:")
                        contractTypePickerView

                        // Location
                        AddLeadFieldLabel(emoji: "\u{1F4CD}", label: "Location:")
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Enter Address", text: Binding(
                                get: { viewModel.searchAddress },
                                set: { viewModel.onSearchAddressChange($0) }
                            ))
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .padding()
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderStrokeColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Address suggestions
                            if viewModel.showPlaceList && !viewModel.placeList.isEmpty {
                                VStack(spacing: 4) {
                                    ForEach(viewModel.placeList, id: \.placeId) { place in
                                        Button(action: { viewModel.selectPlace(place) }) {
                                            Text(place.description)
                                                .font(.system(size: 14))
                                                .foregroundColor(blueLabel)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(10)
                                        }
                                        .background(Color.white)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(suggestionBorder, lineWidth: 1))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                                .padding(10)
                                .background(suggestionBg)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            if viewModel.searchAddress.isEmpty && !viewModel.showPlaceList {
                                Text("Address Required")
                                    .foregroundColor(.red)
                                    .font(.system(size: 12))
                            }
                        }

                        // Cost From Quote
                        AddLeadFieldLabel(emoji: "\u{1F4B5}", label: "Cost From Quote ($):")
                        TextField("Enter Quote Amount", text: Binding(
                            get: { viewModel.costFromQuote },
                            set: { newValue in
                                if newValue.isEmpty || Double(newValue) != nil || newValue == "." {
                                    viewModel.onCostChange(newValue)
                                }
                            }
                        ))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .padding()
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderStrokeColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Status
                        AddLeadFieldLabel(emoji: "\u{1F4CA}", label: "Status:")
                        Text("New Lead")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(orangeStatus)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 2)
                    }
                    .padding(20)
                }

                // Add Lead Button
                Button(action: { viewModel.addLead() }) {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Add Lead")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 150, height: 40)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .disabled(viewModel.isSubmitting)
                .padding(10)
            }
        }
        .background(bgColor)
        .navigationTitle("Add New Lead")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.loadInitialData() }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
            }
        }
        .alert("Success", isPresented: $viewModel.isSuccess) {
            Button("OK") { onSuccess() }
        } message: {
            Text("New Lead created.")
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

    // MARK: - Client Picker
    private var clientPickerView: some View {
        Menu {
            ForEach(viewModel.clients) { client in
                Button(client.name) {
                    viewModel.onClientSelected(client)
                }
            }
        } label: {
            HStack {
                Text(viewModel.selectedClient?.name ?? "Select a Client")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(viewModel.selectedClient != nil ? blueLabel : .gray)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(blueLabel)
            }
            .padding()
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderStrokeColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Owner Picker
    private var ownerPickerView: some View {
        HStack {
            Text("OWNER")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(blueLabel)
                .padding(.trailing, 10)
            Spacer()
            Menu {
                ForEach(viewModel.owners, id: \.id) { owner in
                    Button(owner.displayName) {
                        viewModel.onOwnerSelected(owner)
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.selectedOwner?.displayName ?? "Select Owner")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(blueLabel)
                    Image(systemName: "chevron.down")
                        .foregroundColor(blueLabel)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(radius: 2)
    }

    // MARK: - Contract Type Picker
    private var contractTypePickerView: some View {
        Menu {
            ForEach(Array(contractTypeList.enumerated()), id: \.offset) { index, name in
                Button(name) {
                    viewModel.onContractTypeSelected(index)
                }
            }
        } label: {
            HStack {
                let displayName: String = {
                    if viewModel.selectedContractType > 0 && viewModel.selectedContractType <= contractTypeList.count {
                        return contractTypeList[viewModel.selectedContractType - 1]
                    }
                    return "Select Contract Type"
                }()
                Text(displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(viewModel.selectedContractType > 0 ? blueLabel : .gray)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(blueLabel)
            }
            .padding()
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderStrokeColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Reusable Field Label
struct AddLeadFieldLabel: View {
    let emoji: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(emoji)
                .font(.system(size: 16))
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "#4D4BA3"))
        }
    }
}
