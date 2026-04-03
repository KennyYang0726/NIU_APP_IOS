import SwiftUI
import AVFoundation


// 用 AVFoundation 做 QR 掃描
struct QRScannerView: UIViewRepresentable {
    
    let onCodeScanned: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        context.coordinator.setupCaptureSession(in: view)
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
    }
    
    static func dismantleUIView(_ uiView: PreviewView, coordinator: Coordinator) {
        coordinator.stopSession()
    }
    
    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        
        private let session = AVCaptureSession()
        private let onCodeScanned: (String) -> Void
        private var didSetup = false
        
        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }
        
        func setupCaptureSession(in previewView: PreviewView) {
            guard !didSetup else { return }
            didSetup = true
            
            guard let videoDevice = AVCaptureDevice.default(for: .video),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  session.canAddInput(videoInput) else {
                return
            }
            
            session.beginConfiguration()
            session.addInput(videoInput)
            
            let metadataOutput = AVCaptureMetadataOutput()
            guard session.canAddOutput(metadataOutput) else {
                session.commitConfiguration()
                return
            }
            
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            metadataOutput.metadataObjectTypes = [.qr]
            
            session.commitConfiguration()
            
            previewView.videoPreviewLayer.session = session
            previewView.videoPreviewLayer.videoGravity = .resizeAspectFill
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
        
        func stopSession() {
            guard session.isRunning else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
            }
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let value = object.stringValue else {
                return
            }
            
            onCodeScanned(value)
        }
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
