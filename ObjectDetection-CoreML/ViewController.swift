//
//  ViewController.swift
//  ObjectDetection-CoreML
//
//  Created by Julius Hietala on 16.8.2022.
//

import UIKit
import AVFoundation
import Vision
import CoreData

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        events = defaults.array(forKey: "events") as? [[String: Any]] ?? []
        return events.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = events[indexPath.row]["name"] as? String
        return cell
    }
    
    var lastNotFacingFrontTime: Date?
    
    let defaults = UserDefaults.standard
    var events = [[String: Any]]()
    
    // Capture
    var bufferSize: CGSize = .zero
    var inferenceTime: CFTimeInterval  = 0;
    private let session = AVCaptureSession()
    
    // UI/Layers
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var table_data: UITableView!
    var rootLayer: CALayer! = nil
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private var detectionLayer: CALayer! = nil
    private var inferenceTimeLayer: CALayer! = nil
    private var inferenceTimeBounds: CGRect! = nil
    
    // Vision
    private var requests = [VNRequest]()
    
    // Audio
    var player: AVAudioPlayer?
    var lastPlayTime = Date()
    let minimumDelay: TimeInterval = 2.0
    
    // Detection
    var lastEyeClosedTime: Date?
    let eyeClosedDelay: TimeInterval = 1.0
    var lastYawnTime : Date?
    var yawnTimes = 0
    var isYawning:Bool = false
    
    func createLogFile() {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyy-MM-dd_HH:mm:ss.SSS" // modify the format to your preference
        
        guard let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return
        }
        let fileName = "\(dateFormatter.string(from: Date())).log"
        print(fileName)
        let logFilePath = (documentsDirectory as NSString).appendingPathComponent(fileName)
        print(logFilePath)
        
        freopen(logFilePath.cString(using: String.Encoding.ascii), "a+", stderr)
    }

    
    
    // Setup
    override func viewDidLoad() {
        super.viewDidLoad()
        table_data.dataSource = self
        setupCapture()
        setupOutput()
        setupLayers()
        createLogFile()

        
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                UserDefaults.standard.synchronize()
        events = defaults.array(forKey: "events") as? [[String: Any]] ?? []
        try? setupVision()
        session.startRunning()
    }

    func setupCapture() {
        var deviceInput: AVCaptureDeviceInput!
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front).devices.first
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        
        do {
            try  videoDevice!.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice!.unlockForConfiguration()
        } catch {
            print(error)
        }
        session.commitConfiguration()
    }
    
    func setupOutput() {
        let videoDataOutput = AVCaptureVideoDataOutput()
        let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
    }
    
    func setupLayers() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        rootLayer = previewView.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
        previewView.addSubview(table_data)
        previewView.bringSubviewToFront(table_data)
        table_data.frame = CGRect(x: 0, y: 0, width: previewView.frame.width, height: 200)
        
        inferenceTimeBounds = CGRect(x: rootLayer.frame.midX-95, y: rootLayer.frame.maxY-70, width: 200, height: 17)
        
        inferenceTimeLayer = createRectLayer(inferenceTimeBounds, [1,1,1,1])
        inferenceTimeLayer.cornerRadius = 7
        rootLayer.addSublayer(inferenceTimeLayer)
        
        detectionLayer = CALayer()
        detectionLayer.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionLayer.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionLayer)
        
        let xScale: CGFloat = rootLayer.bounds.size.width / bufferSize.height
        let yScale: CGFloat = rootLayer.bounds.size.height / bufferSize.width
        
        let scale = fmax(xScale, yScale)
    
        // rotate the layer into screen orientation and scale and mirror
        detectionLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionLayer.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
    }
    
    func setupVision() throws {
        guard let modelURL = Bundle.main.url(forResource: "train12", withExtension: "mlmodelc") else {
            throw NSError(domain: "ViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
        }
        
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let objectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
                DispatchQueue.main.async(execute: {
                    if let results = request.results {
                        self.drawResults(results)
                        
                        // Call the additional function on another thread
                        DispatchQueue.global(qos: .userInitiated).async {
                            self.processResults(results)
                        }
                    }
                })
            })
            self.requests = [objectRecognition]
        } catch let error as NSError {
            print("Model loading went wrong: \(error)")
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            // returns true when complete https://developer.apple.com/documentation/vision/vnimagerequesthandler/2880297-perform
            let start = CACurrentMediaTime()
            try imageRequestHandler.perform(self.requests)
            inferenceTime = (CACurrentMediaTime() - start)

        } catch {
            print(error)
        }
    }
    
    func processResults(_ results: [Any]) {
        // Before detection
        var closedEye:Bool = false
        
        var yawnDetected:Bool = false
        // Perform additional processing of the results on another thread
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            
            // Detection with highest confidence
            let topLabelObservation = objectObservation.labels[0]
            
            if topLabelObservation.identifier != "Facing_Front" && lastNotFacingFrontTime == nil{
                lastNotFacingFrontTime = Date()
            }
            
            if topLabelObservation.identifier == "Facing_Front" {
                lastNotFacingFrontTime = nil
            }


            
            // Check if the label is "Eye_Closed" for more than 1 second
            if topLabelObservation.identifier == "Eye_Closed" {
                closedEye = true
                if topLabelObservation.confidence >= 0.8 {
                    if lastEyeClosedTime == nil {
                        lastEyeClosedTime = Date()
                    } else {
                        let timeSinceEyeClosed = Date().timeIntervalSince(lastEyeClosedTime!)
//                        print(timeSinceEyeClosed)
                        if timeSinceEyeClosed >= 0.6 {
                            lastEyeClosedTime = nil
//                            print("sound")
                            playSound(resourceName: "closed_eyes")
                            logEvent(eventName: "Eyes closed")
                            print(timeSinceEyeClosed)
                        }
                    }
                } else {
                    lastEyeClosedTime = nil
                }
            }
            
            // Check if the label is "Eye_Closed" for more than 1 second
            if topLabelObservation.identifier == "Mouth_Yawning" {
                
                yawnDetected = true
                if topLabelObservation.confidence >= 0.8 {
                    
                    if lastYawnTime == nil {
                        lastYawnTime = Date()
                    } else {
                        let timeSinceYawn = Date().timeIntervalSince(lastYawnTime!)
                        print(timeSinceYawn)
                        if timeSinceYawn >= 2 && isYawning == false {
                            isYawning = true
                            lastYawnTime = nil
                            yawnTimes = yawnTimes + 1
                        }
                    }
                } else {
                    lastYawnTime = nil
                    
                }
                
                
            }
        }
        // After detection
        if (!closedEye){
//            print("Not closedEye")
            lastEyeClosedTime = nil
        }
        
        if (!yawnDetected){
            lastYawnTime = nil
            isYawning = false
        }
        
        if yawnTimes != 0 && yawnTimes != 0 {
            playSound(resourceName: "yawn")
            yawnTimes = 0
            lastYawnTime = nil
            logEvent(eventName: "Yawn")
            
        }
        
        if let lastTime = lastNotFacingFrontTime, Date().timeIntervalSince(lastTime) >= 2 {
            playSound(resourceName: "not_facing_front")
            logEvent(eventName: "Not Facing Front")
            lastNotFacingFrontTime = nil
        }
    }
    
    func playSound(resourceName: String) {
        let now = Date()
        let timeSinceLastPlay = now.timeIntervalSince(lastPlayTime)

        // Check if there is no other audio playing and enough time has elapsed since the last play
        let audioSession = AVAudioSession.sharedInstance()
        if !audioSession.isOtherAudioPlaying && timeSinceLastPlay >= minimumDelay {
            guard let path = Bundle.main.path(forResource: resourceName, ofType:"mp3") else {
                return }
            let url = URL(fileURLWithPath: path)

            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.play()
                lastPlayTime = now // Update the last play time to the current time
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
    
    func drawResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionLayer.sublayers = nil // Clear previous detections from detectionLayer
        inferenceTimeLayer.sublayers = nil
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            
            // Detection with highest confidence
            let topLabelObservation = objectObservation.labels[0]
            
            // Rotate the bounding box into screen orientation
            let boundingBox = CGRect(origin: CGPoint(
                x:1.0 - objectObservation.boundingBox.origin.y-objectObservation.boundingBox.size.height,
                y:1.0 - objectObservation.boundingBox.size.width - objectObservation.boundingBox.origin.x ), size: CGSize(width:objectObservation.boundingBox.size.height,height:objectObservation.boundingBox.size.width))
            
            
            let objectBounds = VNImageRectForNormalizedRect(boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            
            let shapeLayer = createRectLayer(objectBounds, colors[topLabelObservation.identifier]!)
            
            let formattedString = NSMutableAttributedString(string: String(format: "\(topLabelObservation.identifier)\n %.1f%% ", topLabelObservation.confidence*100).capitalized)
            
            let textLayer = createDetectionTextLayer(objectBounds, formattedString)
            shapeLayer.addSublayer(textLayer)
            detectionLayer.addSublayer(shapeLayer)
        }
        
        let formattedInferenceTimeString = NSMutableAttributedString(string: String(format: "Inference time: %.1f ms - fps: %.1f", inferenceTime*1000, 1000/(inferenceTime*1000)))
        
        let inferenceTimeTextLayer = createInferenceTimeTextLayer(inferenceTimeBounds, formattedInferenceTimeString)

        inferenceTimeLayer.addSublayer(inferenceTimeTextLayer)
        
        CATransaction.commit()
    }
        
    // Clean up capture setup
    func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }
    
    func logEvent(eventName: String) {
        DispatchQueue.main.async {
            let dateFormatter = DateFormatter()
            dateFormatter.timeZone = TimeZone.current
            dateFormatter.dateFormat = "yyyy-MM-dd_HH:mm:ss.SSS" // modify the format to your preference
            // Create a reference to the managed object context
            let defaults = UserDefaults.standard
            
            var events = defaults.array(forKey: "events") as? [[String: Any]] ?? []
            
            let currentDate = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            let dateString = formatter.string(from: currentDate)
            print("Detected '\(eventName)' at \(dateString)")
            
            let event: [String: Any] = [
                "name": "\(eventName) at \(dateString)",
                "date": currentDate
            ]
            NSLog("\(eventName) at \(dateFormatter.string(from: Date()))")
            events.append(event)
            defaults.set(events, forKey: "events")
            self.table_data.reloadData()
            self.scrollToBottom()
            
        
        }
    }
    
    func scrollToBottom() {
            let lastRow = table_data.numberOfRows(inSection: 0) - 1
            let indexPath = IndexPath(row: lastRow, section: 0)
            table_data.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }

    
}

