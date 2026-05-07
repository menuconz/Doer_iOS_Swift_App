import Foundation

@Observable
class ContractorDetailsViewModel {
    var isLoading: Bool = true
    var contractor: UserDto? = nil
    var errorMessage: String? = nil

    private let accountRepository: AccountRepository
    private let preferencesManager: PreferencesManager
    private let contractorId: String
    private var hasLoaded = false

    private let displayDateFormat = "dd/MM/yyyy"
    private let parseFormats = [
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm"
    ]

    init(
        contractorId: String,
        accountRepository: AccountRepository = DIContainer.shared.accountRepository,
        preferencesManager: PreferencesManager = DIContainer.shared.preferencesManager
    ) {
        self.contractorId = contractorId
        self.accountRepository = accountRepository
        self.preferencesManager = preferencesManager
    }

    // Android gates this control on admin only — managers cannot toggle the
    // employee flag. Mirror that here so the toggle UI shows for the same role.
    var isCallerAdmin: Bool {
        preferencesManager.isAdmin
    }

    func toggleEmployeeFlag(_ newValue: Bool) {
        guard let current = contractor else { return }
        Task { @MainActor in
            let adminId = preferencesManager.userId
            switch await accountRepository.markAsEmployee(userId: current.id, isEmployee: newValue, adminId: adminId) {
            case .success(let updated):
                contractor = updated
            case .error(let msg, _):
                errorMessage = msg
            case .loading: break
            }
        }
    }

    func loadInitialData() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadContractor()
    }

    private func loadContractor() {
        guard !contractorId.trimmingCharacters(in: .whitespaces).isEmpty else {
            isLoading = false
            errorMessage = "Invalid contractor ID"
            return
        }

        Task { @MainActor in
            isLoading = true
            errorMessage = nil
            let result = await accountRepository.getUser(id: contractorId)
            switch result {
            case .success(let user):
                contractor = user
                isLoading = false
            case .error(let message, _):
                errorMessage = message
                isLoading = false
            case .loading:
                break
            }
        }
    }

    func formatDateOfBirth(_ dateStr: String?) -> String {
        guard let dateStr = dateStr, !dateStr.trimmingCharacters(in: .whitespaces).isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for fmt in parseFormats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: dateStr.trimmingCharacters(in: .whitespaces)) {
                formatter.dateFormat = displayDateFormat
                return formatter.string(from: date)
            }
        }
        let trimmed = dateStr.replacingOccurrences(of: "\\.\\d+$", with: "", options: .regularExpression)
        formatter.dateFormat = parseFormats[0]
        if let date = formatter.date(from: trimmed) {
            formatter.dateFormat = displayDateFormat
            return formatter.string(from: date)
        }
        return dateStr
    }

    func isImageFile(_ fileModel: FileModelDto) -> Bool {
        let ext = (fileModel.name as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "bmp", "webp"].contains(ext)
    }

    func clearError() {
        errorMessage = nil
    }
}
