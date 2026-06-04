import AppKit

/// Shim that reuses the onboarding window's Accessibility step instead of presenting a separate
/// gate UI. Coordinator calls `presentIfNeeded(coordinator:)` when auto-paste is enabled but the
/// OS hasn't granted Accessibility yet.
@MainActor
enum AccessibilityGate {
    /// Returns true if the onboarding window was presented (caller should bail / not proceed).
    @discardableResult
    static func presentIfNeeded(coordinator: AppCoordinator) -> Bool {
        guard !AccessibilityPermissionHelper.isGranted else { return false }
        OnboardingWindowPresenter.shared.present(coordinator: coordinator,
                                                 force: true,
                                                 initialStep: .accessibility)
        return true
    }
}
