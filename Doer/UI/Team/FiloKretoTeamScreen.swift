import SwiftUI

private let BlueAccent = Color(hex: "#007AFF")

struct FiloKretoTeamScreen: View {
    var onOpenDrawer: () -> Void

    @State private var viewModel = FiloKretoTeamViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Main layout matching MAUI: Grid Padding="20" RowSpacing="10"
            VStack(spacing: 10) {
                // Search bar - matching MAUI SearchBar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search users...", text: Binding(
                        get: { viewModel.searchQuery },
                        set: { viewModel.updateSearch($0) }
                    ))
                }
                .padding(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )

                if viewModel.filteredUsers.isEmpty && !viewModel.isLoading {
                    Spacer()
                    Text("No users found")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                    Spacer()
                } else {
                    // User list matching MAUI CollectionView
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.filteredUsers) { item in
                                // MAUI: Grid Padding="10, 7, 15, 7" ColumnDefinitions="Auto,*,Auto"
                                HStack {
                                    // MAUI: Label Grid.Column="1" FontAttributes="Bold" Margin="10,0,0,0"
                                    Text(item.user.displayName)
                                        .fontWeight(.bold)
                                        .padding(.leading, 10)

                                    Spacer()

                                    // MAUI: CheckBox Grid.Column="2" IsChecked="{Binding IsInFiloKretoTeam}"
                                    Toggle("", isOn: Binding(
                                        get: { item.isInTeam },
                                        set: { _ in viewModel.toggleTeamMembership(item.user.id) }
                                    ))
                                    .toggleStyle(CheckboxToggleStyle())
                                }
                                .padding(.init(top: 7, leading: 10, bottom: 7, trailing: 15))
                            }
                        }
                    }
                }

                // MAUI: Button Margin="0,10,0,10" HeightRequest="50" CornerRadius="10" BackgroundColor="#007AFF"
                Button(action: { viewModel.saveChanges() }) {
                    if viewModel.isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("SAVE CHANGES")
                            .fontWeight(.bold)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background((!viewModel.isSaving && !viewModel.isLoading) ? BlueAccent : BlueAccent.opacity(0.5))
                .cornerRadius(10)
                .disabled(viewModel.isSaving || viewModel.isLoading)
                .padding(.vertical, 10)
            }
            .padding(20)
        }
        .loadingOverlay(viewModel.isLoading)
        .navigationTitle("FiloKreto Team")
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
        .snackbar(message: Binding(
            get: { viewModel.errorMessage ?? viewModel.successMessage },
            set: { _ in viewModel.clearError(); viewModel.clearSuccess() }
        ))
    }
}

// MARK: - Checkbox Toggle Style
private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: 22))
                .foregroundColor(configuration.isOn ? Color(hex: "#007AFF") : .gray)
        }
        .buttonStyle(.plain)
    }
}
