//
//  ViewController.swift
//  SudokuParser
//
//  Created by Lan Chee Hong (HLB) on 16/03/2020.
//  Copyright © 2020 Lan Chee Hong (HLB). All rights reserved.
//

import UIKit
import Vision
import CoreML
import CoreImage

struct Sudoku {
    let mainImage: UIImage? = nil
    let boxes: [UIImage] = []
    let cell: [UIImage] = []
    let dimension: CGRect?
    let data: [[String]] = []
}

enum SudokuImage {
    case main
    case boxes
    case cell
}

class ViewController: UIViewController {
    
    private var imagePicker = UIImagePickerController()
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    private var numberResult: [[String]] = [[]]
    let numberRange: [String] = {
        let range = Array(0...9)
        return range.map({String($0)})
    }()
    
    let sudoku = { () -> Sudoku in
        let startY = UIScreen.main.bounds.height * 0.1
        let endY = UIScreen.main.bounds.height * 0.9
        return Sudoku(dimension: CGRect(x: 0.0, y: startY, width: UIScreen.main.bounds.width, height: endY))
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    @IBAction func onSelectImagePressed(_ sender: Any) {
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum){
            imagePicker.delegate = self
            imagePicker.sourceType = .savedPhotosAlbum
            imagePicker.allowsEditing = false
            
            present(imagePicker, animated: true, completion: nil)
        }
    }
    
    private func parseImage(_image: UIImage) {
        let recogTextRequest = VNRecognizeTextRequest(completionHandler: { [weak self] (request, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("ERROR: \(error)")
                return
            }
            guard let results = request.results, results.count > 0 else {
                print("No text found")
                return
            }
            
            self.numberResult.removeAll()
            
            for result in results {
                if let observation = result as? VNRecognizedTextObservation {
                    for text in observation.topCandidates(1) {
                        
                        //                        print(text.string)
                        //                        print(text.confidence)
                        //                        print(observation.boundingBox)
                        
                        //                        let parsedNumber = self.getNumberParsed(text.string)
                        //                        if !parsedNumber.isEmpty {
                        //                            print("Appended: \(parsedNumber)")
                        self.drawBorderAndSaveImage(observation.boundingBox, true)
                        //                            self.numberResult.append(parsedNumber)
                        //                        }
                        print("\n")
                    }
                }
            }
            
        })
        recogTextRequest.recognitionLevel = .accurate
        recogTextRequest.minimumTextHeight = 0.025
        //        recogTextRequest.customWords = self.numberRange
        
        
        let recogRectRequest = VNDetectRectanglesRequest { [weak self] (request, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error: \(error)")
            }
            
            guard let results = request.results, results.count > 0 else {
                print("No rectangle found")
                return
            }
            
            for result in results {
                if let observation = result as? VNRectangleObservation {
                    print("topLeft: \(observation.topLeft)")
                    print("topRight: \(observation.topRight)")
                    print("bottomLeft: \(observation.bottomLeft)")
                    print("bottomRight: \(observation.bottomRight)")
                    print("confidence: \(observation.confidence)")
                    self.drawBorderAndSaveImage(observation.boundingBox, false)
                    print("\n")
                }
            }
            
            
        }
        recogRectRequest.minimumSize = 0.09
        recogRectRequest.maximumObservations = 90
        recogRectRequest.minimumAspectRatio = 0.6
        recogRectRequest.maximumAspectRatio = 1
        
//        let coreMLRequest = VNCoreMLRequest(model: MNIST())
        
        
        //execute request
        guard let cgImage = imageView.image?.cgImage else { return }
        let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        DispatchQueue.main.async {
            do {
                //                try imageRequestHandler.perform([recogTextRequest])
                try imageRequestHandler.perform([recogRectRequest, recogTextRequest])
                //                for row in self.numberResult {
                //                    print(row)
                //                }
            } catch let error {
                print("Error: \(error)")
            }
        }
        
    }
    
    private func getNumberParsed(_ input: String) -> [String] {
        var parsedResult: [String] = []
        for c in input {
            if let _ = c.wholeNumberValue {
                parsedResult.append(String(c))
            }
        }
        return parsedResult
    }
    
    private func displayResult(_ result: String) {
        resultLabel.text = result
    }
    
    private func drawBorderAndSaveImage(_ boundingBox: CGRect, _ isText: Bool = false) {
        let size = CGSize(width: boundingBox.width * imageView.bounds.width,
                          height: boundingBox.height * imageView.bounds.height)
        let origin = CGPoint(x: boundingBox.minX * imageView.bounds.width,
                             y: (1 - boundingBox.minY) * imageView.bounds.height - size.height)
        
        //draw border
        let layer = CALayer()
        layer.frame = CGRect(origin: origin, size: size)
        layer.borderWidth = 1
        layer.borderColor = isText ? UIColor.blue.cgColor : UIColor.red.cgColor
        self.imageView.layer.addSublayer(layer)
        
        // extract image and save it
        
    }
    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        self.dismiss(animated: true, completion: { () -> Void in
            
        })
        
        guard let result = info[.originalImage] as? UIImage else { return }
        
        let imageViewToScreenRatio: CGFloat = 0.75
        self.imageView.image = result
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.imageView.widthAnchor.constraint(equalToConstant: UIScreen.main.bounds.width * imageViewToScreenRatio).isActive = true
        self.imageView.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.height * imageViewToScreenRatio).isActive = true
        self.imageView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        
        self.view.layoutIfNeeded()
        self.imageView.layer.sublayers = nil
        
        let imageFrame = CGRect(x: 0, y: 0, width: self.imageView.frame.width, height: self.imageView.frame.height)
        let layer = CALayer()
        layer.frame = imageFrame
        layer.borderColor = UIColor.green.cgColor
        layer.borderWidth = 1
        self.imageView.layer.addSublayer(layer)
        parseImage(_image: result)
        
    }
}

