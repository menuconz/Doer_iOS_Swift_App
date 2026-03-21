import Foundation

struct TeamUserItem: Identifiable {
    let user: UserDto
    var isInTeam: Bool = false

    var id: String { user.id }
}

@Observable
class FiloKretoTeamViewModel {
    var isLoading: Bool = true
    var isSaving: Bool = false
    var users: [TeamUserItem] = []
    var searchQuery: String = ""
    var filteredUsers: [TeamUserItem] = []
    var errorMessage: String? = nil
    var successMessage: String? = nil

    private let accountRepository: AccountRepository
    private var hasLoaded = false

    init(accountRepository: AccountRepository = DIContainer.shared.accountRepository) {
        self.accountRepository = accountRepository
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadData()
    }

    private func loadData() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil

            // Load all users and team members (matching MAUI LoadUsersAsync)
            let allUsersResult = await accountRepository.getAllUsersWithAdmin()
            let teamResult = await accountRepository.getAllFiloKretoTeam()

            switch (allUsersResult, teamResult) {
            case (.success(let allUsers), .success(let teamUsers)):
                let teamIds = Set(teamUsers.map { $0.id })

                let userItems = allUsers.map { user in
                    TeamUserItem(
                        user: user,
                        isInTeam: teamIds.contains(user.id)
                    )
                }

                users = userItems
                filteredUsers = userItems
                isLoading = false

            case (.error(let message, _), _):
                errorMessage = message
                isLoading = false

            case (_, .error(let message, _)):
                errorMessage = message
                isLoading = false

            default:
                isLoading = false
            }
        }
    }

    func updateSearch(_ query: String) {
        searchQuery = query
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            filteredUsers = users
        } else {
            filteredUsers = users.filter {
                $0.user.displayName.localizedCaseInsensitiveContains(query)
            }
        }
    }

    func toggleTeamMembership(_ userId: String) {
        users = users.map { item in
            if item.user.id == userId {
                return TeamUserItem(user: item.user, isInTeam: !item.isInTeam)
            }
            return item
        }
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            filteredUsers = users
        } else {
            filteredUsers = users.filter {
                $0.user.displayName.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }

    // Matching MAUI SaveChanges: re-fetches current team before computing diff
    func saveChanges() {
        guard !users.isEmpty else {
            errorMessage = "No users found to update."
            return
        }

        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            // MAUI re-fetches the current team to compute accurate diff
            let currentTeamResult = await accountRepository.getAllFiloKretoTeam()
            let currentTeamIds: Set<String>
            switch currentTeamResult {
            case .success(let teamUsers):
                currentTeamIds = Set(teamUsers.map { $0.id })
            case .error(_, _):
                isSaving = false
                errorMessage = "Unable to update team. Please try again later."
                return
            case .loading:
                isSaving = false
                return
            }

            let selectedIds = Set(users.filter { $0.isInTeam }.map { $0.user.id })

            let toAdd = Array(selectedIds.subtracting(currentTeamIds))
            let toRemove = currentTeamIds.filter { id in
                !users.contains(where: { $0.isInTeam && $0.user.id == id })
            }

            if toAdd.isEmpty && toRemove.isEmpty {
                isSaving = false
                successMessage = "No updates to apply."
                return
            }

            var addSuccess = true
            var removeSuccess = true

            if !toAdd.isEmpty {
                let result = await accountRepository.addUsersToFiloKretoTeam(userIds: toAdd)
                if case .error(_, _) = result {
                    addSuccess = false
                }
            }

            if !toRemove.isEmpty {
                let result = await accountRepository.removeUsersFromFiloKretoTeam(userIds: Array(toRemove))
                if case .error(_, _) = result {
                    removeSuccess = false
                }
            }

            // Match MAUI messaging
            let message: String
            switch (addSuccess, removeSuccess) {
            case (true, true):
                message = "FiloKreto Team updated successfully!"
            case (false, false):
                message = "Unable to update the FiloKreto Team. Please try again later."
            case (false, true):
                message = "Some users could not be added to the FiloKreto Team."
            case (true, false):
                message = "Some users could not be removed from the FiloKreto Team."
            }

            isSaving = false
            if addSuccess || removeSuccess {
                successMessage = message
            } else {
                errorMessage = message
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func clearSuccess() {
        successMessage = nil
    }
}
