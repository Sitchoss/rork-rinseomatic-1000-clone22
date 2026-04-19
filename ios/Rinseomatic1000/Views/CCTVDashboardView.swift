import SwiftUI
import WebKit

struct CCTVDashboardView: View {
    @State private var screenshotManager = UnifiedScreenshotManager.shared
    @State private var debugService = LiveWebViewDebugService.shared
    @State private var vm = Sitchomatic1000ViewModel.shared
    @State private var pinnedSessionKey: String? = nil
    @State private var selectedEntry: Sitchomatic1000Entry?
    @FocusState private var isPasteFocused: Bool

    private var activeSessions: [UnifiedScreenshot] {
        let allScreenshots = screenshotManager.screenshots
        let activeHosts = vm.activeEntries.compactMap { URL(string: $0.url)?.host?.lowercased() }
        let recentCutoff = Date().addingTimeInterval(-180)
        var latestPerSession: [String: UnifiedScreenshot] = [:]

        for shot in allScreenshots where shot.timestamp > recentCutoff {
            let normalizedSite = shot.site.lowercased()
            guard activeHosts.contains(where: { normalizedSite.contains($0) }) else { continue }
            let key = sessionKey(for: shot)
            if let existing = latestPerSession[key], existing.timestamp >= shot.timestamp {
                continue
            }
            latestPerSession[key] = shot
        }

        return Array(latestPerSession.values).sorted { $0.timestamp > $1.timestamp }
    }

    private var pinnedSession: UnifiedScreenshot? {
        if let pinnedSessionKey {
            return activeSessions.first(where: { sessionKey(for: $0) == pinnedSessionKey }) ?? activeSessions.first
        }
        return activeSessions.first
    }

    private var gridSessions: [UnifiedScreenshot] {
        guard let pinnedSession else { return activeSessions }
        return activeSessions.filter { sessionKey(for: $0) != sessionKey(for: pinnedSession) }
    }

    private var lineCount: Int {
        vm.bulkPasteText
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }

    private var parsedCount: Int {
        vm.parseBulkCredentials(vm.bulkPasteText).count
    }

    private var windowsWithCredentialsCount: Int {
        vm.entries.filter(\.hasCredentials).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                launchCommandCentreButton
                liveMonitorCard
                assignmentCard
                windowsCard
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("CCTV Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isPasteFocused = false
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            NavigationStack {
                CredentialAssignmentSheetContent(vm: vm, entry: entry)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
        .preferredColorScheme(.dark)
    }

    private var liveMonitorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Live Monitor", systemImage: "video.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Your CCTV feeds, credential loading state, and active custom URL windows all in one place.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    monitorStatPill(title: "Windows", value: "\(vm.entries.count)")
                    monitorStatPill(title: "Loaded", value: "\(windowsWithCredentialsCount)")
                    monitorStatPill(title: "Live", value: "\(activeSessions.count)")
                }
            }

            heroPanel(height: 250)

            if !activeSessions.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(gridSessions) { shot in
                        sessionButton(shot, isPinned: false)
                    }
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.08, blue: 0.1), Color(red: 0.02, green: 0.02, blue: 0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(.rect(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var assignmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Credential Assignment", systemImage: "key.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Paste one list, then append it to a single CCTV window or to every window at once.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !vm.bulkPasteText.isEmpty {
                    Text("\(parsedCount)/\(lineCount) valid")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(parsedCount > 0 ? .green : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
            }

            if vm.entries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a custom URL window first.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("When you leave the label blank, new windows are named automatically as custom_url, custom_url2, and so on.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.white.opacity(0.05))
                .clipShape(.rect(cornerRadius: 18))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Paste List")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    TextEditor(text: $vm.bulkPasteText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 180)
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .clipShape(.rect(cornerRadius: 18))
                        .focused($isPasteFocused)
                        .overlay(alignment: .topLeading) {
                            if vm.bulkPasteText.isEmpty {
                                Text("email1@example.com:password\nemail2@example.com:password")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.25))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 20)
                                    .allowsHitTesting(false)
                            }
                        }

                    ViewThatFits {
                        HStack(spacing: 10) {
                            pasteFromClipboardButton
                            clearPasteButton
                            appendToAllWindowsButton
                        }

                        VStack(spacing: 10) {
                            appendToAllWindowsButton
                            HStack(spacing: 10) {
                                pasteFromClipboardButton
                                clearPasteButton
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
                .clipShape(.rect(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Append To One Window")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    ForEach(vm.entries) { entry in
                        assignmentRow(entry)
                    }
                }
            }

            if let summary = vm.lastBulkImportSummary {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(summary)
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.green.opacity(0.12))
                .clipShape(.rect(cornerRadius: 16))
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var windowsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("CCTV Windows", systemImage: "rectangle.split.3x1.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Each custom URL window keeps its own credential list. Manage, review, or clear them independently.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(vm.entries.count)")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }

            if vm.entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("No CCTV windows yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Go back and add a custom URL window, then return here to load different credential lists into each one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(vm.entries) { entry in
                    windowRow(entry)
                }
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var pasteFromClipboardButton: some View {
        Button {
            if let clipboard = UIPasteboard.general.string, !clipboard.isEmpty {
                vm.bulkPasteText = clipboard
                isPasteFocused = false
            }
        } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.white)
    }

    private var clearPasteButton: some View {
        Button {
            vm.bulkPasteText = ""
            vm.lastBulkImportSummary = nil
            isPasteFocused = false
        } label: {
            Label("Clear", systemImage: "xmark.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.white)
    }

    private var appendToAllWindowsButton: some View {
        Button {
            let appended = vm.appendCredentialTextToAllWindows(vm.bulkPasteText)
            if appended > 0 {
                vm.lastBulkImportSummary = "Appended \(appended) creds to all \(vm.entries.count) windows"
                vm.bulkPasteText = ""
                isPasteFocused = false
            } else {
                vm.lastBulkImportSummary = vm.entries.isEmpty ? "No CCTV windows available" : "No valid lines found"
            }
        } label: {
            Label("Append to All Windows", systemImage: "square.stack.3d.up.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(parsedCount == 0 || vm.entries.isEmpty)
    }

    private func assignmentRow(_ entry: Sitchomatic1000Entry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.label)
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(entry.url)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(entry.credentialList.count)")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(entry.hasCredentials ? .cyan : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background((entry.hasCredentials ? Color.cyan : Color.white).opacity(0.12))
                .clipShape(Capsule())

            Button {
                let appended = vm.appendCredentialText(entryId: entry.id, text: vm.bulkPasteText)
                if appended > 0 {
                    vm.lastBulkImportSummary = "Appended \(appended) creds to \(entry.label)"
                    vm.bulkPasteText = ""
                    isPasteFocused = false
                } else {
                    vm.lastBulkImportSummary = "No valid lines found"
                }
            } label: {
                Text("Append")
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 76)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(parsedCount == 0)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(.rect(cornerRadius: 18))
    }

    private func windowRow(_ entry: Sitchomatic1000Entry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(entry.isActive ? Color.red.opacity(0.18) : Color.white.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: entry.isActive ? "video.fill" : "video.slash.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(entry.isActive ? .red : .secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.label)
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(entry.url)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(entry.isActive ? "LIVE" : "OFF")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(entry.isActive ? .red : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background((entry.isActive ? Color.red : Color.white).opacity(0.1))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                detailPill(icon: "key.fill", text: entry.credentialDisplay, color: entry.hasCredentials ? .cyan : .secondary)
                detailPill(icon: entry.hasFlow ? "record.circle.fill" : "record.circle", text: entry.assignedFlowName ?? "No Flow", color: entry.hasFlow ? .green : .secondary)
                Spacer()
            }

            ViewThatFits {
                HStack(spacing: 10) {
                    manageButton(for: entry)
                    cloneButton(for: entry)
                    clearButton(for: entry)
                }

                VStack(spacing: 10) {
                    manageButton(for: entry)
                    HStack(spacing: 10) {
                        cloneButton(for: entry)
                        clearButton(for: entry)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(.rect(cornerRadius: 20))
    }

    private func manageButton(for entry: Sitchomatic1000Entry) -> some View {
        Button {
            selectedEntry = entry
        } label: {
            Label("Manage List", systemImage: "slider.horizontal.3")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
    }

    private func cloneButton(for entry: Sitchomatic1000Entry) -> some View {
        Button {
            vm.cloneEntry(id: entry.id)
        } label: {
            Label("Clone", systemImage: "square.on.square")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.white)
    }

    private var launchCommandCentreButton: some View {
        NavigationLink {
            CCTVCommandCentreView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.3x3.topleft.filled")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("LAUNCH COMMAND CENTRE")
                        .font(.system(.subheadline, design: .monospaced, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(.white)
                    Text("Select up to 7 windows • run all flows live")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(16)
            .background(
                LinearGradient(colors: [Color.green.opacity(0.9), Color.blue.opacity(0.9)], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(.rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func clearButton(for entry: Sitchomatic1000Entry) -> some View {
        Button(role: .destructive) {
            vm.clearCredentialList(entryId: entry.id)
        } label: {
            Label("Clear List", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!entry.hasCredentials)
    }

    private func detailPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func monitorStatPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .heavy))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func heroPanel(height: CGFloat) -> some View {
        Color(white: 0.05)
            .frame(height: height)
            .overlay {
                if let pinnedSession, debugService.isAttached, let webView = debugService.attachedWebView {
                    LiveWebViewContainerView(webView: webView, interactive: false)
                        .allowsHitTesting(false)
                } else if let pinnedSession {
                    Image(uiImage: pinnedSession.displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                } else {
                    noSignalPlaceholder(isLarge: true)
                }
            }
            .clipShape(.rect(cornerRadius: 22))
            .overlay(alignment: .topLeading) {
                if let pinnedSession {
                    monitorBadge(title: pinnedSession.siteLabel, subtitle: pinnedSession.outcomeLabel, color: pinnedSession.siteColor)
                        .padding(12)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let pinnedSession {
                    Text(pinnedSession.formattedTime)
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.72))
                        .clipShape(Capsule())
                        .padding(12)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let pinnedSession {
                    HStack(spacing: 8) {
                        Text(pinnedSession.credentialEmail)
                            .font(.system(.caption, design: .monospaced, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        Text(pinnedSession.site)
                            .font(.system(.caption2, design: .monospaced, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [.black.opacity(0.85), .black.opacity(0.25)], startPoint: .bottom, endPoint: .top))
                    .clipShape(.rect(cornerRadius: 22))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.green.opacity(0.24), lineWidth: 1.2)
            )
    }

    private func sessionButton(_ shot: UnifiedScreenshot, isPinned: Bool) -> some View {
        Button {
            pinnedSessionKey = sessionKey(for: shot)
        } label: {
            Color(white: 0.08)
                .frame(height: 126)
                .overlay {
                    Image(uiImage: shot.displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 18))
                .overlay(alignment: .topLeading) {
                    monitorBadge(title: shot.siteLabel, subtitle: shot.outcomeLabel, color: shot.siteColor)
                        .padding(10)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shot.credentialEmail)
                            .font(.system(.caption2, design: .monospaced, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(shot.formattedTime)
                            .font(.system(.caption2, design: .monospaced, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.72))
                    .clipShape(.rect(cornerRadius: 18))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(isPinned ? Color.blue : Color.white.opacity(0.08), lineWidth: isPinned ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show live feed for \(shot.credentialEmail) on \(shot.siteLabel)")
    }

    private func monitorBadge(title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.72))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func noSignalPlaceholder(isLarge: Bool) -> some View {
        ZStack {
            Color(white: 0.03)

            VStack(spacing: isLarge ? 12 : 6) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: isLarge ? 32 : 16))
                    .foregroundStyle(.white.opacity(0.15))

                Text("NO LIVE FEED")
                    .font(.system(size: isLarge ? 13 : 8, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.15))
                    .tracking(2)
            }

            Canvas { context, size in
                for y in stride(from: 0, to: size.height, by: 4) {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(.white.opacity(0.02)))
                }
            }
            .allowsHitTesting(false)
        }
        .clipShape(.rect(cornerRadius: isLarge ? 22 : 12))
    }

    private func sessionKey(for shot: UnifiedScreenshot) -> String {
        "\(shot.credentialEmail.lowercased())|\(shot.site.lowercased())"
    }
}
