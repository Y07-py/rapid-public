//
//  ProfileImageEditView.swift
//  Rapid
//
//  Created by 木本瑛介 on 2026/02/25.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct ProfileImageEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Source Image
    let originalImage: UIImage
    
    // States for Transformation
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var rotation: Double = 0.0
    
    // States for Filtering
    @State private var selectedFilter: PhotoFilter = .none
    @State private var processedImage: UIImage? = nil
    
    private let context = CIContext()
    
    private let aspect: CGFloat = 1.35
    
    private var cropFrameWidth: CGFloat {
        UIScreen.main.bounds.width - 40
    }
    
    private var cropFrameHeight: CGFloat {
        cropFrameWidth * aspect
    }
    
    // Callback
    var onComplete: (UIImage) -> Void
    var onCancel: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Editor Area
            GeometryReader { proxy in
                ZStack {
                    let image = processedImage ?? originalImage
                    Image(uiImage: image)
                        .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .rotationEffect(.degrees(rotation))
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale *= delta
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                    }
                                    .simultaneously(with: DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                    )
                            )
                    
                    // Crop Overlay
                    cropOverlayView
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // UI Controls
            VStack {
                headerView
                    .padding(.top, 40)
                Spacer()
                footerView
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            processedImage = originalImage
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Button("キャンセル") {
                if let onCancel = onCancel {
                    onCancel()
                } else {
                    dismiss()
                }
            }
            .foregroundStyle(.white)
            .padding()
            
            Spacer()
            
            Button("完了") {
                if let croppedImage = renderCroppedImage() {
                    onComplete(croppedImage)
                }
                dismiss()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.mainColor)
            .clipShape(Capsule())
            .padding()
        }
    }



    // MARK: - Logic
    
    private func renderCroppedImage() -> UIImage? {
        let imageToCrop = processedImage ?? originalImage
        
        // Use a renderer to capture the content of the rectangle area
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropFrameWidth, height: cropFrameHeight))
        
        return renderer.image { context in
            // Move coordinate to the center of the renderer
            context.cgContext.translateBy(x: cropFrameWidth / 2, y: cropFrameHeight / 2)
            
            // Apply transformation
            context.cgContext.rotate(by: CGFloat(rotation * .pi / 180))
            context.cgContext.scaleBy(x: scale, y: scale)
            
            // Adjust for offset (Gestures use Screen points, but we need to consider scale)
            context.cgContext.translateBy(x: offset.width, y: offset.height)
            
            // Draw image
            let imageSize = imageToCrop.size
            let originalAspect = imageSize.width / imageSize.height
            
            let drawWidth: CGFloat
            let drawHeight: CGFloat
            
            // Logic to fit image to the NEW rectangular crop frame aspect
            if originalAspect > (1.0 / aspect) {
                drawHeight = cropFrameHeight
                drawWidth = cropFrameHeight * originalAspect
            } else {
                drawWidth = cropFrameWidth
                drawHeight = cropFrameWidth / originalAspect
            }
            
            imageToCrop.draw(in: CGRect(x: -drawWidth / 2, y: -drawHeight / 2, width: drawWidth, height: drawHeight))
        }
    }
    
    @ViewBuilder
    private var footerView: some View {
        VStack(spacing: 20) {
            // Rotation Control
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "rotate.left")
                        .foregroundStyle(.white)
                    Slider(value: $rotation, in: -45...45)
                        .tint(.white)
                    Image(systemName: "rotate.right")
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 30)
                
                Button(action: {
                    withAnimation(.spring()) {
                        rotation = 0
                    }
                }) {
                    Text("角度をリセット")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            
            // Filter Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(PhotoFilter.allCases, id: \.self) { filter in
                        filterButton(filter)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .background(
            Color.black.opacity(0.8)
                .background(.ultraThinMaterial)
        )
    }
    
    @ViewBuilder
    private func filterButton(_ filter: PhotoFilter) -> some View {
        Button(action: {
            withAnimation {
                selectedFilter = filter
                applyFilter(filter)
            }
        }) {
            VStack(spacing: 8) {
                // Small preview could go here
                Circle()
                    .stroke(selectedFilter == filter ? Color.mainColor : .white.opacity(0.3), lineWidth: 2)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(filter.displayName.prefix(1))
                            .foregroundStyle(.white)
                    )
                
                Text(filter.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(selectedFilter == filter ? Color.mainColor : .white)
            }
        }
    }
    
    @ViewBuilder
    private var cropOverlayView: some View {
        ZStack {
            // Dimmed background with hole
            Color.black.opacity(0.5)
                .mask(
                    HoleShapeMask(width: cropFrameWidth, height: cropFrameHeight)
                        .fill(style: FillStyle(eoFill: true))
                )
            
            // Frame border
            RoundedRectangle(cornerRadius: 4) // Subtle rounding for the rectangle
                .stroke(.white, lineWidth: 2)
                .frame(width: cropFrameWidth, height: cropFrameHeight)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Logic
    
    private func applyFilter(_ filter: PhotoFilter) {
        if filter == .none {
            processedImage = originalImage
            return
        }
        
        guard let ciImage = CIImage(image: originalImage) else { return }
        let currentFilter: CIFilter
        
        switch filter {
        case .chrome:
            currentFilter = CIFilter.photoEffectChrome()
        case .fade:
            currentFilter = CIFilter.photoEffectFade()
        case .instant:
            currentFilter = CIFilter.photoEffectInstant()
        case .mono:
            currentFilter = CIFilter.photoEffectMono()
        case .noir:
            currentFilter = CIFilter.photoEffectNoir()
        case .process:
            currentFilter = CIFilter.photoEffectProcess()
        case .tonal:
            currentFilter = CIFilter.photoEffectTonal()
        case .transfer:
            currentFilter = CIFilter.photoEffectTransfer()
        case .sepia:
            currentFilter = CIFilter.sepiaTone()
        case .none:
            return
        }
        
        currentFilter.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let outputImage = currentFilter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return }
        
        processedImage = UIImage(cgImage: cgImage)
    }
}

struct HoleShapeMask: Shape {
    let width: CGFloat
    let height: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        let cropRect = CGRect(
            x: rect.midX - width / 2,
            y: rect.midY - height / 2,
            width: width,
            height: height
        )
        // Draw a rectangle instead of ellipse
        path.addRect(cropRect)
        return path
    }
}

enum PhotoFilter: String, CaseIterable {
    case none, chrome, fade, instant, mono, noir, process, tonal, transfer, sepia
    
    var displayName: String {
        switch self {
        case .none: return "Original"
        case .chrome: return "Chrome"
        case .fade: return "Fade"
        case .instant: return "Instant"
        case .mono: return "Mono"
        case .noir: return "Noir"
        case .process: return "Process"
        case .tonal: return "Tonal"
        case .transfer: return "Transfer"
        case .sepia: return "Sepia"
        }
    }
}

#Preview {
    ProfileImageEditView(originalImage: UIImage(systemName: "person.fill")!, onComplete: { _ in }, onCancel: {})
}
