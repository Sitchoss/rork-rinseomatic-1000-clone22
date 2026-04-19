import SwiftUI

struct SplitProfileSelectorView: View {
    @Bindable var nordService: NordVPNService
    let height: CGFloat
    let animateIn: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                profileHalf(.nick)
                profileHalf(.poli)
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.82), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3)
                .blur(radius: 1)
                .shadow(color: .white.opacity(0.8), radius: 12)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.18), Color.black.opacity(0.36)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: min(72, height * 0.42))
            .allowsHitTesting(false)
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : -26)
        .sensoryFeedback(.impact(weight: .heavy), trigger: nordService.activeKeyProfile)
    }

    private func profileHalf(_ profile: NordKeyProfile) -> some View {
        let isActive: Bool = nordService.hasSelectedProfile && nordService.activeKeyProfile == profile
        let titleAlignment: HorizontalAlignment = profile == .nick ? .leading : .trailing
        let frameAlignment: Alignment = profile == .nick ? .topLeading : .topTrailing
        let titleSize: CGFloat = height > 160 ? 56 : 48
        let topPadding: CGFloat = max(22, height * 0.14)
        let accentColor: Color = profile == .nick ? Color(red: 0.22, green: 0.72, blue: 1.0) : Color(red: 1.0, green: 0.28, blue: 0.33)

        return Button {
            guard !isActive else { return }
            withAnimation(.spring(duration: 0.3, bounce: 0.18)) {
                nordService.switchProfile(profile)
            }
        } label: {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(isActive ? 0.22 : 0.12)

                LinearGradient(
                    colors: gradientColors(for: profile, isActive: isActive),
                    startPoint: gradientStartPoint(for: profile),
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: [Color.black.opacity(0.38), .clear, Color.black.opacity(isActive ? 0.12 : 0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: titleAlignment, spacing: 10) {
                    Text(profile.rawValue.uppercased())
                        .font(.system(size: titleSize, weight: .black, design: .default))
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .shadow(color: accentColor.opacity(isActive ? 0.95 : 0.55), radius: isActive ? 22 : 12)
                        .shadow(color: .black.opacity(0.65), radius: 6)

                    Text(selectionText(for: profile, isActive: isActive))
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(isActive ? accentColor.opacity(0.96) : .white.opacity(0.72))
                }
                .padding(.horizontal, 22)
                .padding(.top, topPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Use \(profile.rawValue) profile")
        .accessibilityValue(isActive ? "Selected" : "Not selected")
    }

    private func gradientColors(for profile: NordKeyProfile, isActive: Bool) -> [Color] {
        switch profile {
        case .nick:
            return [
                Color(red: 0.06, green: 0.32, blue: 0.86).opacity(isActive ? 0.34 : 0.20),
                Color(red: 0.22, green: 0.72, blue: 1.0).opacity(isActive ? 0.18 : 0.08),
                .clear
            ]
        case .poli:
            return [
                Color(red: 0.90, green: 0.14, blue: 0.24).opacity(isActive ? 0.34 : 0.20),
                Color(red: 1.0, green: 0.38, blue: 0.58).opacity(isActive ? 0.16 : 0.08),
                .clear
            ]
        }
    }

    private func gradientStartPoint(for profile: NordKeyProfile) -> UnitPoint {
        profile == .nick ? .topLeading : .topTrailing
    }

    private func selectionText(for profile: NordKeyProfile, isActive: Bool) -> String {
        if isActive {
            return "ACTIVE PROFILE"
        }
        return nordService.hasSelectedProfile ? "TAP TO SWITCH" : "TAP TO CONTINUE"
    }
}
