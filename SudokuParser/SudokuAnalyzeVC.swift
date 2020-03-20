//
//  SudokuAnalyzeVC.swift
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
    var mainImage: UIImage? = nil
    var boxes: [UIImage] = []
    var cell: [UIImage] = []
    var data: [[String]] = []
}

enum SudokuImage {
    case main
    case boxes
    case cell
}

class SudokuAnalyzeVC: UIViewController {
     
    // MARK: - IBOutlets
    @IBOutlet weak var imageView: UIImageView!
    
    // MARK: - Variables
    private var imagePicker = UIImagePickerController()
    private var numberResult: [[String]] = [[]]
    let numberRange: [String] = {
        let range = Array(0...9)
        return range.map({String($0)})
    }()
    var sudoku = Sudoku()
    
    
    private var detectRectCompletion: (() -> ())?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        promptSelectImage()
        
        detectRectCompletion = {
           print("DONE")
        }
    }
    
    // MARK: - Actions
    func promptSelectImage() {
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum){
            imagePicker.delegate = self
            imagePicker.sourceType = .savedPhotosAlbum
            imagePicker.allowsEditing = false
            
            present(imagePicker, animated: true, completion: nil)
        }
    }
    
    private func parseImage(_image: UIImage) {
        //execute request
        guard let cgImage = imageView.image?.cgImage else { return }
        let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        DispatchQueue.main.async {
            do {
                try imageRequestHandler.perform([self.getVNRectRequest()])
            } catch let error {
                print("Error: \(error)")
            }
        }
        
    }
    
    private func drawBorderAndSaveImage(_ observation: VNRectangleObservation) {
        let boundingBox = observation.boundingBox
        
        let size = CGSize(width: boundingBox.width * imageView.bounds.width,
                          height: boundingBox.height * imageView.bounds.height)
        let origin = CGPoint(x: boundingBox.minX * imageView.bounds.width,
                             y: (1 - boundingBox.minY) * imageView.bounds.height - size.height)
        
        //draw border
        let layer = CALayer()
        layer.frame = CGRect(origin: origin, size: size)
        layer.borderWidth = 1
        layer.borderColor = UIColor.green.cgColor
        self.imageView.layer.addSublayer(layer)
        
        // extract image and save it
        let topLeft = observation.topLeft
        let topRight = observation.topRight
        let botLeft = observation.bottomLeft
        let botRight = observation.bottomRight
        
        let width = (topRight.x - topLeft.x) * imageView.bounds.width
        let height = (topRight.y - botRight.y) * imageView.bounds.height
        
        guard let image = imageView.image else { return }
        guard let cgImage = image.cgImage else { return }
        
        let cropSize = CGSize(width: boundingBox.width * image.size.width, height: boundingBox.height * image.size.height)
        let cropOrigin = CGPoint(x: topLeft.x * image.size.width, y: image.size.height - (topLeft.y * image.size.height))
        let cropRect = CGRect(origin: cropOrigin, size: cropSize)
        guard let croppedCgImage = cgImage.cropping(to: cropRect) else { return }
        let croppedImage = UIImage(cgImage: croppedCgImage)
        
        print(cropRect)
        if cropRect.size.width > UIScreen.main.nativeBounds.width * 0.9 {
            //main box
            sudoku.mainImage = croppedImage
            saveImage("main.jpg", croppedImage)
        } else {
            //sub boxes
            sudoku.boxes.append(croppedImage)
            saveImage("box\(sudoku.boxes.count).jpg", croppedImage)
        }
        
        
    }
    
    //fileName must containe extension of image
    func saveImage(_ fileName: String, _ image: UIImage) -> Bool {
        guard let data = image.jpegData(compressionQuality: 1) ?? image.pngData() else {
            return false
        }
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL else {
            return false
        }
        do {
            try data.write(to: directory.appendingPathComponent(fileName)!)
            print("Saving: \(fileName)")
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
    
    // MARK: - Getters
    private func getNumberParsed(_ input: String) -> [String] {
        var parsedResult: [String] = []
        for c in input {
            if let _ = c.wholeNumberValue {
                parsedResult.append(String(c))
            }
        }
        return parsedResult
    }
    
    private func getVNRectRequest() -> VNDetectRectanglesRequest {
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
                    self.drawBorderAndSaveImage(observation)
                    print("\n")
                }
            }
            
            self.detectRectCompletion?()
            
            
        }
        recogRectRequest.minimumSize = 0.2
        recogRectRequest.maximumObservations = 10
        
        return recogRectRequest
    }
    
    
}

// MARK: - extension: UIImagePickerControllerDelegate, UINavigationControllerDelegate
extension SudokuAnalyzeVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        self.dismiss(animated: true, completion: { () -> Void in
            
        })
        
        guard let result = info[.originalImage] as? UIImage else { return }
        
        self.imageView.image = result
        self.imageView.layer.sublayers = nil
        
        parseImage(_image: result)
        
    }
}
