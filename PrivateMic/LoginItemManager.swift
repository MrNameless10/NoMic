import Foundation
import ServiceManagement

enum LoginItemState: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

protocol LoginItemManaging: AnyObject {
    var state: LoginItemState { get }
    func setEnabled(_ enabled: Bool) throws
}

final class LoginItemManager: LoginItemManaging {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var state: LoginItemState {
        switch service.status {
        case .notRegistered: return .disabled
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .unavailable
        @unknown default: return .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if service.status == .notRegistered { try service.register() }
        } else if service.status != .notRegistered {
            try service.unregister()
        }
    }
}
