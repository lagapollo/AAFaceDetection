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
 */

import UIKit
import GLKit
import AVFoundation

class LiveTranscribeViewController: UIViewController {
    
    @IBOutlet weak var glkView: GLKView!
    var faceReplacer: FaceReplacer!
    
    @IBOutlet weak var faceCollectionView: UICollectionView!
    let faceSource = FaceSource()
    
    @IBOutlet weak var transcriptionOutputLabel: UILabel!
    
    var visage: Visage! = Visage()
    
    @IBAction func handleDoneTapped(_ sender: Any?) {
        faceReplacer.stopCapture()
        dismiss(animated: true, completion: .none)
    }
    
    @IBOutlet weak var viewRender: UIView!
    @IBOutlet weak var ivRender: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        initialiseFaceReplacer()
        startRecording()
    }
    
    @IBAction func clickOnStart(_ sender: Any) {
        faceSource.initSource()
    }
}

extension LiveTranscribeViewController {
    fileprivate func startRecording() {
        //self.transcriptionOutputLabel.text = ""
    }
}

extension LiveTranscribeViewController {
    fileprivate func initialiseFaceReplacer() {
        faceReplacer = FaceReplacer(imageView: glkView, finalRenderView:self.ivRender)
        do {
            try faceReplacer.startCapture(imageView: viewRender)
        } catch let error as NSError {
            let alert = UIAlertController(title: "Sorry", message: error.localizedDescription, preferredStyle: .alert)
            present(alert, animated: true, completion: .none)
        }
        faceSource.faceChosen = { [unowned self] face in
            self.faceReplacer.newFace = self.visage.convertFeaturesToEmojiImage()
        }
//        faceSource.initSource()
    }
}

