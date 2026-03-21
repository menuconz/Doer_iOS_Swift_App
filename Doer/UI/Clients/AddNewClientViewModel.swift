import Foundation
import SwiftUI

@Observable
class AddNewClientViewModel {
    var name: String = ""
    var email: String = ""
    var isSaving: Bool = false
    var errorMessage: String? = nil
    var successMessage: String? = nil

    private let clientRepository: ClientRepository
    private let preferencesManager: PreferencesManager

    init(
        clientRepository: ClientRepository = DIContainer.shared.clientRepository,
        preferencesManager: PreferencesManager = DIContainer.shared.preferencesManager
    ) {
        self.clientRepository = clientRepository
        self.preferencesManager = preferencesManager
    }

    func updateName(_ value: String) {
        name = value
    }

    func updateEmail(_ value: String) {
        email = value
    }

    // Matching MAUI AddClient command
    func addClient() {
        // MAUI: ValidateAllProperties -> HasErrors -> "Please Enter Required Feilds." (MAUI typo)
        let hasErrors = name.trimmingCharacters(in: .whitespaces).isEmpty
            || email.trimmingCharacters(in: .whitespaces).isEmpty

        if hasErrors {
            errorMessage = "Please Enter Required Feilds."
            return
        }

        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let userId = preferencesManager.userId
                let basicAuthUid = preferencesManager.basicAuthUid

                var client = ClientDto()
                client.name = name.trimmingCharacters(in: .whitespaces)
                client.email = email.trimmingCharacters(in: .whitespaces)
                client.createdBy = userId
                client.modifiedBy = userId
                client.userId = userId
                client.basicAuthUid = basicAuthUid

                let result = await clientRepository.createNewClient(client: client)
                switch result {
                case .success:
                    isSaving = false
                    successMessage = "New Client created."
                case .error:
                    isSaving = false
                    errorMessage = "Error in creating New Client."
                case .loading:
                    break
                }
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
