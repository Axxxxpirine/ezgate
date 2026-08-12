import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void

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
            Label("This build uses clearly labelled mock traffic until the Network Extension is signed and approved.", systemImage: "hammer")
                .font(.callout)
                .padding(12)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24)
            Button("Continue") { onContinue() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("completeOnboarding")
            Spacer()
        }
        .padding()
    }
}

