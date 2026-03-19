//
//  IdentificationCameraView.swift
//  Rapid
//
//  Created by Antigravity on 2026/03/09.
//

import SwiftUI
import AVFoundation
import Combine
import MLKitObjectDetection
import MLKitVision

fileprivate enum IdentificationRoot: Equatable {
    case camera
    case check
}


struct IdentificationRootView: View {
    @StateObject private var rootViewModel = RootViewModel<IdentificationRoot>(root: .camera)
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    
    @Binding var isPresented: Bool
    let idType: IdentificationType
    
    @State private var captureImage: UIImage? = nil
    @State private var guideFrame: CGRect = .zero
    @State private var captureViewSize: CGRect = .zero
    
    var body: some View {
        ZStack {
            RootViewController(rootViewModel: rootViewModel) { root in
                switch root {
                case .camera:
                    IdentificationCameraView(isPresented: $isPresented, idType: idType, guideFrame: $guideFrame) { image, viewSize in
                        self.captureImage = image
                        self.captureViewSize = viewSize
                        self.rootViewModel.push(.check)
                    }
                case .check:
                    if let image = captureImage {
                        IdentificationCheckView(isPresented: $isPresented, image: image, idType: idType, guideFrame: guideFrame, captureViewSize: captureViewSize)
                    }
                }
            }
            .environmentObject(rootViewModel)
        }
        .ignoresSafeArea()
    }
}

fileprivate struct IdentificationCheckView: View {
    @EnvironmentObject private var rootViewModel: RootViewModel<IdentificationRoot>
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @Binding var isPresented: Bool
    
    let image: UIImage
    let idType: IdentificationType
    let guideFrame: CGRect
    let captureViewSize: CGRect
    
    @State private var detectedObjects: [Object] = []
    @State private var isProcessing = true
    @State private var currentIoU: CGFloat = 0
    @State private var imageViewRect: CGRect = .zero
    @State private var showAlert = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main Image (displayed exactly like camera preview)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIWindow().bounds.width, height: UIWindow().bounds.height)
                    .clipped()
                    .ignoresSafeArea()
                
                // Reuse the same cutout overlay from CameraView
                let width = geometry.size.width
                let cardWidth = width * 0.9
                let cardHeight = cardWidth / idType.ratio
                
                ZStack {
                    Color.black.opacity(0.5)
                        .mask(
                            Rectangle()
                                .fill(Color.black)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .frame(width: cardWidth, height: cardHeight)
                                        .blendMode(.destinationOut)
                                )
                        )
                    
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: cardWidth, height: cardHeight)
                }
                .ignoresSafeArea()
                
                VStack {
                    // Header
                    HStack {
                        Text("内容を確認してください")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(12)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Info and Buttons
                    VStack(spacing: 20) {
                        HStack(spacing: 16) {
                            Button(action: {
                                rootViewModel.pop(1)
                            }) {
                                Text("撮り直す")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(16)
                            }
                            
                            Button(action: {
                                print("[DEBUG] current IoU: \(currentIoU)")
                                if currentIoU < 0.7 {
                                    showAlert = true
                                } else {
                                    // Proceed logic
                                    Task {
                                        let success = await profileViewModel.uploadIdentificationImage(
                                            image: image,
                                            idType: idType,
                                            guideFrame: guideFrame
                                        )
                                        if success {
                                            isPresented = false
                                        }
                                    }
                                }
                            }) {
                                ZStack {
                                    Text("これを使う")
                                        .opacity(profileViewModel.isIdentificationUploading ? 0 : 1)
                                    
                                    if profileViewModel.isIdentificationUploading {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(currentIoU < 0.7 || profileViewModel.isIdentificationUploading ? Color.gray : Color.blue)
                                .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                
                if isProcessing {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
                
                // Show upload progress overlay if uploading
                if profileViewModel.isIdentificationUploading {
                    ZStack {
                        Color.black.opacity(0.6).ignoresSafeArea()
                        VStack(spacing: 20) {
                            ProgressView(value: profileViewModel.identificationUploadProgress)
                                .progressViewStyle(.linear)
                                .tint(.blue)
                                .frame(width: 200)
                            Text("画像をアップロード中... \(Int(profileViewModel.identificationUploadProgress * 100))%")
                                .foregroundStyle(.white)
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                }
            }
            .ignoresSafeArea()
            
            .alert("枠内に収まっていません", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(idType.title)をガイド枠内にきれいに収める必要があります。")
            }
            .onAppear {
                detectObjects()
            }
            .navigationBarHidden(true)
        }
    }
    
    private func detectObjects() {
        let options = ObjectDetectorOptions()
        options.detectorMode = .singleImage
        options.shouldEnableClassification = false
        options.shouldEnableMultipleObjects = false
        
        let objectDetector = ObjectDetector.objectDetector(options: options)
        let visionImage = VisionImage(image: image)
        visionImage.orientation = .left
        
        objectDetector.process(visionImage) { objects, error in
            isProcessing = false
            guard error == nil, let objects = objects else { return }
            DispatchQueue.main.async {
                self.detectedObjects = objects
                if let first = objects.first {
                    // Coordinates are based on full screen geometry
                    // Use a common viewSize (e.g. root geometry)
                    let detectedRect = transformRect(first.frame, imageSize: image.size)
                    self.currentIoU = calculateIoU(rect1: guideFrame, rect2: detectedRect)
                    
                    // Auto proceed if IoU is high enough
                    if self.currentIoU >= 0.7 && !profileViewModel.isIdentificationUploading {
                        Task {
                            let success = await profileViewModel.uploadIdentificationImage(
                                image: image,
                                idType: idType,
                                guideFrame: guideFrame
                            )
                            if success {
                                isPresented = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func calculateIoU(rect1: CGRect, rect2: CGRect) -> CGFloat {
        let intersection = rect1.intersection(rect2)
        if intersection.isNull { return 0 }
        
        let intersectionArea = intersection.width * intersection.height
        let unionArea = (rect1.width * rect1.height) + (rect2.width * rect2.height) - intersectionArea
        
        let iou = intersectionArea / (unionArea + 1e-10)
        return iou
    }
    
    private func transformRect(_ rect: CGRect, imageSize: CGSize) -> CGRect {
        let imgW = imageSize.width
        let imgH = imageSize.height
        let viewRect = UIWindow().bounds
        
        let normalizedImageSize = CGSize(width: imgH, height: imgW)
        let scaleWidth = viewRect.width / normalizedImageSize.height
        let scaleHeight = viewRect.height / normalizedImageSize.width
        let scale = max(scaleWidth, scaleHeight)
        
        let offsetX = (viewRect.width - normalizedImageSize.height * scale) / 2
        let offsetY = (viewRect.height - normalizedImageSize.width * scale) / 2
        
        let transformedX = rect.origin.y * scale + offsetX
        let transformedY = rect.origin.x * scale + offsetY
        let transformedWidth = rect.height * scale
        let transformedHeight = rect.width * scale
        
        // The image data received by the detection model and the image desplayed in the View are mirror images of each other,
        // so they are flpped horizontal about the x-axis centered on the View's width.
        let reflectedX = viewRect.width - transformedX - transformedWidth
        
        return CGRect(
            x: reflectedX,
            y: transformedY,
            width: transformedWidth,
            height: transformedHeight
        )
    }
}

fileprivate struct IdentificationCameraView: View {
    @EnvironmentObject private var rootViewModel: RootViewModel<IdentificationRoot>
    
    @Binding var isPresented: Bool
    let idType: IdentificationType
    @Binding var guideFrame: CGRect
    var onCapture: (UIImage, CGRect) -> Void
    
    @StateObject private var camera = CameraModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreview(camera: camera)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Overlay with rectangular Cutout
                let width = geometry.size.width
                let cardWidth = width * 0.9
                let cardHeight = cardWidth / idType.ratio
                
                ZStack {
                    // Dark background
                    Color.black.opacity(0.5)
                        .mask(
                            Rectangle()
                                .fill(Color.black)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .frame(width: cardWidth, height: cardHeight)
                                        .blendMode(.destinationOut)
                                )
                        )
                    
                    // Rectangular Edge
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: cardWidth, height: cardHeight)
                        .background(
                            GeometryReader { innerGeometry in
                                Color.clear
                                    .onAppear {
                                        self.guideFrame = innerGeometry.frame(in: .global)
                                    }
                                    .onChange(of: innerGeometry.frame(in: .global)) { _, newFrame in
                                        self.guideFrame = newFrame
                                    }
                            }
                        )
                        .overlay(
                            VStack {
                                Spacer()
                                Text("枠内に\(idType.title)を収めてください")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.bottom, -30)
                            }
                        )
                }
                
                // Controls
                VStack {
                    HStack {
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .padding()
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 20)
                        .padding(.top, 40)
                        
                        Spacer()
                    }
                    .padding(.top, geometry.safeAreaInsets.top + 10)
                    
                    Spacer()
                    
                    // Shutter Button
                    Button(action: {
                        camera.takePic { image in
                            onCapture(image, geometry.frame(in: .global))
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 80, height: 80)
                        }
                    }
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 30)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            camera.checkPermissions()
        }
    }
}

fileprivate class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer!
    @Published var imageSize: CGSize = .zero
    
    private var completion: ((UIImage) -> Void)?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setup()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { status in
                if status {
                    self.setup()
                }
            }
        case .denied, .restricted:
            self.alert = true
        @unknown default:
            break
        }
    }
    
    func setup() {
        do {
            self.session.beginConfiguration()
            
            // Set resolution for stable coordinate calculations
            if self.session.canSetSessionPreset(.hd1920x1080) {
                self.session.sessionPreset = .hd1920x1080
            }
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
            let input = try AVCaptureDeviceInput(device: device)
            
            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
            }
            
            if self.session.canAddOutput(self.videoDataOutput) {
                self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
                self.session.addOutput(self.videoDataOutput)
                
                self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            }
            
            self.session.commitConfiguration()
            
            DispatchQueue.global(qos: .background).async {
                self.session.startRunning()
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func takePic(completion: @escaping (UIImage) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        
        // Match capture orientation with preview
        if let connection = self.output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
        
        self.output.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else { return }
        guard let image = UIImage(data: imageData) else { return }
        
        DispatchQueue.main.async {
            self.completion?(image)
        }
    }
}

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let width = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        
        DispatchQueue.main.async {
            if self.imageSize.width != width || self.imageSize.height != height {
                self.imageSize = CGSize(width: width, height: height)
            }
        }
    }
}

fileprivate struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: camera.session)
        previewLayer.videoGravity = .resizeAspectFill
        
        if let connection = previewLayer.connection {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
        
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.main.async {
            camera.preview = previewLayer
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            camera.preview?.frame = uiView.bounds
        }
    }
}
