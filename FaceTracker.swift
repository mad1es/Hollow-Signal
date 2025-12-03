import Foundation
import Vision
import AVFoundation
import UIKit

class FaceTracker: NSObject, ObservableObject {
    @Published var isTracking: Bool = false
    @Published var faceDetected: Bool = false
    @Published var faceExpression: FaceExpression = .neutral
    
    private let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var mockTimer: Timer?
    private var useMockData: Bool = true // Для демонстрации используем mock данные
    
    override init() {
        super.init()
        if !useMockData {
            setupCaptureSession()
        }
    }
    
    private func setupCaptureSession() {
        captureSession.sessionPreset = .medium
        
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("Не удалось настроить камеру, используем mock данные")
            useMockData = true
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
    }
    
    func startTracking() {
        guard !isTracking else { return }
        
        if useMockData {
            startMockTracking()
        } else {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
                DispatchQueue.main.async {
                    self?.isTracking = true
                }
            }
        }
    }
    
    /// Mock трекинг для демонстрации - симулирует обнаружение лица и эмоций
    private func startMockTracking() {
        isTracking = true
        
        // Случайно определяем наличие лица (70% вероятность)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.faceDetected = Double.random(in: 0...1) > 0.3
        }
        
        // Периодически меняем выражение лица для реалистичности
        mockTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Случайно меняем выражение, но чаще нейтральное или напряженное
            let random = Double.random(in: 0...1)
            if random < 0.4 {
                self.faceExpression = .neutral
            } else if random < 0.7 {
                self.faceExpression = .tense
            } else if random < 0.85 {
                self.faceExpression = .tired
            } else {
                self.faceExpression = [.surprised, .sad].randomElement() ?? .neutral
            }
            
            // Иногда "обнаруживаем" лицо
            if Double.random(in: 0...1) > 0.2 {
                self.faceDetected = true
            }
        }
    }
    
    func stopTracking() {
        guard isTracking else { return }
        
        mockTimer?.invalidate()
        mockTimer = nil
        
        if !useMockData {
            captureSession.stopRunning()
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.isTracking = false
            self?.faceDetected = false
        }
    }
    
    private func handleFaceDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNFaceObservation] else {
            DispatchQueue.main.async {
                self.faceDetected = false
            }
            return
        }
        
        DispatchQueue.main.async {
            self.faceDetected = !observations.isEmpty
            
            if let face = observations.first {
                // Анализируем выражение лица
                self.analyzeFaceExpression(face)
            }
        }
    }
    
    private func analyzeFaceExpression(_ face: VNFaceObservation) {
        // Простой анализ выражения лица на основе геометрии
        // В реальной реализации можно использовать более сложные модели
        
        guard let landmarks = face.landmarks else {
            DispatchQueue.main.async { [weak self] in
                self?.faceExpression = .neutral
            }
            return
        }
        
        // Анализ бровей (напряжение)
        if let leftEyebrow = landmarks.leftEyebrow,
           let rightEyebrow = landmarks.rightEyebrow {
            let eyebrowDistance = calculateDistance(leftEyebrow.normalizedPoints, rightEyebrow.normalizedPoints)
            
            if eyebrowDistance < 0.1 {
                DispatchQueue.main.async { [weak self] in
                    self?.faceExpression = .tense
                }
                return
            }
        }
        
        // Анализ рта (улыбка/грусть)
        if let mouth = landmarks.outerLips {
            let mouthPoints = mouth.normalizedPoints
            let mouthWidth = abs(mouthPoints[0].x - mouthPoints[mouthPoints.count / 2].x)
            
            DispatchQueue.main.async { [weak self] in
                if mouthWidth > 0.3 {
                    self?.faceExpression = .smiling
                } else if mouthWidth < 0.15 {
                    self?.faceExpression = .sad
                }
            }
        }
        
        // Анализ глаз (широко открыты = страх/удивление)
        if let leftEye = landmarks.leftEye,
           let rightEye = landmarks.rightEye {
            let eyeOpenness = (calculateEyeOpenness(leftEye.normalizedPoints) + 
                             calculateEyeOpenness(rightEye.normalizedPoints)) / 2
            
            DispatchQueue.main.async { [weak self] in
                if eyeOpenness > 0.8 {
                    self?.faceExpression = .surprised
                } else if eyeOpenness < 0.3 {
                    self?.faceExpression = .tired
                }
            }
        }
    }
    
    private func calculateDistance(_ points1: [CGPoint], _ points2: [CGPoint]) -> CGFloat {
        guard !points1.isEmpty && !points2.isEmpty else { return 0 }
        let center1 = points1.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let center2 = points2.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let avg1 = CGPoint(x: center1.x / CGFloat(points1.count), y: center1.y / CGFloat(points1.count))
        let avg2 = CGPoint(x: center2.x / CGFloat(points2.count), y: center2.y / CGFloat(points2.count))
        return sqrt(pow(avg1.x - avg2.x, 2) + pow(avg1.y - avg2.y, 2))
    }
    
    private func calculateEyeOpenness(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 4 else { return 0.5 }
        let topY = points.prefix(points.count / 2).map { $0.y }.min() ?? 0
        let bottomY = points.suffix(points.count / 2).map { $0.y }.max() ?? 0
        return abs(topY - bottomY)
    }
    
    deinit {
        stopTracking()
    }
}

extension FaceTracker: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Создаем новый request с обработчиком каждый раз
        let faceDetectionRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            self?.handleFaceDetection(request: request, error: error)
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try imageRequestHandler.perform([faceDetectionRequest])
        } catch {
            print("Ошибка обработки изображения: \(error)")
        }
    }
}

enum FaceExpression {
    case neutral
    case tense
    case smiling
    case sad
    case surprised
    case tired
}

