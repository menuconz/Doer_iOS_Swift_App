import Foundation
import SwiftUI

@Observable
class ClientsViewModel {
    var isLoading: Bool = true
    var clients: [ClientDto] = []
    var sortColumn: String = ""
    var sortAscending: Bool = true
    var errorMessage: String? = nil
    var successMessage: String? = nil
    // Edit bottom sheet
    var editingClient: ClientDto? = nil
    var fieldName: String = ""
    var editorTitle: String = "Edit Field"
    var editorText: String = ""
    var isSaving: Bool = false
    // Delete dialog
    var deletingClient: ClientDto? = nil
    var isDeleting: Bool = false
    // Projects bottom sheet
    var projectsClient: ClientDto? = nil
    var projectJobs: [ClientJobDto] = []
    var filteredJobs: [ClientJobDto] = []
    var searchText: String = ""
    var isLoadingProjects: Bool = false
    var isSavingProjects: Bool = false

    private let clientRepository: ClientRepository
    private let preferencesManager: PreferencesManager
    private var hasLoaded = false

    init(
        clientRepository: ClientRepository = DIContainer.shared.clientRepository,
        preferencesManager: PreferencesManager = DIContainer.shared.preferencesManager
    ) {
        self.clientRepository = clientRepository
        self.preferencesManager = preferencesManager
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadClients()
    }

    func refreshData() {
        loadClients()
    }

    func loadClients() {
        Task { @MainActor in
            isLoading = true
            errorMessage = nil

            let result = await clientRepository.getAllClients()
            switch result {
            case .success(let data):
                if data.isEmpty {
                    isLoading = false
                    clients = []
                    errorMessage = "No Clients found."
                } else {
                    isLoading = false
                    clients = data
                }
            case .error(let message, _):
                isLoading = false
                errorMessage = message
            case .loading:
                break
            }
        }
    }

    func sortBy(_ column: String) {
        let ascending = (sortColumn == column) ? !sortAscending : true
        let sorted = clients.sorted { a, b in
            let valA: String
            let valB: String
            switch column {
            case "Name": valA = a.name.lowercased(); valB = b.name.lowercased()
            case "Email": valA = a.email.lowercased(); valB = b.email.lowercased()
            default: valA = ""; valB = ""
            }
            return ascending ? valA < valB : valA > valB
        }
        clients = sorted
        sortColumn = column
        sortAscending = ascending
    }

    // MARK: - Edit bottom sheet

    func editClientName(_ client: ClientDto) {
        editFieldInternal(client, fieldName: "Client Name")
    }

    func editClientEmail(_ client: ClientDto) {
        editFieldInternal(client, fieldName: "Client Email")
    }

    private func editFieldInternal(_ client: ClientDto, fieldName: String) {
        let value: String
        switch fieldName {
        case "Client Name": value = client.name
        case "Client Email": value = client.email
        default: value = ""
        }
        editingClient = client
        self.fieldName = fieldName
        editorTitle = fieldName
        editorText = value
    }

    func updateEditorText(_ value: String) {
        editorText = value
    }

    func dismissEditSheet() {
        editingClient = nil
        fieldName = ""
        editorText = ""
    }

    func saveEdit() {
        guard var client = editingClient, !fieldName.isEmpty else { return }

        switch fieldName {
        case "Client Name": client.name = editorText
        case "Client Email": client.email = editorText
        default: break
        }

        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            let userId = preferencesManager.userId
            client.modifiedBy = userId

            let result = await clientRepository.updateClient(client: client)
            switch result {
            case .success:
                isSaving = false
                editingClient = nil
                fieldName = ""
                editorText = ""
                loadClients()
            case .error(let message, _):
                isSaving = false
                errorMessage = message.isEmpty ? "There was a problem in Updating Client Details" : message
            case .loading:
                break
            }
        }
    }

    // MARK: - Delete dialog

    func openDeleteDialog(_ client: ClientDto) {
        deletingClient = client
    }

    func dismissDeleteDialog() {
        deletingClient = nil
    }

    func confirmDelete() {
        guard let client = deletingClient else { return }
        isDeleting = true
        errorMessage = nil

        Task { @MainActor in
            let result = await clientRepository.deleteClientById(id: client.id)
            switch result {
            case .success:
                isDeleting = false
                deletingClient = nil
                successMessage = "The client has been successfully deleted."
                loadClients()
            case .error:
                isDeleting = false
                deletingClient = nil
                errorMessage = "Failed to delete the Client. Please try again later."
            case .loading:
                break
            }
        }
    }

    // MARK: - Projects bottom sheet

    func viewClientProjects(_ client: ClientDto) {
        projectsClient = client
        projectJobs = []
        filteredJobs = []
        searchText = ""
        isLoadingProjects = true

        Task { @MainActor in
            var existingJobs = client.jobs.map { job in
                var j = job
                j.originalIsAssigned = j.isAssigned
                return j
            }

            let result = await clientRepository.getUnassignedJobs()
            switch result {
            case .success(let data):
                let unassigned = data.filter { uj in
                    !existingJobs.contains(where: { $0.id == uj.id })
                }.map { job in
                    var j = job
                    j.isAssigned = false
                    j.originalIsAssigned = false
                    return j
                }
                let allJobs = existingJobs + unassigned
                isLoadingProjects = false
                projectJobs = allJobs
                filteredJobs = allJobs
            case .error:
                isLoadingProjects = false
                projectJobs = existingJobs
                filteredJobs = existingJobs
            case .loading:
                break
            }
        }
    }

    func dismissProjectsSheet() {
        projectsClient = nil
        projectJobs = []
        filteredJobs = []
        searchText = ""
    }

    func onSearchTextChange(_ value: String) {
        searchText = value
        filterProjects()
    }

    private func filterProjects() {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            filteredJobs = projectJobs
        } else {
            let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            filteredJobs = projectJobs.filter { $0.projectName.lowercased().contains(query) }
        }
    }

    func toggleJobAssignment(_ job: ClientJobDto) {
        if let index = projectJobs.firstIndex(where: { $0.id == job.id }) {
            projectJobs[index].isAssigned.toggle()
            filterProjects()
        }
    }

    func saveProjectAssignments() {
        guard let client = projectsClient else { return }
        let changedJobs = projectJobs.filter { $0.isAssigned != $0.originalIsAssigned }

        if changedJobs.isEmpty {
            successMessage = "Nothing to update."
            dismissProjectsSheet()
            return
        }

        isSavingProjects = true
        errorMessage = nil

        Task { @MainActor in
            for job in changedJobs {
                let clientId = job.isAssigned ? client.id : 0
                let result = await clientRepository.assignClientToJob(shiftId: job.id, clientId: clientId)
                if case .error(let message, _) = result {
                    isSavingProjects = false
                    errorMessage = "Failed to update: \(job.projectName)"
                    return
                }
            }
            isSavingProjects = false
            successMessage = "Projects Updated"
            dismissProjectsSheet()
            loadClients()
        }
    }

    func clearError() { errorMessage = nil }
    func clearSuccess() { successMessage = nil }
}
