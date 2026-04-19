import SwiftUI
import UIKit

struct ScreenshotHighlightView: View {
    let image: UIImage
    let onComplete: ([HighlightRegion]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var regions: [DrawingRegion] = []
    @State private var currentDrag: CGRect?
    @State private var dragStart: CGPoint?
    @State private var labelForRegion: String = ""
    @State private var showLabelPrompt: Bool = false
    @State private var pendingRegionRect: CGRect?
    @State private var imageFrame: CGRect = .zero

    struct DrawingRegion: Identifiable {
        let id = UUID()
        var rect: CGRect
        var label: String
        var color: Color = .red
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                instructionBar

                GeometryReader { geo in
                    let imageSize = image.size
                    let containerSize = geo.size
                    let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
                    let displayWidth = imageSize.width * scale
                    let displayHeight = imageSize.height * scale
                    let offsetX = (containerSize.width - displayWidth) / 2
                    let offsetY = (containerSize.height - displayHeight) / 2

                    ZStack(alignment: .topLeading) {
                        Color.black

                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: displayWidth, height: displayHeight)
                            .position(x: containerSize.width / 2, y: containerSize.height / 2)

                        ForEach(regions) { region in
                            let screenRect = normalizedToScreen(region.rect, displayWidth: displayWidth, displayHeight: displayHeight, offsetX: offsetX, offsetY: offsetY)
                            Rectangle()
                                .strokeBorder(region.color, lineWidth: 2.5)
                                .background(region.color.opacity(0.15))
                                .frame(width: screenRect.width, height: screenRect.height)
                                .overlay(alignment: .topLeading) {
                                    if !region.label.isEmpty {
                                        Text(region.label)
                                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(region.color.opacity(0.85))
                                            .clipShape(.rect(cornerRadius: 3))
                                            .offset(y: -18)
                                    }
                                }
                                .position(x: screenRect.midX, y: screenRect.midY)
                        }

                        if let drag = currentDrag {
                            Rectangle()
                                .strokeBorder(.yellow, lineWidth: 2)
                                .background(Color.yellow.opacity(0.1))
                                .frame(width: drag.width, height: drag.height)
                                .position(x: drag.midX, y: drag.midY)
                        }

                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 8)
                                    .onChanged { value in
                                        let start = dragStart ?? value.startLocation
                                        dragStart = start
                                        let minX = min(start.x, value.location.x)
                                        let minY = min(start.y, value.location.y)
                                        let w = abs(value.location.x - start.x)
                                        let h = abs(value.location.y - start.y)
                                        currentDrag = CGRect(x: minX, y: minY, width: w, height: h)
                                    }
                                    .onEnded { _ in
                                        guard let drag = currentDrag else { return }
                                        let normalized = screenToNormalized(drag, displayWidth: displayWidth, displayHeight: displayHeight, offsetX: offsetX, offsetY: offsetY)
                                        if normalized.width > 0.02 && normalized.height > 0.02 {
                                            pendingRegionRect = normalized
                                            labelForRegion = ""
                                            showLabelPrompt = true
                                        }
                                        currentDrag = nil
                                        dragStart = nil
                                    }
                            )
                    }
                }

                bottomBar
            }
            .background(.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("HIGHLIGHT EVIDENCE")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.yellow)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let result = regions.map {
                            HighlightRegion(
                                x: $0.rect.origin.x,
                                y: $0.rect.origin.y,
                                width: $0.rect.width,
                                height: $0.rect.height,
                                label: $0.label
                            )
                        }
                        onComplete(result)
                        dismiss()
                    } label: {
                        Text("Done (\(regions.count))")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                    }
                    .disabled(regions.isEmpty)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .alert("Label this region", isPresented: $showLabelPrompt) {
            TextField("e.g. error text, login button", text: $labelForRegion)
            Button("Add") {
                if let rect = pendingRegionRect {
                    let region = DrawingRegion(
                        rect: rect,
                        label: labelForRegion.trimmingCharacters(in: .whitespacesAndNewlines),
                        color: regionColor(for: regions.count)
                    )
                    regions.append(region)
                }
                pendingRegionRect = nil
            }
            Button("Skip Label") {
                if let rect = pendingRegionRect {
                    let region = DrawingRegion(rect: rect, label: "", color: regionColor(for: regions.count))
                    regions.append(region)
                }
                pendingRegionRect = nil
            }
            Button("Cancel", role: .cancel) {
                pendingRegionRect = nil
            }
        } message: {
            Text("What does this highlighted area indicate?\nE.g. 'error banner', 'balance visible', 'button still loading'")
        }
    }

    private var instructionBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.yellow)
            Text("Draw rectangles around evidence that shows the correct result")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.12))
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if !regions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(regions.enumerated()), id: \.element.id) { index, region in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(region.color)
                                    .frame(width: 8, height: 8)
                                Text(region.label.isEmpty ? "Region \(index + 1)" : region.label)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                Button {
                                    regions.removeAll { $0.id == region.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(region.color.opacity(0.25))
                            .clipShape(Capsule())
                        }
                    }
                }
            } else {
                Text("No regions highlighted yet")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !regions.isEmpty {
                Button {
                    regions.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func normalizedToScreen(_ normalized: CGRect, displayWidth: CGFloat, displayHeight: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> CGRect {
        CGRect(
            x: offsetX + normalized.origin.x * displayWidth,
            y: offsetY + normalized.origin.y * displayHeight,
            width: normalized.width * displayWidth,
            height: normalized.height * displayHeight
        )
    }

    private func screenToNormalized(_ screen: CGRect, displayWidth: CGFloat, displayHeight: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> CGRect {
        let nx = max(0, (screen.origin.x - offsetX) / displayWidth)
        let ny = max(0, (screen.origin.y - offsetY) / displayHeight)
        let nw = min(1 - nx, screen.width / displayWidth)
        let nh = min(1 - ny, screen.height / displayHeight)
        return CGRect(x: nx, y: ny, width: nw, height: nh)
    }

    private func regionColor(for index: Int) -> Color {
        let colors: [Color] = [.red, .orange, .yellow, .cyan, .purple, .pink]
        return colors[index % colors.count]
    }
}
