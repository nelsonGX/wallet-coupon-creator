//
//  IconCropperView.swift
//  coupon-creator
//

import SwiftUI
import UIKit

struct IconCropperView: View {
    let image: UIImage
    let onCropped: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    // Gesture state
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    private let cropSize: CGFloat = 260
    private let outputSize: CGFloat = 174 // 2x of 87pt (largest icon size)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Crop area
                ZStack {
                    // Full image (draggable, zoomable)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropSize * scale, height: cropSize * scale)
                        .offset(offset)
                        .gesture(dragGesture)
                        .gesture(magnificationGesture)
                        .frame(width: cropSize, height: cropSize)
                        .clipped()

                    // Crop overlay
                    cropOverlay
                }
                .frame(width: cropSize, height: cropSize)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Text("Drag and pinch to adjust")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)

                Spacer()
            }
            .background(Color.black.opacity(0.9))
            .navigationTitle("Crop Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        cropAndSave()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Overlay

    private var cropOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
            .frame(width: cropSize, height: cropSize)
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
                clampOffset()
            }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastScale * value.magnification
                scale = max(1.0, min(newScale, 5.0))
            }
            .onEnded { _ in
                lastScale = scale
                clampOffset()
            }
    }

    private func clampOffset() {
        let maxOffset = (cropSize * scale - cropSize) / 2
        withAnimation(.easeOut(duration: 0.2)) {
            offset.width = max(-maxOffset, min(maxOffset, offset.width))
            offset.height = max(-maxOffset, min(maxOffset, offset.height))
        }
        lastOffset = offset
    }

    // MARK: - Crop

    private func cropAndSave() {
        let renderer = ImageRenderer(content:
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: cropSize * scale, height: cropSize * scale)
                .offset(offset)
                .frame(width: cropSize, height: cropSize)
                .clipped()
        )
        renderer.scale = outputSize / cropSize

        guard let cgImage = renderer.cgImage else {
            dismiss()
            return
        }

        let cropped = UIImage(cgImage: cgImage)
        if let pngData = cropped.pngData() {
            onCropped(pngData)
        }
        dismiss()
    }
}
