//
//  CameraFeedView.swift
//  GenericCameraFeedFetcher
//
//  Created by Shubham Kamdi on 1/15/23.
//

import SwiftUI
import AVFoundation
struct CameraFeedView: View {
    @StateObject var cameraService = CameraService()
    var body: some View {
        VStack {
            if let frame = cameraService.cameraFrame {
                Image(decorative: frame, scale: 1, orientation: .right)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth:.infinity, maxHeight: .infinity)
                
            } else {
                Text("Please wait....")
            }
        }.onDisappear(perform: {
            cameraService.stopSession()
        })
    }
}

// Fetching camera frames
class CameraService: NSObject, ObservableObject {
    
    @Published var cameraFrame: CGImage?
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let captureQueue = DispatchQueue.init(label: "Camera.service", qos: .userInitiated)
    override init() {
        super.init()
        addCameraInput()
        addVideoOutput()
        startSession()
    }
    
    private func addCameraInput() {
       if let device = AVCaptureDevice.default(for: .video) {
           do {
               let cameraInput = try AVCaptureDeviceInput(device: device)
               self.captureSession.addInput(cameraInput)
           } catch let error {
               print("Error: \(error.localizedDescription)")
           }
       }
    }
    
    private func addVideoOutput() {
        self.videoOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString): NSNumber(value: kCVPixelFormatType_32BGRA)] as [String: Any]
        self.videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        self.captureSession.addOutput(videoOutput)
    }
    
    private func startSession() {
        DispatchQueue.global(qos: .background).async {
            [weak self] in
            guard let self = self else { return }
            self.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .background).async {
            [weak self] in
            guard let self = self else { return }
            self.captureSession.stopRunning()
        }
    }
}

// Conforming to the camera delegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async {
            [weak self] in
            //Preventing leaks
            guard let self = self else { return }
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            let ciiimage = CIImage(cvPixelBuffer: imageBuffer!)
            if let cgImage = self.getCGImage(ciiimage) {
                //Publish the frames
                self.cameraFrame = cgImage
            }
        }
    }
    
    func getCGImage(_ inputImage: CIImage) -> CGImage? {
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(inputImage, from: inputImage.extent) {
            return cgImage
        }
        return nil
    }
}
