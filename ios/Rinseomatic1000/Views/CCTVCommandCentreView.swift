import SwiftUI

struct CCTVCommandCentreView: View {
    @State private var vm = CCTVCommandCentreViewModel()
    @State private var sitchVM = Sitchomatic1000ViewModel.shared
    @State private var pulse: Bool = false

    private var hasAnyWindows: Bool {
        !sitchVM.entries.isEmpty
    }

    private var hasActiveWindows: Bool {
        !vm.selectableEntries.isEmpty
    }

    private var shouldShowWarning: Bool {
        !vm.startBlockers.isEmpty && !vm.isRunning && vm.selectionCount > 0
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.05, blue: 0.07), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                topBar

                if shouldShowWarning {
                    warningBanner
                }

                if vm.isRunning {
                    runningGrid
                } else {
                    selectionPhase
                }
            }
            .padding(14)
        }
        .navigationTitle("Command Centre")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear {
            pulse = true
            vm.pruneSelection()
        }
        .onDisappear {
            vm.resetSession()
        }
        .onChange(of: sitchVM.entries) { _, _ in
            vm.pruneSelection()
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            counterBadge
            Spacer()
            startStopButton
        }
    }

    private var counterBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.caption.weight(.bold))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vm.selectionCount)/\(CCTVCommandCentreViewModel.maxSlots) selected")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                Text("\(vm.selectableEntries.count) active windows")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }

    private var startStopButton: some View {
        Button {
            if vm.isRunning {
                vm.stopAll()
            } else {
                vm.startAll()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: vm.isRunning ? "stop.fill" : "play.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .symbolEffect(.pulse, options: .repeating, isActive: vm.isRunning)
                Text(vm.isRunning ? "STOP ALL" : "START ALL")
                    .font(.system(.subheadline, design: .monospaced, weight: .heavy))
                    .tracking(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(vm.isRunning ? Color.red : (vm.canStart ? Color.green : Color.gray.opacity(0.4)))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(pulse && !vm.isRunning && vm.canStart ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
        }
        .buttonStyle(.plain)
        .disabled(!vm.isRunning && !vm.canStart)
    }

    private var warningBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.title3)
            VStack(alignment: .leading, spacing: 6) {
                Text("Start blocked")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text("Every selected window needs an assigned flow and at least one credential.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(vm.startBlockers, id: \.self) { blocker in
                    Text(blocker)
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.red.opacity(0.6), lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 14))
    }

    private var selectionPhase: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                selectionHeaderCard

                if !hasAnyWindows {
                    emptyState(
                        icon: "rectangle.stack.badge.plus",
                        title: "No windows yet",
                        message: "Add custom URL windows first, then come back to select up to 7 for concurrent automation."
                    )
                } else if !hasActiveWindows {
                    emptyState(
                        icon: "video.slash.fill",
                        title: "No active windows",
                        message: "Only active custom URL windows can be selected here. Turn a window on in the CCTV dashboard, then return to command centre."
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(vm.selectableEntries) { entry in
                            selectionTile(entry)
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var selectionHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select up to 7 live windows")
                        .font(.system(.title3, design: .monospaced, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("Slot 1 becomes the large top feed. Slots 2–7 fill the 2×3 grid below. Start runs every selected window at the same time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("ACTIVE ONLY")
                    .font(.system(.caption2, design: .monospaced, weight: .heavy))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                infoPill(title: "Selected", value: "\(vm.selectionCount)", tint: .blue)
                infoPill(title: "Active", value: "\(vm.selectableEntries.count)", tint: .green)
                infoPill(title: "Ready", value: vm.canStart ? "YES" : "NO", tint: vm.canStart ? .green : .orange)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func selectionTile(_ entry: Sitchomatic1000Entry) -> some View {
        let selected = vm.isSelected(entry.id)
        let number = vm.slotNumber(for: entry.id)
        let selectionLocked = vm.selectionCount >= CCTVCommandCentreViewModel.maxSlots && !selected

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                vm.toggleSelection(entry.id)
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? .blue : .secondary)
                    Spacer()
                    if let number {
                        Text("\(number)")
                            .font(.system(.caption, design: .monospaced, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.blue))
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(entry.label)
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(entry.url)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    statusChip(icon: entry.hasFlow ? "record.circle.fill" : "record.circle", text: entry.assignedFlowName ?? "No Flow", tint: entry.hasFlow ? .green : .orange)
                    statusChip(icon: "key.fill", text: "\(entry.credentialList.count) cred\(entry.credentialList.count == 1 ? "" : "s")", tint: entry.hasCredentials ? .cyan : .orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.white.opacity(selected ? 0.12 : 0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selected ? Color.blue : Color.white.opacity(0.08), lineWidth: selected ? 2 : 1)
            )
            .clipShape(.rect(cornerRadius: 16))
            .opacity(selectionLocked ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(selectionLocked)
    }

    @ViewBuilder
    private var runningGrid: some View {
        GeometryReader { geo in
            let bigHeight = max(geo.size.height * 0.55, 260)
            let smalls = Array(vm.slots.dropFirst())

            VStack(spacing: 10) {
                if let big = vm.slots.first {
                    slotTile(slot: big, index: 0, isBig: true)
                        .frame(height: bigHeight)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(Array(smalls.enumerated()), id: \.element.id) { offset, slot in
                        slotTile(slot: slot, index: offset + 1, isBig: false)
                            .aspectRatio(0.9, contentMode: .fit)
                    }
                }
            }
        }
    }

    private func slotTile(slot: CCTVCommandCentreViewModel.Slot, index: Int, isBig: Bool) -> some View {
        let entry = currentEntry(for: slot)
        let corner: CGFloat = isBig ? 20 : 14

        return Button {
            guard !isBig else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                vm.promoteToBig(slotIndex: index)
            }
        } label: {
            Color.black
                .overlay {
                    CCTVSlotWebView(webView: slot.webView)
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: corner))
                .overlay(alignment: .topLeading) {
                    Text("\(index + 1)")
                        .font(.system(.caption2, design: .monospaced, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.black.opacity(0.75)))
                        .padding(6)
                }
                .overlay(alignment: .topTrailing) {
                    statusBadge(slot.status)
                        .padding(6)
                }
                .overlay(alignment: .bottom) {
                    bottomOverlay(slot: slot, entry: entry, isBig: isBig)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(borderColor(slot.status), lineWidth: isBig ? 2 : 1.2)
                        .shadow(color: glowColor(slot.status), radius: isBig ? 8 : 4)
                )
        }
        .buttonStyle(.plain)
    }

    private func bottomOverlay(slot: CCTVCommandCentreViewModel.Slot, entry: Sitchomatic1000Entry?, isBig: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(entry?.label ?? "—")
                    .font(.system(isBig ? .caption : .caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(slot.completedCredentialCount)/\(max(slot.credentialCount, 1))")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(slot.activeCredentialEmail.isEmpty ? "(no credential)" : slot.activeCredentialEmail)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.cyan)
                .lineLimit(1)

            if slot.totalSteps > 0 {
                Text("Step \(slot.currentStep)/\(slot.totalSteps)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if !slot.resultMessage.isEmpty {
                Text(slot.resultMessage)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(LinearGradient(colors: [.black.opacity(0.92), .black.opacity(0.22)], startPoint: .bottom, endPoint: .top))
    }

    @ViewBuilder
    private func statusBadge(_ status: CCTVCommandCentreViewModel.SlotStatus) -> some View {
        switch status {
        case .idle:
            badge("IDLE", color: .gray)
        case .loading:
            badge("LOAD", color: .yellow)
        case .running:
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                Text("LIVE")
            }
            .font(.system(.caption2, design: .monospaced, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.75))
            .clipShape(Capsule())
        case .done:
            badge("DONE", color: .green)
        case .error:
            badge("ERROR", color: .red)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(.caption2, design: .monospaced, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.85))
            .clipShape(Capsule())
    }

    private func infoPill(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .heavy))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func statusChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }

    private func currentEntry(for slot: CCTVCommandCentreViewModel.Slot) -> Sitchomatic1000Entry? {
        sitchVM.entries.first(where: { $0.id == slot.entryId })
    }

    private func borderColor(_ status: CCTVCommandCentreViewModel.SlotStatus) -> Color {
        switch status {
        case .running:
            return Color.green.opacity(0.9)
        case .done:
            return Color.green.opacity(0.6)
        case .error:
            return Color.red.opacity(0.8)
        case .loading:
            return Color.yellow.opacity(0.6)
        case .idle:
            return Color.white.opacity(0.12)
        }
    }

    private func glowColor(_ status: CCTVCommandCentreViewModel.SlotStatus) -> Color {
        switch status {
        case .running:
            return Color.green.opacity(0.5)
        case .error:
            return Color.red.opacity(0.5)
        default:
            return .clear
        }
    }
}
