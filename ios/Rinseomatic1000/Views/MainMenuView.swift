import SwiftUI

struct MainMenuView: View {
    @Binding var activeMode: ActiveAppMode?
    let requiresProfileSelection: Bool
    @State private var animateIn: Bool = false
    @State private var nordService = NordVPNService.shared
    private let proxyService = ProxyRotationService.shared

    init(activeMode: Binding<ActiveAppMode?>, requiresProfileSelection: Bool = false) {
        _activeMode = activeMode
        self.requiresProfileSelection = requiresProfileSelection
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("MainMenuBG")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                Color.black.opacity(0.3)

                VStack(spacing: 0) {
                    profileSelector(geo: geo)
                        .frame(height: profileSelectorHeight(geo: geo))
                        .padding(.top, geo.safeAreaInsets.top + 4)
                        .padding(.bottom, 4)
                        .zIndex(10)

                    networkModeSelector()
                        .padding(.bottom, 4)
                        .zIndex(9)

                    unifiedSessionZone()
                        .frame(maxHeight: .infinity)

                    HStack(spacing: 0) {
                        dualFindZone()
                        credentialHubZone()
                    }
                    .frame(maxHeight: .infinity)

                    ppsrZone()
                        .frame(maxHeight: .infinity)

                    HStack(spacing: 0) {
                        toolsAndTestingZone()
                        sitchomatic1000Zone()
                    }
                    .frame(maxHeight: .infinity)

                    settingsZone()
                        .frame(maxHeight: .infinity)

                    Spacer().frame(height: geo.safeAreaInsets.bottom + 4)
                }

                ghostTrigger(geo: geo)

                VStack {
                    Spacer()

                    HStack {
                        Spacer()
                        Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.15))
                            .padding(.trailing, 16)
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom + 6)
                }
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.12)) {
                animateIn = true
            }
        }
        .onDisappear {
            animateIn = false
        }
    }

    private func profileSelector(geo: GeometryProxy) -> some View {
        SplitProfileSelectorView(
            nordService: nordService,
            height: profileSelectorHeight(geo: geo),
            animateIn: animateIn
        )
    }

    private func profileSelectorHeight(geo: GeometryProxy) -> CGFloat {
        let availableHeight: CGFloat = geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom
        return min(max(availableHeight * 0.23, 170), 232)
    }

    private func unifiedSessionZone() -> some View {
        MainMenuItemCard(
            mode: .unifiedSession,
            activeMode: $activeMode,
            canEnterModes: canEnterModes,
            animateIn: animateIn,
            colors: [.green.opacity(0.12), .orange.opacity(0.12)],
            sensoryWeight: .heavy,
            yOffset: -20
        ) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "suit.spade.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.green)
                            .symbolEffect(.pulse, options: .repeating.speed(0.4))
                            .shadow(color: .green.opacity(0.6), radius: 10)
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.4))
                        Image(systemName: "flame.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.orange)
                            .symbolEffect(.pulse, options: .repeating.speed(0.4))
                            .shadow(color: .orange.opacity(0.6), radius: 10)
                    }

                    Text("UNIFIED\nSESSIONS")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineSpacing(2)
                        .shadow(color: .black.opacity(0.8), radius: 4)

                    Text("JoePoint + Ignition Lite · Paired Testing")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))

                    Text("V4.1 · 4 Workers · Early-Stop Sync")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.leading, 20)

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Image(systemName: "rectangle.split.2x1.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [.green, .orange], startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: .green.opacity(0.3), radius: 8)

                    HStack(spacing: 3) {
                        Text("LAUNCH")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.trailing, 20)
            }
        }
    }

    private func dualFindZone() -> some View {
        MainMenuItemCard(
            mode: .dualFind,
            activeMode: $activeMode,
            canEnterModes: canEnterModes,
            animateIn: animateIn,
            colors: [.purple.opacity(0.15), .indigo.opacity(0.2)],
            sensoryWeight: .medium,
            xOffset: -30
        ) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.purple)
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.indigo)
                    }
                    .shadow(color: .purple.opacity(0.5), radius: 8)

                    Text("DUAL FIND")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4)

                    Text("Email × 3 Passwords")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.purple.opacity(0.7))

                    HStack(spacing: 3) {
                        Text("FIND")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.purple.opacity(0.6))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundStyle(.purple.opacity(0.4))
                    }
                }
                .padding(.leading, 20)

                Spacer()
            }
        }
    }

    private func credentialHubZone() -> some View {
        MainMenuItemCard(
            mode: .credentialHub,
            activeMode: $activeMode,
            canEnterModes: canEnterModes,
            animateIn: animateIn,
            colors: [.green.opacity(0.16), .mint.opacity(0.1)],
            sensoryWeight: .medium,
            xOffset: 30
        ) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.rectangle.stack.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.green)
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.mint)
                    }
                    .shadow(color: .green.opacity(0.4), radius: 8)

                    Text("CREDENTIAL HUB")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4)

                    Text("Dashboard · Import · Saved · Working · Sessions")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.leading, 20)

                Spacer()
            }
        }
    }

    private func ppsrZone() -> some View {
        MainMenuItemCard(
            mode: .ppsr,
            activeMode: $activeMode,
            canEnterModes: canEnterModes,
            animateIn: animateIn,
            colors: [.cyan.opacity(0.2), .blue.opacity(0.05)],
            sensoryWeight: .medium,
            yOffset: 30
        ) {
            HStack(spacing: 14) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.cyan)
                    .shadow(color: .cyan.opacity(0.5), radius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("CARD")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4)

                    Text("TESTING")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)
                        .shadow(color: .cyan.opacity(0.4), radius: 4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("PPSR, BPOINT & WA REGO")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.cyan.opacity(0.6))

                    HStack(spacing: 3) {
                        Text("ENTER")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.cyan.opacity(0.6))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundStyle(.cyan.opacity(0.4))
                    }
                }
            }
            .padding(.leading, 20)
        }
    }

    private func toolsAndTestingZone() -> some View {
        MainMenuItemCard(
            mode: .toolsAndTesting,
            activeMode: $activeMode,
            canEnterModes: canEnterModes,
            animateIn: animateIn,
            colors: [Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.4), Color(red: 0.2, green: 0.3, blue: 0.5).opacity(0.3)],
            sensoryWeight: .medium,
            yOffset: 30
        ) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Image(systemName: "flask.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.orange.opacity(0.7))
                    }
                    .shadow(color: .orange.opacity(0.4), radius: 8)

                    Text("TOOLS & TESTING")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4)

                    Text("Super Test · Debug · Nord · Recorder")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.leading, 20)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "flask.fill")
                        Image(systemName: "network")
                        Image(systemName: "brain.head.profile.fill")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))

                    HStack(spacing: 3) {
                        Text("OPEN")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 7, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.trailing, 20)
            }
        }
    }

    private func sitchomatic1000Zone() -> some View {
        MainMenuItemCard(
            mode: .sitchomatic1000,
            activeMode: $activeMode,
            canEnterModes: canEnterModes,
            animateIn: animateIn,
            colors: [Color.red.opacity(0.2), Color.black.opacity(0.4)],
            sensoryWeight: .heavy,
            xOffset: 30
        ) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.red)
                            .shadow(color: .red.opacity(0.6), radius: 8)
                        Image(systemName: "record.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.red.opacity(0.7))
                            .symbolEffect(.pulse, options: .repeating.speed(0.5))
                    }

                    Text("SITCHOMATIC")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4)
                    Text("1000")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.red)
                        .shadow(color: .red.opacity(0.4), radius: 4)

                    Text("CCTV · Custom URLs · Flows")
                        .font(.system(size: 7, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.leading, 20)

                Spacer()
            }
        }
    }

    private func settingsZone() -> some View {
        MainMenuItemCard(
            mode: .settings,
            activeMode: $activeMode,
            canEnterModes: canEnterModes,
            animateIn: animateIn,
            colors: [Color(.secondarySystemBackground).opacity(0.35), connectionModeColor.opacity(0.22)],
            sensoryWeight: .medium,
            xOffset: 30
        ) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(connectionModeColor)
                        .shadow(color: connectionModeColor.opacity(0.4), radius: 8)

                    Text("SETTINGS")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4)

                    Text("Automation · URLs · Network · Vault")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))


                }
                .padding(.leading, 20)

                Spacer()
            }
        }
    }

    private func ghostTrigger(geo: GeometryProxy) -> some View {
        Color.clear
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .onTapGesture(count: 3) {
                openCustomSitch()
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 1.1)
                    .onEnded { _ in
                        openCustomSitch()
                    }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, geo.safeAreaInsets.top + 4)
            .padding(.trailing, 4)
    }

    private func openCustomSitch() {
        guard canEnterModes else { return }
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            activeMode = .customSitch
        }
    }

    private func networkModeSelector() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ConnectionMode.allCases, id: \.self) { mode in
                    let isActive = proxyService.unifiedConnectionMode == mode
                    let modeColor = color(for: mode)

                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                            proxyService.setUnifiedConnectionMode(mode)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 10, weight: .bold))
                            Text(mode.label.uppercased())
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .foregroundStyle(isActive ? .white : .white.opacity(0.55))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            if isActive {
                                Capsule()
                                    .fill(modeColor.opacity(0.7))
                                    .shadow(color: modeColor.opacity(0.5), radius: 8)
                            } else {
                                Capsule()
                                    .fill(.white.opacity(0.08))
                                    .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .contentMargins(.horizontal, 0)
        .sensoryFeedback(.impact(weight: .medium), trigger: proxyService.unifiedConnectionMode)
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : -10)
    }

    private func color(for mode: ConnectionMode) -> Color {
        switch mode {
        case .direct: .green
        case .proxy: .blue
        case .openvpn: .indigo
        case .wireguard: .purple
        case .dns: .cyan
        case .nodeMaven: .teal
        }
    }

    private var connectionModeColor: Color {
        color(for: proxyService.unifiedConnectionMode)
    }

    private var canEnterModes: Bool {
        !requiresProfileSelection || nordService.hasSelectedProfile
    }

}

struct MainMenuItemCard<Content: View>: View {
    let mode: ActiveAppMode
    @Binding var activeMode: ActiveAppMode?
    let canEnterModes: Bool
    let animateIn: Bool
    let colors: [Color]
    let sensoryWeight: SensoryFeedback.Weight
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button {
            guard canEnterModes else { return }
            withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                activeMode = mode
            }
        } label: {
            ZStack(alignment: .leading) {
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                content()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(animateIn ? (canEnterModes ? 1 : 0.35) : 0)
        .offset(x: animateIn ? 0 : xOffset, y: animateIn ? 0 : yOffset)
        .allowsHitTesting(canEnterModes)
        .sensoryFeedback(.impact(weight: sensoryWeight), trigger: activeMode == mode)
    }
}
