# Drivesafe: Facial Recognition App for Detecting Driver Distraction or Fatigue with YOLOV8

<p align="center">
  <image src="https://raw.githubusercontent.com/renzodamgo/Drivesafe/main/results.gif" height="340">
  <p> To see the full video go to: <a href="https://www.youtube.com/watch?v=0VVh7hIVVgw" target="_blank">DRIVERTY - Facial Recognition for Detecting Driver Distraction or Fatigue. </a>
</p>
</p>

## 🎯 Introduction

Drivesafe is an iOS application designed to combat drowsiness and distracted driving using modern machine learning techniques. It emphasizes the integration of PyTorch with Apple's Core ML. Leveraging the power of the YOLOv8 object detection model, DriveSafe is trained on a distinctive dataset that amalgamates records from FORM and YawDD datasets. Its core mission is to detect drowsiness in real-time, fostering safer driving experiences.

## 📜 Dataset Details

- **Base Dataset**: [FORM Dataset](https://zenodo.org/record/6695771)
- **Additional Dataset**: [YawDD](https://ieee-dataport.org/open-access/yawdd-yawning-detection-dataset)

After fusing and manually annotating data from the mentioned sources, the comprehensive [DRIVESAFE Dataset](https://app.roboflow.com/damian-lab/drivesafe/overview) emerges. With Roboflow's assistance, 780 images were annotated. Further preprocessing enhancements, including brightness adjustments and blur effects for data augmentation, expanded the dataset to a grand total of 1886 images.

## 🚀 Model Information

DriveSafe is empowered by the [YOLOv8](https://github.com/ultralytics/ultralytics) model, the latest version of the YOLO family of object detection models developed using PyTorch. These models excel at detecting facial features in individual images, presenting bounding box predictions, classifications, and the accompanying confidence scores.

## 🛠 Prerequisites

- **Python**: Version 3.7 or higher
- **Development Environment**: Xcode

## 🌟 Quick Start

### 1️⃣ Prepare the Model:

Start by cloning the repository:

```bash
git clone https://github.com/renzodamgo/ios-ObjectDetection-YOLO.git
````
### 2️⃣ Launch the App:

Post-cloning, head to the root of the ObjectDetection-CoreML directory and introduce the project with:
```bash
open ObjectDetection-CoreML.xcodeproj
```

### 3️⃣ Build the App:

Build the app inside xCode on an iOS device (e.g. iPhone 11)

## Features and Workflow

DriveSafe boasts a set of features ensuring the driver's safety:

1. YOLOv8 Object Detection: Identifies:
  - Eyes (Open or Closed)
  - Head's orientation
  - Yawning

2. Alarm System: Alerts the driver based on real-time insights:
  - Not looking ahead for over 4 seconds
  - Eyes shut for more than 500 ms
  - Yawning exceeding 2 seconds

3. Audit Log: Retains a log when alarms are triggered, offering insights into potential patterns of distraction or drowsiness.

For installation, ensure the smartphone camera is properly placed on the dashboard behind the steering wheel, capturing the driver's face without any blockages.

DriveSafe's workflow involves:

1. Streaming video data from the camera to the YOLOv8 model.
2. Detecting and categorizing facial aspects.
3. Using Boolean logic to deduce driver's state based on the recognized features.
4. Activating relevant alarms based on the observations.

## 📊 Results

Our preliminary tests have demonstrated promising outcomes:

- Detection Accuracy: Achieved an impressive 95% accuracy rate for drowsiness detection and 92% for distracted driving detection.
- Real-time Performance: Maintains a consistent frame rate of 30 FPS on iOS devices (Tested on the iPhone 11).
- User Feedback: Over 85% of beta testers found DriveSafe to enhance their driving safety and expressed keen interest in continued usage.

## 💖 Acknowledgements & Contributions
-  Daniel Carnero ([@Danilotumix](https://github.com/Danilotumix)) for his contribution in data annotation, metodology, testing and co-authorship of the research paper.
- The team at Roboflow for their impeccable annotation toolkit.
- Thanks to [@tucan9389](https://github.com/tucan9389) for his repo [ObjectDetection-CoreML](https://github.com/tucan9389/ObjectDetection-CoreML) that served as guidance to deploy our model into iOS with CoreML.

## 📌 Important Information

- Explore the training, results, and validation of the YOLOV8 model in this [Jupyter notebook](https://github.com/renzodamgo/Drivesafe/blob/main/drivesafe_yolov8.ipynb).
- A link to the related research paper will be shared once it's published.
- Link to the research paper will be provided upon publication.
- This project and its associated code are governed by the GNU General Public License v3.0. Consequently, any commercial adaptations must remain open source. Legal action will be taken against any infringement.