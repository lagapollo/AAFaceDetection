/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 *  Created by Richard Turton on 19/04/2016.
 */

import UIKit
import AVFoundation
import GLKit

class FaceReplacer: NSObject {
    
    var visage = Visage(optimizeFor: Visage.DetectorAccuracy.higherPerformance)
    let imageView: GLKView
    var lastTimestamp:TimeInterval = 0
    var count: Int = 0
    var newFace: UIImage? {
        didSet {
            if let newFace = newFace {
                newFaceCI = CIImage(image: newFace)
            } else {
                newFaceCI = nil
            }
        }
    }
    var renderView:UIImageView!
    fileprivate var newFaceCI: CIImage?
    fileprivate let eaglContext = EAGLContext(api: .openGLES2)
    fileprivate let context: CIContext
    fileprivate let detector: CIDetector
    
    init(imageView: GLKView, renderView:UIImageView) {
        self.imageView = imageView
        self.renderView = renderView
        newFace = "😇".image()
        newFaceCI = CIImage(image: newFace!)
        context = CIContext(eaglContext: self.eaglContext!)
        let options = [CIDetectorSmile : true as AnyObject, CIDetectorEyeBlink: true as AnyObject, CIDetectorAccuracy: CIDetectorAccuracyLow as AnyObject, CIDetectorTracking: true as AnyObject]
        
        detector = CIDetector(ofType: CIDetectorTypeFace, context: self.context, options:options)!
        
        super.init()
        imageView.delegate = self
        imageView.context = eaglContext!
        
    }
    
    fileprivate let captureSession = AVCaptureSession()
    fileprivate var cameraImage: CIImage?
    
    
    fileprivate func replaceFaceInImage(_ startImage: CIImage) -> CIImage {
        
        guard let newFaceCI = newFaceCI else { return startImage }
        let options = [CIDetectorSmile : true as AnyObject, CIDetectorEyeBlink: true as AnyObject]
        
        if let faces = detector.features(in: startImage, options:options) as? [CIFaceFeature] {
            if faces.count > 0 {
                
                if (count % 8 == 0){
                    count = 0
                    visage.detectFeatures(withFeatures: faces)
                    newFace = visage.convertFeaturesToEmojiImage()
                }
                count = count+1
                let face = faces[0]
                let compositingFilter = CIFilter(name: "CISourceAtopCompositing")!
                let transformFilter = CIFilter(name: "CIAffineTransform")!
                
                let angle = face.hasFaceAngle ? face.faceAngle : 0
                let angleInRadians = CGFloat(angle * Float(M_PI / -180.0))
                let newFaceSize = newFaceCI.extent.size
                
                transformFilter.setValue(newFaceCI, forKey: kCIInputImageKey)
                let translate = CGAffineTransform(translationX: face.bounds.origin.x, y: face.bounds.origin.y)
                
                let scale = CGAffineTransform(scaleX: face.bounds.width / newFaceSize.width, y: face.bounds.height / newFaceSize.height)
                let rotation = CGAffineTransform(rotationAngle: angleInRadians)
                
                var finalTransform = CGAffineTransform.identity
                finalTransform = finalTransform.concatenating(scale)
                finalTransform = finalTransform.concatenating(rotation)
                finalTransform = finalTransform.concatenating(translate)
                
                transformFilter.setValue(NSValue(cgAffineTransform: finalTransform), forKey: "inputTransform")
                let transformResult = transformFilter.outputImage!
                compositingFilter.setValue(startImage, forKey: kCIInputBackgroundImageKey)
                compositingFilter.setValue(transformResult, forKey: kCIInputImageKey)
                
                return compositingFilter.outputImage!
                
            } else {
                return startImage
            }
        }
        else {
            return startImage
        }
    }
    
    
    func startCapture() throws
    {
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        let cameraError = NSError(domain: "facereplace", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to access front camera"])
        
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: AVCaptureDevice.Position.front)
        
        guard let frontCamera = discoverySession?.devices.first else {
            throw cameraError
        }
        do
        {
            let input = try AVCaptureDeviceInput(device: frontCamera)
            captureSession.addInput(input)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer delegate", qos: DispatchQoS.userInitiated, attributes: DispatchQueue.Attributes()))
        if captureSession.canAddOutput(videoOutput)
        {
            captureSession.addOutput(videoOutput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = UIScreen.main.bounds
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        visage.visageCameraView.layer.addSublayer(previewLayer!)
        
        captureSession.startRunning()
    }
    
    func stopCapture() {
        captureSession.stopRunning()
    }
}

extension FaceReplacer: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        cameraImage = CIImage(cvPixelBuffer: pixelBuffer)
        DispatchQueue.main.async {
            self.imageView.setNeedsDisplay()
        }
        //visage.facialDetection(captureOutput, didOutputSampleBuffer: sampleBuffer, from: connection)
        
    }
}

extension FaceReplacer: GLKViewDelegate {
    func glkView(_ view: GLKView, drawIn rect: CGRect) {
        guard let cameraImage = cameraImage else { return }
        
        
        lastTimestamp = Date().timeIntervalSince1970
        let result = replaceFaceInImage(cameraImage)
        self.renderView.image = UIImage(ciImage: result, scale: 1, orientation: .up)
        
    }
}
