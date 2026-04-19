import SwiftUI

struct Sitchomatic1000WorkspaceView: View {
    @State private var vm = Sitchomatic1000ViewModel.shared
    @State private var screenshotManager = UnifiedScreenshotManager.shared
    @State private var flowVM = FlowRecorderViewModel()
    @State private var path: [Route] = []
    @State private var pendingNavigationRoute: Route?
    @State private var pendingFlowEntryId: String?
    @State private var flowAssignmentEntry: Sitchomatic1000Entry?

    nonisolated enum Route: Hashable, Sendable {
        case flowRecorder(url: String, entryId: String)
        case savedFlows
        case cctvDashboard
    }

    private var cctvSessions: [UnifiedScreenshot] {
        let allScreenshots = screenshotManager.screenshots
        let activeURLs = Set(vm.activeEntries.map(\.url))
        var latestPerSession: [String: UnifiedScreenshot] = [:]
        let recentCutoff = Date().addingTimeInterval(-180)

        for shot in allScreenshots where shot.timestamp > recentCutoff {
            guard activeURLs.contains(where: { shot.site.localizedCaseInsensitiveContains(URL(string: $0)?.host ?? "") }) else { continue }
            let sessionKey = shot.credentialEmail + shot.site
            if let existing = latestPerSession[sessionKey] {
                if shot.timestamp > existing.timestamp {
                    latestPerSession[sessionKey] = shot
                }
            } else {
                latestPerSession[sessionKey] = shot
            }
        }
        return Array(latestPerSession.values).sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                List {
                    cctvSection
                    bulkCredentialSection
                    workspaceSection
                    urlEntriesSection
                    if !cctvSessions.isEmpty {
                        cctvFeedSection
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Sitchomatic 1000")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            vm.resetNewURLFields()
                            vm.showAddURLSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.red)
                        }
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .flowRecorder(let url, _):
                        FlowRecorderView(viewModel: flowVM, initialURL: url)
                    case .savedFlows:
                        SavedFlowsView(vm: flowVM)
                    case .cctvDashboard:
                        CCTVDashboardView()
                    }
                }
                .sheet(isPresented: $vm.showAddURLSheet) {
                    addURLSheet
                }
                .sheet(isPresented: $vm.showCredentialSheet) {
                    if let entry = vm.editingEntry {
                        credentialAssignmentSheet(entry: entry)
                    }
                }
                .sheet(isPresented: $vm.showBulkCredentialSheet) {
                    bulkCredentialPasteSheet
                }

                addURLFAB
            }
        }
        .withMainMenuButton()
        .preferredColorScheme(.dark)
        .onChange(of: vm.showAddURLSheet) { oldValue, newValue in
            guard oldValue, !newValue, let route = pendingNavigationRoute else { return }
            path.append(route)
            pendingNavigationRoute = nil
        }
        .onChange(of: flowVM.savedFlows.count) { oldValue, newValue in
            guard newValue > oldValue,
                  let entryId = pendingFlowEntryId,
                  let entry = vm.entries.first(where: { $0.id == entryId }),
                  let latestFlow = flowVM.savedFlows.first,
                  latestFlow.url == entry.url else { return }
            vm.assignFlow(entryId: entryId, flowId: latestFlow.id, flowName: latestFlow.name)
            pendingFlowEntryId = nil
        }
        .confirmationDialog(
            "Assign Flow",
            isPresented: Binding(
                get: { flowAssignmentEntry != nil },
                set: { newValue in
                    if !newValue {
                        flowAssignmentEntry = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let entry = flowAssignmentEntry {
                ForEach(flowVM.savedFlows) { flow in
                    Button(flow.name) {
                        vm.assignFlow(entryId: entry.id, flowId: flow.id, flowName: flow.name)
                        flowAssignmentEntry = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                flowAssignmentEntry = nil
            }
        } message: {
            if let entry = flowAssignmentEntry {
                Text("Choose a recorded flow for \(entry.label).")
            }
        }
    }

    // MARK: - CCTV Section (Always Accessible)

    private var cctvSection: some View {
        Section {
            Button {
                path.append(.cctvDashboard)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "video.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.red)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("CCTV Dashboard")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                        HStack(spacing: 6) {
                            if cctvSessions.isEmpty {
                                Text("7-CAM · No active feeds")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            } else {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 5, height: 5)
                                Text("LIVE · \(cctvSessions.count) feed\(cctvSessions.count == 1 ? "" : "s")")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            HStack(spacing: 6) {
                Label("LIVE MONITOR", systemImage: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.red)
                if !cctvSessions.isEmpty {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                }
            }
        }
    }

    // MARK: - Bulk Credential Paste Section

    private var bulkCredentialSection: some View {
        Section {
            Button {
                vm.bulkPasteText = ""
                vm.bulkAssignTarget = .all
                vm.lastBulkImportSummary = nil
                vm.showBulkCredentialSheet = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bulk Paste Credentials")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                        Text("Paste a list & assign to windows")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if vm.entries.contains(where: { !$0.credentialList.isEmpty }) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(vm.entries.filter { !$0.credentialList.isEmpty }) { entry in
                        HStack(spacing: 8) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.cyan)
                                .frame(width: 16)
                            Text(entry.label)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                            Text("\(entry.credentialList.count) creds")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.cyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.cyan.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Label("Credential Assignment", systemImage: "key.fill")
        } footer: {
            Text("Paste email:password lists and append them to one CCTV window or all windows at once.")
        }
    }

    private var workspaceSection: some View {
        Section {
            NavigationLink(value: Route.savedFlows) {
                Label("Saved Flows", systemImage: "tray.full.fill")
            }
        } header: {
            Label("Workspace", systemImage: "rectangle.stack.badge.play")
        }
    }

    private var urlEntriesSection: some View {
        Section {
            if vm.entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No Custom URLs")
                        .font(.subheadline.weight(.semibold))
                    Text("Tap + to add a custom URL with an optional recorded flow.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(vm.entries) { entry in
                    urlEntryRow(entry)
                }
                .onDelete { offsets in
                    vm.removeEntries(at: offsets)
                }
            }
        } header: {
            HStack {
                Label("Custom URLs", systemImage: "globe")
                Spacer()
                Text("\(vm.entries.count)")
                    .font(.caption2.weight(.bold).monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    private func urlEntryRow(_ entry: Sitchomatic1000Entry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(entry.isActive ? Color.red.opacity(0.15) : Color.secondary.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "video.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(entry.isActive ? .red : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.label)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                    Text(entry.url)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { entry.isActive },
                    set: { _ in vm.toggleActive(id: entry.id) }
                ))
                .labelsHidden()
                .tint(.red)
            }

            HStack(spacing: 8) {
                flowBadge(entry)
                credentialPill(entry)
                Spacer()
                assignCredentialButton(entry)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                vm.removeEntry(id: entry.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            if !flowVM.savedFlows.isEmpty {
                Button {
                    showFlowPicker(for: entry)
                } label: {
                    Label("Assign Flow", systemImage: "record.circle")
                }
                .tint(.purple)
            }
        }
    }

    private func flowBadge(_ entry: Sitchomatic1000Entry) -> some View {
        HStack(spacing: 4) {
            Image(systemName: entry.hasFlow ? "record.circle.fill" : "record.circle")
                .font(.system(size: 9))
            Text(entry.assignedFlowName ?? "No Flow")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(entry.hasFlow ? .green : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((entry.hasFlow ? Color.green : Color.secondary).opacity(0.1))
        .clipShape(Capsule())
    }

    private func credentialPill(_ entry: Sitchomatic1000Entry) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "person.fill")
                .font(.system(size: 9))
            Text(entry.credentialDisplay)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(entry.hasCredentials ? .cyan : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((entry.hasCredentials ? Color.cyan : Color.secondary).opacity(0.1))
        .clipShape(Capsule())
    }

    private func assignCredentialButton(_ entry: Sitchomatic1000Entry) -> some View {
        Button {
            vm.editingEntryId = entry.id
            vm.showCredentialSheet = true
        } label: {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
        }
    }

    private func showFlowPicker(for entry: Sitchomatic1000Entry) {
        flowAssignmentEntry = entry
    }

    private var cctvFeedSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(cctvSessions, id: \.credentialEmail) { shot in
                    cctvCard(shot)
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack {
                Label("LIVE CCTV", systemImage: "video.fill")
                    .foregroundStyle(.red)
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                Spacer()
                Text("\(cctvSessions.count) Feed(s)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func cctvCard(_ shot: UnifiedScreenshot) -> some View {
        Button {
            path.append(.cctvDashboard)
        } label: {
            ZStack(alignment: .bottomLeading) {
                Color(.secondarySystemBackground)
                    .frame(height: 140)
                    .overlay {
                        Image(uiImage: shot.displayImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 5, height: 5)
                            Text("REC")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundStyle(.red)
                        }
                        .padding(6)
                        .background(.black.opacity(0.6))
                        .clipShape(.rect(cornerRadius: 4))
                        .padding(6)
                    }
                    .overlay(alignment: .topTrailing) {
                        Text(shot.site.uppercased())
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.6))
                            .clipShape(.rect(cornerRadius: 4))
                            .padding(6)
                    }
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(shot.credentialEmail)
                                .font(.system(size: 8, design: .monospaced))
                                .lineLimit(1)
                                .foregroundStyle(.white)
                            Text(shot.timestamp, format: .dateTime.hour().minute().second())
                                .font(.system(size: 7, weight: .medium, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.7))
                        .clipShape(.rect(cornerRadius: 4))
                        .padding(4)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private var addURLFAB: some View {
        Button {
            vm.resetNewURLFields()
            vm.showAddURLSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(Circle())
                .shadow(color: .red.opacity(0.4), radius: 12, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    private var addURLSheet: some View {
        NavigationStack {
            Form {
                Section("Target URL") {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .foregroundStyle(.secondary)
                        TextField("https://example.com/login", text: $vm.newURL)
                            .font(.system(size: 14, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                }

                Section {
                    TextField("Leave blank for custom_url naming", text: $vm.newLabel)
                        .font(.system(size: 14))
                } header: {
                    Text("Label (Optional)")
                } footer: {
                    Text("Blank labels are named automatically as custom_url, custom_url2, and so on.")
                }

                Section("Flow Recording") {
                    Button {
                        let rawURL = vm.newURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !rawURL.isEmpty else { return }
                        let normalizedURL = rawURL.hasPrefix("http://") || rawURL.hasPrefix("https://") ? rawURL : "https://\(rawURL)"
                        vm.addEntry(url: rawURL, label: vm.newLabel)
                        if let entry = vm.entries.last {
                            pendingFlowEntryId = entry.id
                            pendingNavigationRoute = .flowRecorder(url: normalizedURL, entryId: entry.id)
                        }
                        vm.showAddURLSheet = false
                    } label: {
                        HStack {
                            Image(systemName: "record.circle.fill")
                                .foregroundStyle(.red)
                            Text("Record a flow for this URL")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    if !flowVM.savedFlows.isEmpty {
                        Menu {
                            ForEach(flowVM.savedFlows) { flow in
                                Button {
                                    vm.addEntry(url: vm.newURL, label: vm.newLabel, flowId: flow.id, flowName: flow.name)
                                    vm.showAddURLSheet = false
                                } label: {
                                    Label(flow.name, systemImage: "play.circle.fill")
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "tray.full.fill")
                                    .foregroundStyle(.purple)
                                Text("Assign Existing Flow")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        vm.addEntry(url: vm.newURL, label: vm.newLabel)
                        vm.showAddURLSheet = false
                    } label: {
                        HStack {
                            Image(systemName: "forward.fill")
                                .foregroundStyle(.secondary)
                            Text("Skip Flow — Add URL Only")
                                .font(.subheadline)
                        }
                    }
                } footer: {
                    Text("You can always assign a flow later by swiping the URL entry.")
                }
            }
            .navigationTitle("Add Custom URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        vm.showAddURLSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Bulk Credential Paste Sheet

    private var bulkCredentialPasteSheet: some View {
        NavigationStack {
            BulkCredentialPasteContent(vm: vm)
        }
        .presentationDetents([.large])
    }

    private func credentialAssignmentSheet(entry: Sitchomatic1000Entry) -> some View {
        NavigationStack {
            CredentialAssignmentSheetContent(vm: vm, entry: entry)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Bulk Credential Paste Content

struct BulkCredentialPasteContent: View {
    @Bindable var vm: Sitchomatic1000ViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isPasteFocused: Bool
    @State private var selectedEntryId: String? = nil
    @State private var assignToAll: Bool = true

    private var lineCount: Int {
        vm.bulkPasteText
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }

    private var parsedCount: Int {
        vm.parseBulkCredentials(vm.bulkPasteText).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                instructionCard
                pasteArea
                assignmentPicker
                appendButton

                if let summary = vm.lastBulkImportSummary {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(summary)
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Bulk Paste Credentials")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isPasteFocused = false }
            }
        }
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bulk Credential Append")
                        .font(.headline)
                    Text("Paste a list once, then append it to one CCTV window or every window.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                formatChip("user:pass")
                formatChip("user;pass")
                formatChip("user,pass")
                formatChip("user|pass")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 18))
    }

    private var pasteArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Paste Area")
                    .font(.subheadline.bold())
                Spacer()
                if !vm.bulkPasteText.isEmpty {
                    Text("\(parsedCount) valid of \(lineCount) lines")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(parsedCount > 0 ? .green : .red)
                }
            }

            TextEditor(text: $vm.bulkPasteText)
                .font(.system(.callout, design: .monospaced))
                .frame(minHeight: 180)
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 14))
                .focused($isPasteFocused)
                .overlay(alignment: .topLeading) {
                    if vm.bulkPasteText.isEmpty {
                        Text("Paste credentials here…\n\nexample@email.com:password123\nuser2@test.com:pass456")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.quaternary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 10) {
                Button {
                    if let clipboard = UIPasteboard.general.string, !clipboard.isEmpty {
                        vm.bulkPasteText = clipboard
                        isPasteFocused = false
                    }
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    vm.bulkPasteText = ""
                    vm.lastBulkImportSummary = nil
                    isPasteFocused = false
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 18))
    }

    private var assignmentPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Append To")
                .font(.subheadline.bold())

            Button {
                assignToAll = true
                selectedEntryId = nil
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: assignToAll ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(assignToAll ? .orange : .secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("All Windows")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                        Text("Append this list to every CCTV window")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if assignToAll {
                        Text("\(vm.entries.count) windows")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(12)
                .background(assignToAll ? Color.orange.opacity(0.08) : Color(.tertiarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(assignToAll ? Color.orange.opacity(0.4) : .clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if !vm.entries.isEmpty {
                Text("Or append to one specific window:")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                ForEach(vm.entries) { entry in
                    let isSelected = !assignToAll && selectedEntryId == entry.id
                    Button {
                        assignToAll = false
                        selectedEntryId = entry.id
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(isSelected ? .cyan : .secondary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.label)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(entry.url)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("\(entry.credentialList.count) loaded")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(entry.hasCredentials ? .cyan : .secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background((entry.hasCredentials ? Color.cyan : Color.secondary).opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(12)
                        .background(isSelected ? Color.cyan.opacity(0.08) : Color(.tertiarySystemGroupedBackground))
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(isSelected ? Color.cyan.opacity(0.4) : .clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 18))
    }

    private var appendButton: some View {
        Button {
            let target: Sitchomatic1000ViewModel.BulkAssignTarget
            if assignToAll {
                target = .all
            } else if let entryId = selectedEntryId {
                target = .specific(entryId: entryId)
            } else {
                return
            }
            vm.importBulkCredentials(to: target)
            isPasteFocused = false
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("APPEND LIST")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(vm.bulkPasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!assignToAll && selectedEntryId == nil))
        .opacity((vm.bulkPasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!assignToAll && selectedEntryId == nil)) ? 0.5 : 1)
    }

    private func formatChip(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(Capsule())
    }
}

// MARK: - Per-Entry Credential Sheet

struct CredentialAssignmentSheetContent: View {
    @Bindable var vm: Sitchomatic1000ViewModel
    let entry: Sitchomatic1000Entry
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isPasteFocused: Bool
    @State private var appendText: String = ""

    private var currentEntry: Sitchomatic1000Entry? {
        vm.entries.first(where: { $0.id == entry.id })
    }

    private var parsedCount: Int {
        vm.parseBulkCredentials(appendText).count
    }

    var body: some View {
        Form {
            if let currentEntry {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: currentEntry.isActive ? "video.fill" : "video.slash.fill")
                            .foregroundStyle(currentEntry.isActive ? .red : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentEntry.label)
                                .font(.subheadline.bold())
                            Text(currentEntry.url)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(currentEntry.credentialDisplay)
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(currentEntry.hasCredentials ? .cyan : .secondary)
                    }
                }

                Section("Assigned Credential List") {
                    if currentEntry.credentialList.isEmpty {
                        Text("No credentials loaded for this window yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(currentEntry.credentialList.prefix(20)) { cred in
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.cyan)
                                    .frame(width: 16)
                                Text(cred.email)
                                    .font(.system(size: 11, design: .monospaced))
                                    .lineLimit(1)
                                Spacer()
                                Text("••••")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if currentEntry.credentialList.count > 20 {
                            Text("+ \(currentEntry.credentialList.count - 20) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Append More Credentials") {
                    TextEditor(text: $appendText)
                        .font(.system(.callout, design: .monospaced))
                        .frame(minHeight: 150)
                        .focused($isPasteFocused)
                        .overlay(alignment: .topLeading) {
                            if appendText.isEmpty {
                                Text("email@example.com:password")
                                    .font(.system(.callout, design: .monospaced))
                                    .foregroundStyle(.quaternary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                        }

                    HStack {
                        Text("\(parsedCount) valid lines")
                            .font(.caption.monospaced())
                            .foregroundStyle(parsedCount > 0 ? .green : .secondary)
                        Spacer()
                        Button {
                            if let clipboard = UIPasteboard.general.string, !clipboard.isEmpty {
                                appendText = clipboard
                                isPasteFocused = false
                            }
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                        }
                    }

                    Button {
                        let appended = vm.appendCredentialText(entryId: currentEntry.id, text: appendText)
                        if appended > 0 {
                            vm.lastBulkImportSummary = "Appended \(appended) creds to \(currentEntry.label)"
                            appendText = ""
                            isPasteFocused = false
                        }
                    } label: {
                        Label("Append to This Window", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(parsedCount == 0)
                }

                Section {
                    Button(role: .destructive) {
                        vm.clearCredentialList(entryId: currentEntry.id)
                    } label: {
                        Label("Clear Credential List", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(currentEntry?.label ?? "Window List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isPasteFocused = false }
            }
        }
    }
}
