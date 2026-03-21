import SwiftUI

private let bgColor = Color(hex: "#F8F9FA")
private let blueLabel = Color(hex: "#4D4BA3")
private let borderStrokeColor = Color(hex: "#667685")

struct AddNewClientScreen: View {
    let onBack: () -> Void
    let onSuccess: () -> Void

    @State private var viewModel = AddNewClientViewModel()
    @State private var showSnackbar = false
    @State private var snackbarMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Client Name Section
                NewClientFieldLabel(emoji: "\u{1F464}", label: "Client Name:")
                Spacer().frame(height: 10)
                NewClientBorderedEntryField(
                    value: $viewModel.name,
                    placeholder: "Enter Client Name",
                    height: 55
                )

                Spacer().frame(height: 15)

                // Client Email Section
                NewClientFieldLabel(emoji: "\u{1F4E7}", label: "Client Email:")
                Spacer().frame(height: 10)
                NewClientBorderedEntryField(
                    value: $viewModel.email,
                    placeholder: "Enter Client Email",
                    height: 55
                )

                Spacer().frame(height: 20)

                // "Add Client" button centered
                HStack {
                    Spacer()
                    Button(action: { viewModel.addClient() }) {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Add Client")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 150, height: 40)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .disabled(viewModel.isSaving)
                    Spacer()
                }
            }
            .padding(20)
        }
        .background(bgColor)
        .navigationTitle("New Client")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
            }
        }
        // Success popup
        .alert("Success", isPresented: Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 {
                viewModel.clearSuccess()
            }}
        )) {
            Button("OK") {
                viewModel.clearSuccess()
                onSuccess()
            }
        } message: {
            Text(viewModel.successMessage ?? "")
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

// MARK: - New Client Components

private struct NewClientFieldLabel: View {
    let emoji: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(emoji)
                .font(.system(size: 16))
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(blueLabel)
        }
    }
}

private struct NewClientBorderedEntryField: View {
    @Binding var value: String
    let placeholder: String
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            TextField(placeholder, text: $value)
                .font(.system(size: 16))
                .padding(.horizontal, 5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderStrokeColor, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }
}
