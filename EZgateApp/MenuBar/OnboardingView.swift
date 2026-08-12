import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Welcome to EZgate").font(.title2.weight(.semibold))
                Text("Simple network control for macOS.")
                    .font(.headline).foregroundStyle(.secondary)
            }
            Text("EZgate observes connection metadata so it can show which apps use your bandwidth and let you control their access. All data stays on this Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 36)
            Label(model.filterController.status.label, systemImage: "network.badge.shield.half.filled")
                .font(.callout)
                .padding(12)
                .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24)
            Button(model.filterController.status.isActive ? "Continue" : "Install Network Filter") {
                if model.filterController.status.isActive {
                    model.completeOnboarding()
                } else {
                    model.activateFilter()
                }
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("completeOnboarding")
            if model.filterController.status == .awaitingApproval {
                Text("Approve EZgate in System Settings → General → Login Items & Extensions, then return here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            Spacer()
        }
        .padding()
    }
}
