//
//  Utils.swift
//  ObjectDetection-CoreML
//
//  Created by Julius Hietala on 17.8.2022.
//

import UIKit
import Vision

let classes = ["Eye_Closed", "Eye_Open", "Facing_Down", "Facing_Front", "Hand_With_Cellphone", "Mouth_Closed", "Mouth_Yawning"]
  

let colors = classes.reduce(into: [String: [CGFloat]]()) {
    $0[$1] = [Double.random(in: 0.0 ..< 1.0),Double.random(in: 0.0 ..< 1.0),Double.random(in: 0.0 ..< 1.0),0.2]
}

func createDetectionTextLayer(_ bounds: CGRect, _ text: NSMutableAttributedString) -> CATextLayer {
    let textLayer = CATextLayer()
    textLayer.string = text
    textLayer.bounds = CGRect(x: 0 - 30, y: 0, width: bounds.size.height + 60, height: bounds.size.width + 20)
    textLayer.position = CGPoint(x: bounds.midX - 20, y: bounds.midY)
    textLayer.contentsScale = 10.0
    textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
    return textLayer
}

func createInferenceTimeTextLayer(_ bounds: CGRect, _ text: NSMutableAttributedString) -> CATextLayer {
    let inferenceTimeTextLayer = CATextLayer()
    inferenceTimeTextLayer.string = text
    inferenceTimeTextLayer.frame = bounds
    inferenceTimeTextLayer.contentsScale = 10.0
    inferenceTimeTextLayer.alignmentMode = .center
    return inferenceTimeTextLayer
}

func createRectLayer(_ bounds: CGRect, _ color: [CGFloat]) -> CALayer {
    let shapeLayer = CALayer()
    shapeLayer.bounds = bounds
    shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
    shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: color)
    return shapeLayer
}


