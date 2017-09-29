//
//  Visage.swift
//  FaceDetection
//
//  Created by Julian Abentheuer on 21.12.14.
//  Copyright (c) 2014 Aaron Abentheuer. All rights reserved.
//

import UIKit
import CoreImage
import AVFoundation
import ImageIO

class Visage: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    enum DetectorAccuracy {
        case batterySaving
        case higherPerformance
    }
    
    enum CameraDevice {
        case iSightCamera
        case faceTimeCamera
    }
    
    var onlyFireNotificatonOnStatusChange : Bool = true
    var visageCameraView : UIView = UIView()
    
    //Private properties of the detected face that can be accessed (read-only) by other classes.
    fileprivate(set) var faceDetected : Bool?
    fileprivate(set) var faceBounds : CGRect?
    fileprivate(set) var faceAngle : CGFloat?
    fileprivate(set) var faceAngleDifference : CGFloat?
    fileprivate(set) var leftEyePosition : CGPoint?
    fileprivate(set) var rightEyePosition : CGPoint?
    
    fileprivate(set) var mouthPosition : CGPoint?
    fileprivate(set) var hasSmile : Bool?
    fileprivate(set) var isBlinking : Bool?
    fileprivate(set) var isWinking : Bool?
    fileprivate(set) var leftEyeClosed : Bool?
    fileprivate(set) var rightEyeClosed : Bool?
    
    //Notifications you can subscribe to for reacting to changes in the detected properties.
    fileprivate let visageNoFaceDetectedNotification = Notification(name: Notification.Name(rawValue: "visageNoFaceDetectedNotification"), object: nil)
    fileprivate let visageFaceDetectedNotification = Notification(name: Notification.Name(rawValue: "visageFaceDetectedNotification"), object: nil)
    fileprivate let visageSmilingNotification = Notification(name: Notification.Name(rawValue: "visageHasSmileNotification"), object: nil)
    fileprivate let visageNotSmilingNotification = Notification(name: Notification.Name(rawValue: "visageHasNoSmileNotification"), object: nil)
    fileprivate let visageBlinkingNotification = Notification(name: Notification.Name(rawValue: "visageBlinkingNotification"), object: nil)
    fileprivate let visageNotBlinkingNotification = Notification(name: Notification.Name(rawValue: "visageNotBlinkingNotification"), object: nil)
    fileprivate let visageWinkingNotification = Notification(name: Notification.Name(rawValue: "visageWinkingNotification"), object: nil)
    fileprivate let visageNotWinkingNotification = Notification(name: Notification.Name(rawValue: "visageNotWinkingNotification"), object: nil)
    fileprivate let visageLeftEyeClosedNotification = Notification(name: Notification.Name(rawValue: "visageLeftEyeClosedNotification"), object: nil)
    fileprivate let visageLeftEyeOpenNotification = Notification(name: Notification.Name(rawValue: "visageLeftEyeOpenNotification"), object: nil)
    fileprivate let visageRightEyeClosedNotification = Notification(name: Notification.Name(rawValue: "visageRightEyeClosedNotification"), object: nil)
    fileprivate let visageRightEyeOpenNotification = Notification(name: Notification.Name(rawValue: "visageRightEyeOpenNotification"), object: nil)
    
    //Private variables that cannot be accessed by other classes in any way.
    var faceDetector : CIDetector?
    fileprivate var videoDataOutput : AVCaptureVideoDataOutput?
    fileprivate var videoDataOutputQueue : DispatchQueue?
    fileprivate var cameraPreviewLayer : AVCaptureVideoPreviewLayer?
    fileprivate var captureSession : AVCaptureSession = AVCaptureSession()
    fileprivate let notificationCenter : NotificationCenter = NotificationCenter.default
    fileprivate var currentOrientation : Int?
    
    init(optimizeFor : DetectorAccuracy) {
        super.init()
        
        currentOrientation = convertOrientation(UIDevice.current.orientation)
        
        var faceDetectorOptions : [String : AnyObject]?
        
        switch optimizeFor {
        case .batterySaving : faceDetectorOptions = [CIDetectorAccuracy : CIDetectorAccuracyLow as AnyObject]
        case .higherPerformance : faceDetectorOptions = [CIDetectorAccuracy : CIDetectorAccuracyHigh as AnyObject]
        }
        
        self.faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: faceDetectorOptions)
    }

    
    var options : [String : AnyObject]?
    
    //MARK: CAPTURE-OUTPUT/ANALYSIS OF FACIAL-FEATURES
    func detectFeatures(withFeatures features:[CIFaceFeature]) {
        
        if (features.count > 0) {
            
            if (onlyFireNotificatonOnStatusChange == true) {
                if (self.faceDetected == false) {
                    notificationCenter.post(visageFaceDetectedNotification)
                }
            } else {
                notificationCenter.post(visageFaceDetectedNotification)
            }
            
            self.faceDetected = true
            
            for feature in features as! [CIFaceFeature] {
                faceBounds = feature.bounds
                
                if (feature.hasFaceAngle) {
                    
                    if (faceAngle != nil) {
                        faceAngleDifference = CGFloat(feature.faceAngle) - faceAngle!
                    } else {
                        faceAngleDifference = CGFloat(feature.faceAngle)
                    }
                    
                    faceAngle = CGFloat(feature.faceAngle)
                }
                
                if (feature.hasLeftEyePosition) {
                    leftEyePosition = feature.leftEyePosition
                }
                
                if (feature.hasRightEyePosition) {
                    rightEyePosition = feature.rightEyePosition
                }
                
                if (feature.hasMouthPosition) {
                    mouthPosition = feature.mouthPosition
                }
                
                if (feature.hasSmile) {
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.hasSmile == false) {
                            notificationCenter.post(visageSmilingNotification)
                        }
                    } else {
                        notificationCenter.post(visageSmilingNotification)
                    }
                    
                    hasSmile = feature.hasSmile
                    
                } else {
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.hasSmile == true) {
                            notificationCenter.post(visageNotSmilingNotification)
                        }
                    } else {
                        notificationCenter.post(visageNotSmilingNotification)
                    }
                    
                    hasSmile = feature.hasSmile
                }
                
                if (feature.leftEyeClosed || feature.rightEyeClosed) {
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.isWinking == false) {
                            notificationCenter.post(visageWinkingNotification)
                        }
                    } else {
                        notificationCenter.post(visageWinkingNotification)
                    }
                    
                    isWinking = true
                    
                    if (feature.leftEyeClosed) {
                        if (onlyFireNotificatonOnStatusChange == true) {
                            if (self.leftEyeClosed == false) {
                                notificationCenter.post(visageLeftEyeClosedNotification)
                            }
                        } else {
                            notificationCenter.post(visageLeftEyeClosedNotification)
                        }
                        
                        leftEyeClosed = feature.leftEyeClosed
                    }
                    if (feature.rightEyeClosed) {
                        if (onlyFireNotificatonOnStatusChange == true) {
                            if (self.rightEyeClosed == false) {
                                notificationCenter.post(visageRightEyeClosedNotification)
                            }
                        } else {
                            notificationCenter.post(visageRightEyeClosedNotification)
                        }
                        
                        rightEyeClosed = feature.rightEyeClosed
                    }
                    if (feature.leftEyeClosed && feature.rightEyeClosed) {
                        if (onlyFireNotificatonOnStatusChange == true) {
                            if (self.isBlinking == false) {
                                notificationCenter.post(visageBlinkingNotification)
                            }
                        } else {
                            notificationCenter.post(visageBlinkingNotification)
                        }
                        
                        isBlinking = true
                    }
                } else {
                    
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.isBlinking == true) {
                            notificationCenter.post(visageNotBlinkingNotification)
                        }
                        if (self.isWinking == true) {
                            notificationCenter.post(visageNotWinkingNotification)
                        }
                        if (self.leftEyeClosed == true) {
                            notificationCenter.post(visageLeftEyeOpenNotification)
                        }
                        if (self.rightEyeClosed == true) {
                            notificationCenter.post(visageRightEyeOpenNotification)
                        }
                    } else {
                        notificationCenter.post(visageNotBlinkingNotification)
                        notificationCenter.post(visageNotWinkingNotification)
                        notificationCenter.post(visageLeftEyeOpenNotification)
                        notificationCenter.post(visageRightEyeOpenNotification)
                    }
                    
                    isBlinking = false
                    isWinking = false
                    leftEyeClosed = feature.leftEyeClosed
                    rightEyeClosed = feature.rightEyeClosed
                }
            }
        } else {
            if (onlyFireNotificatonOnStatusChange == true) {
                if (self.faceDetected == true) {
                    notificationCenter.post(visageNoFaceDetectedNotification)
                }
            } else {
                notificationCenter.post(visageNoFaceDetectedNotification)
            }
            
            self.faceDetected = false
        }
    }
    
    func convertFeaturesToEmoji() -> String {
        
        var emojiLabel = ""
//        print("=============================")
//        print("leftEyeClose : \(String(describing: self.leftEyeClosed))")
//        print("rightEyeClose : \(String(describing: self.rightEyeClosed))")
//        print("hasSmile : \(String(describing: self.hasSmile))")
//        print("isWinking : \(String(describing: self.isWinking))")
//        print("isBlinking : \(String(describing: self.isBlinking))")
        
        emojiLabel = "neutral"
        if (self.hasSmile == true) {
           if (self.leftEyeClosed == true){
                emojiLabel = "left_wink_open"
            }
            else if (self.rightEyeClosed == true) {
                   emojiLabel = "right_wink_open"
            }
            else {
                emojiLabel = "smile"
            }
        }
        else {
            if (self.leftEyeClosed == true){
                emojiLabel = "left_wink"
            }
            else if (self.rightEyeClosed == true) {
                emojiLabel = "right_wink"
            }
        }
//        if ((self.leftEyeClosed == true && self.rightEyeClosed == true)){
//            emojiLabel = "sleep"
//        }
        return emojiLabel
    }
    
    func convertFeaturesToEmojiImage() -> UIImage {
        return UIImage(named:convertFeaturesToEmoji())!
    }
    
    //TODO: 🚧 HELPER TO CONVERT BETWEEN UIDEVICEORIENTATION AND CIDETECTORORIENTATION 🚧
    fileprivate func convertOrientation(_ deviceOrientation: UIDeviceOrientation) -> Int {
        var orientation: Int = 0
        switch deviceOrientation {
        case .portrait:
            orientation = 6
        case .portraitUpsideDown:
            orientation = 2
        case .landscapeLeft:
            orientation = 3
        case .landscapeRight:
            orientation = 4
        default : orientation = 1
        }
        return 6
    }
}


extension String {
    func image() -> UIImage! {
        let size = CGSize(width: 30, height: 35)
        UIGraphicsBeginImageContextWithOptions(size, false, 0);
        UIColor.white.set()
        
        let rect = CGRect(origin: CGPoint(x: 0, y: 0), size: size)
        UIRectFill(CGRect(origin: CGPoint(x: 0, y: 0), size: size))
        
        (self as NSString).draw(in: rect, withAttributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 30)])
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
}
