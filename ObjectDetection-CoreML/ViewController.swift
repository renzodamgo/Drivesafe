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

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        events = defaults.array(forKey: "events") as? [[String: Any]] ?? []
        return events.count
    }
    
    @IBOutlet weak var lupa: UIImageView!
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = logTable.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! CustomTableViewCell
        cell.logName.text = events[indexPath.row]["name"] as? String
        cell.logDate?.text = events[indexPath.row]["date"] as? String
        return cell
    }
    
    @IBOutlet weak var notfound: UILabel!
    
    
    
    @IBOutlet weak var logTable: UITableView!
    var isDetectionRunning = false
    var isFacingFront = false
    var lastNotFacingFrontTime: Date?
    
    let defaults = UserDefaults.standard
    var events = [[String: Any]]()
    @IBAction func startDetection(_ sender: Any) {
        if (!isDetectionRunning) {
            print("Detection started")
            isDetectionRunning = true
            popupInfo.isHidden = true
            inferenceTimeLayer.isHidden = false
            
            startDButton.isEnabled = true
            startDButton.setTitle("Detener detección", for: .normal)
            startDButton.backgroundColor = UIColor.systemRed
        } else {
            print("Detection stopped")
            isFacingFront = false
            //session.stopRunning()
            isDetectionRunning = false
            popupInfo.isHidden = true
            detectionLayer.sublayers = nil // Clear previous detections from detectionLayer
            inferenceTimeLayer.isHidden = false
            
            startDButton.isEnabled = true
            startDButton.setTitle("Empezar detección", for: .normal)
            
            startDButton.backgroundColor = UIColor.systemGreen
        }
        
        
    }
    
   
    // Capture
    var bufferSize: CGSize = .zero
    var inferenceTime: CFTimeInterval  = 0;
    private let session = AVCaptureSession()
    
    @IBOutlet weak var registro: UILabel!
    @IBOutlet weak var driverty: UILabel!
    // UI/Layers
    @IBOutlet weak var infraccion: UILabel!
    @IBOutlet weak var hora: UILabel!
    @IBOutlet weak var welcome: UILabel!
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var logs: UIView!
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
    var lastLogTime = Date()
    let minimumDelay: TimeInterval = 2.0
    
    // Detection
    var lastEyeClosedTime: Date?
    let eyeClosedDelay: TimeInterval = 1.0
    var lastYawnTime : Date?
    var yawnTimes = 0
    var isYawning:Bool = false
    var visionModel: VNCoreMLModel?
    
    func createLogFile() {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyy-MM-dd_HH:mm:ss.SSS" // modify the format to your preference
        
        guard let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return
        }
        let fileName = "\(dateFormatter.string(from: Date()))benchmark.log"
        print(fileName)
        let logFilePath = (documentsDirectory as NSString).appendingPathComponent(fileName)
        
        print(logFilePath)
        freopen(logFilePath.cString(using: String.Encoding.ascii), "a+", stderr)
    }

    
    
    // Setup
    override func viewDidLoad() {
        popupInfo.isHidden = true
        table_data.delegate = self
        super.viewDidLoad()
        table_data.dataSource = self
        logTable.dataSource = self
        setupCapture()
        setupOutput()
        setupLayers()
        createLogFile()
        
        
        startDButton.isEnabled = false

        
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                UserDefaults.standard.synchronize()
        events = defaults.array(forKey: "events") as? [[String: Any]] ?? []
        try? loadModel()
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
    @IBOutlet weak var popupInfo: UIView!
    
    
    @IBOutlet weak var startDButton: UIButton!
    func setupLayers() {
        logTable.isHidden = true
        startDButton.layer.cornerRadius = 25.0
        
        startDButton.backgroundColor = UIColor.systemGreen
        logs.backgroundColor = UIColor.black
        logs.layer.cornerRadius = 20.0
        
        popupInfo.backgroundColor = UIColor.black.withAlphaComponent(0.95)
        popupInfo.layer.cornerRadius = 5.0
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        rootLayer = previewView.layer
        table_data.layer.cornerRadius = 20
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
        //previewView.addSubview(table_data)
        hora.isHidden = true
        infraccion.isHidden = true
        
        previewView.addSubview(popupInfo)
        previewView.addSubview(welcome)
        previewView.addSubview(lupa)
        previewView.addSubview(hora)
        previewView.addSubview(infraccion)
        previewView.addSubview(notfound)
        previewView.addSubview(driverty)
        previewView.addSubview(logTable)
        previewView.addSubview(logs)
        previewView.addSubview(registro)
        previewView.bringSubviewToFront(startDButton)
        //previewView.bringSubviewToFront(table_data)
        previewView.bringSubviewToFront(popupInfo)
        previewView.bringSubviewToFront(welcome)
        previewView.bringSubviewToFront(driverty)
        previewView.bringSubviewToFront(logs)
        previewView.bringSubviewToFront(logTable)
        previewView.bringSubviewToFront(notfound)
        previewView.bringSubviewToFront(lupa)
        previewView.bringSubviewToFront(hora)
        previewView.bringSubviewToFront(infraccion)
        previewView.bringSubviewToFront(registro)
        table_data.frame = CGRect(x: 0, y: 0, width: previewView.frame.width, height: 200)
        
        inferenceTimeBounds = CGRect(x: rootLayer.frame.midX-95, y: rootLayer.frame.maxY-40, width: 200, height: 17)
        
        inferenceTimeLayer = createRectLayer(inferenceTimeBounds, [1,1,1,1])
        inferenceTimeLayer.cornerRadius = 7
        rootLayer.addSublayer(inferenceTimeLayer)
        inferenceTimeLayer.isHidden = true
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
    
    func loadModel() throws {
        guard let modelURL = Bundle.main.url(forResource: "train14", withExtension: "mlmodelc") else {
            throw NSError(domain: "ViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
        }
        visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
    }
    
    func setupVision() throws {
        //guard let modelURL = Bundle.main.url(forResource: "train14", withExtension: "mlmodelc") else {
        //    throw NSError(domain: "ViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
        //}
        
        if let model = visionModel {
            do {
                let objectRecognition = VNCoreMLRequest(model: model, completionHandler: { (request, error) in
                    DispatchQueue.main.async(execute: {
                        if let results = request.results {
                            self.drawResults(results)
                            if self.isDetectionRunning {
                                // Call the additional function on another thread
                                DispatchQueue.global(qos: .userInitiated).async {
                                    self.processResults(results)
                                }
                            }
                        }
                    })
                })
                self.requests = [objectRecognition]
            }
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
        
        if !isFacingFront {
            for observation in results where observation is VNRecognizedObjectObservation {
                guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                    continue
                }
                let topLabelObservation = objectObservation.labels[0]
           
                if topLabelObservation.identifier == "Facing_Front" {
                    if (!isFacingFront){
                        isFacingFront = true
                    }
                }
            }
            
        } else {
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
                                logEvent(eventName: "Ojos cerrados")
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
                logEvent(eventName: "Bostezo")
                
            }
            
            if let lastTime = lastNotFacingFrontTime, Date().timeIntervalSince(lastTime) >= 2 {
                playSound(resourceName: "not_facing_front")
                logEvent(eventName: "No mira al frente")
                lastNotFacingFrontTime = nil
            }
        }

    }
    
    func playSound(resourceName: String) {

        let now = Date()
        let timeSinceLastPlay = now.timeIntervalSince(lastPlayTime)
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
                
                //            logEvent(eventName: resourceName)
            }
        }
    
    }
    
    func drawResults(_ results: [Any]) {
        var stillFacingFront: Bool = false
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
            
            if topLabelObservation.identifier == "Facing_Front" {
                if (isDetectionRunning == false){
                    isFacingFront = true
                    startDButton.isEnabled = true
                    stillFacingFront = true
                }
                
            }
            
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
        if isDetectionRunning == false && stillFacingFront == false {
            print("Still facing front")
            startDButton.isEnabled = false
        }
        //NSLog(String(format: "Inference time: %.1f ms - fps: %.1f", inferenceTime*1000, 1000/(inferenceTime*1000)))
        
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
            print(eventName)
            self.lupa.isHidden = true
            self.notfound.isHidden = true
            self.logTable.isHidden = false
            self.hora.isHidden = false
            self.infraccion.isHidden = false
            let now = Date()
            let timeSinceLastLog = now.timeIntervalSince(self.lastLogTime)
            print(timeSinceLastLog,self.minimumDelay)

            if timeSinceLastLog >= self.minimumDelay {
                self.lastLogTime = now
                
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
                    "name": eventName,
                    "date": dateString
                ]
                NSLog("\(eventName) at \(dateFormatter.string(from: Date()))")
                events.append(event)
                defaults.set(events, forKey: "events")
                self.table_data.reloadData()
                self.logTable.reloadData()
                
                self.scrollToBottom()
                
            }
        }
    }
    
    func scrollToBottom() {
            let lastRow = logTable.numberOfRows(inSection: 0) - 1
            let indexPath = IndexPath(row: lastRow, section: 0)
            logTable.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }

    
}
