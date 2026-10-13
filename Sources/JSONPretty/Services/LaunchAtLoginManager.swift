import ServiceManagement

/// 开机启动管理：基于 SMAppService（macOS 13+），注册状态由系统持久化。
@MainActor
@Observable
final class LaunchAtLoginManager {
    private(set) var isEnabled: Bool
    private(set) var lastError: String?

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            // 未打包运行时（如 swift run）注册会失败，透出原因
            lastError = error.localizedDescription
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// 用户在系统设置中手动改动后，重新同步状态
    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
