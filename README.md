# Object Detection with PyTorch, Core ML, and Vision on iOS

<p align="center">
  <img src="https://raw.githubusercontent.com/renzodamgo/ios-ObjectDetection-YOLO/main/results.jpeg" align="center" height="500">
</p>

## Introduction
This demo app was built to showcase how to use PyTorch with Apple's Core ML. The app uses YOLOv8 tranied with the [FORM Dataset](https://zenodo.org/record/6695771).

[YOLOv5](https://github.com/ultralytics/yolov5) is a family of object detection models built with PyTorch. The models enable detecting objects from single images, where the model output includes predictions of bounding boxes, the bounding box classification, and the confidence of the prediction.


## Prerequisites

* Python >=3.7 
* Xcode

## Quick Start

### 1. Prepare the model

Start by cloning the repository:

```
git clone https://github.com/renzodamgo/ios-ObjectDetection-YOLO.git
```

### 2. Run the app

Navigate to the root of the `ObjectDetection-CoreML` directory and open the project with:

`open ObjectDetection-CoreML.xcodeproj`

Select an iOS simulator or device on Xcode to run the app. The app will start outputting predictions and the current inference time:

<p align="center">
  <img src="https://raw.githubusercontent.com/renzodamgo/ios-ObjectDetection-YOLO/main/results.jpeg" align="center" height="500">
</p>
