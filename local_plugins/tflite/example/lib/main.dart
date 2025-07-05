import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(App());

const String mobile = "MobileNet";
const String ssd = "SSD MobileNet";
const String yolo = "Tiny YOLOv2";
const String deeplab = "DeepLab";
const String posenet = "PoseNet";

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyApp(),
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  File? _image;
  List<dynamic>? _recognitions;
  String _model = mobile;
  double? _imageHeight;
  double? _imageWidth;
  bool _busy = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> predictImagePicker() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      _busy = true;
    });

    await predictImage(File(pickedFile.path));
  }

  Future<void> predictImage(File image) async {
    if (image == null) return;

    List<dynamic>? res;

    switch (_model) {
      case yolo:
        res = await yolov2Tiny(image);
        break;
      case ssd:
        res = await ssdMobileNet(image);
        break;
      case deeplab:
        res = await segmentMobileNet(image);
        break;
      case posenet:
        res = await poseNet(image);
        break;
      default:
        res = await recognizeImage(image);
    }

    // Dapatkan dimensi gambar
    final completer = Completer<void>();
    final imageStream = FileImage(image).resolve(ImageConfiguration());
    ImageStreamListener? listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      _imageHeight = info.image.height.toDouble();
      _imageWidth = info.image.width.toDouble();
      completer.complete();
      imageStream.removeListener(listener!);
    });
    imageStream.addListener(listener);
    await completer.future;

    setState(() {
      _recognitions = res;
      _image = image;
      _busy = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _busy = true;
    loadModel().then((_) {
      setState(() {
        _busy = false;
      });
    });
  }

  Future<void> loadModel() async {
    await Tflite.close();
    try {
      String? res = "";
      switch (_model) {
        case yolo:
          res = await Tflite.loadModel(
            model: "assets/yolov2_tiny.tflite",
            labels: "assets/yolov2_tiny.txt",
            // useGpuDelegate: true,
          );
          break;
        case ssd:
          res = await Tflite.loadModel(
            model: "assets/ssd_mobilenet.tflite",
            labels: "assets/ssd_mobilenet.txt",
            // useGpuDelegate: true,
          );
          break;
        case deeplab:
          res = await Tflite.loadModel(
            model: "assets/deeplabv3_257_mv_gpu.tflite",
            labels: "assets/deeplabv3_257_mv_gpu.txt",
            // useGpuDelegate: true,
          );
          break;
        case posenet:
          res = await Tflite.loadModel(
            model: "assets/posenet_mv1_075_float_from_checkpoints.tflite",
            // useGpuDelegate: true,
          );
          break;
        default:
          res = await Tflite.loadModel(
            model: "assets/mobilenet_v1_1.0_224.tflite",
            labels: "assets/mobilenet_v1_1.0_224.txt",
            // useGpuDelegate: true,
          );
      }
      print("Model loaded: $res");
    } on PlatformException {
      print('Failed to load model.');
    }
  }

  Uint8List imageToByteListFloat32(
      img.Image image, int inputSize, double mean, double std) {
    if (image.width != inputSize || image.height != inputSize) {
      image = img.copyResize(image, width: inputSize, height: inputSize);
    }

    var convertedBytes = Float32List(inputSize * inputSize * 3);
    int pixelIndex = 0;

    for (int i = 0; i < inputSize; i++) {
      for (int j = 0; j < inputSize; j++) {
        int pixel = image.getPixel(j, i);
        int r = (pixel >> 16) & 0xFF;
        int g = (pixel >> 8) & 0xFF;
        int b = pixel & 0xFF;

        convertedBytes[pixelIndex++] = (r - mean) / std;
        convertedBytes[pixelIndex++] = (g - mean) / std;
        convertedBytes[pixelIndex++] = (b - mean) / std;
      }
    }

    return convertedBytes.buffer.asUint8List();
  }

  Future<List<dynamic>> recognizeImage(File image) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    var recognitions = await Tflite.runModelOnImage(
      path: image.path,
      numResults: 6,
      threshold: 0.05,
      imageMean: 127.5,
      imageStd: 127.5,
    );
    int endTime = DateTime.now().millisecondsSinceEpoch;
    print("Inference took ${endTime - startTime}ms");
    return recognitions ?? [];
  }

  Future<List<dynamic>> recognizeImageBinary(File image) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    var imageBytes = await File(image.path).readAsBytes();
    img.Image? oriImage = img.decodeImage(imageBytes);
    if (oriImage == null) {
      throw Exception("Failed to decode image");
    }
    img.Image resizedImage = img.copyResize(oriImage, height: 224, width: 224);
    var recognitions = await Tflite.runModelOnBinary(
      binary: imageToByteListFloat32(resizedImage, 224, 127.5, 127.5),
      numResults: 6,
      threshold: 0.05,
    );
    int endTime = DateTime.now().millisecondsSinceEpoch;
    print("Inference took ${endTime - startTime}ms");
    return recognitions ?? [];
  }

  Future<List<dynamic>> yolov2Tiny(File image) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    var recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      model: "YOLO",
      threshold: 0.3,
      imageMean: 0.0,
      imageStd: 255.0,
      numResultsPerClass: 1,
    );
    int endTime = DateTime.now().millisecondsSinceEpoch;
    print("Inference took ${endTime - startTime}ms");
    return recognitions ?? [];
  }

  Future<List<dynamic>> ssdMobileNet(File image) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    var recognitions = await Tflite.detectObjectOnImage(
      path: image.path,
      numResultsPerClass: 1,
    );
    int endTime = DateTime.now().millisecondsSinceEpoch;
    print("Inference took ${endTime - startTime}ms");
    return recognitions ?? [];
  }

  Future<List<dynamic>> segmentMobileNet(File image) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    var recognitions = await Tflite.runSegmentationOnImage(
      path: image.path,
      imageMean: 127.5,
      imageStd: 127.5,
    );
    int endTime = DateTime.now().millisecondsSinceEpoch;
    print("Inference took ${endTime - startTime}ms");
    return recognitions ?? [];
  }

  Future<List<dynamic>> poseNet(File image) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    var recognitions = await Tflite.runPoseNetOnImage(
      path: image.path,
      numResults: 2,
    );
    int endTime = DateTime.now().millisecondsSinceEpoch;
    print("Inference took ${endTime - startTime}ms");
    return recognitions ?? [];
  }

  Future<void> onSelect(String model) async {
    setState(() {
      _busy = true;
      _model = model;
      _recognitions = null;
    });
    await loadModel();

    if (_image != null) {
      await predictImage(_image!);
    } else {
      setState(() {
        _busy = false;
      });
    }
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imageHeight == null || _imageWidth == null) return [];

    double factorX = screen.width;
    double factorY = _imageHeight! / _imageWidth! * screen.width;

    Color colorPick = Colors.red;

    return _recognitions!.map((re) {
      if (re["rect"] == null) return Container();

      var _x = re["rect"]["x"] * factorX;
      var _w = re["rect"]["w"] * factorX;
      var _y = re["rect"]["y"] * factorY;
      var _h = re["rect"]["h"] * factorY;

      return Positioned(
        left: max(0, _x),
        top: max(0, _y),
        width: _w,
        height: _h,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: colorPick,
              width: 3,
            ),
          ),
          child: Text(
            "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = colorPick,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget renderBoxesSeg(Size screen) {
    // Contoh untuk segmentasi bisa dibuat berbeda (tidak seperti bounding box).
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    List<Widget> stackChildren = [];

    stackChildren.add(Positioned(
      top: 10,
      left: 10,
      child: DropdownButton<String>(
        value: _model,
        items: <String>[mobile, ssd, yolo, deeplab, posenet]
            .map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (String? val) {
          if (val != null) onSelect(val);
        },
      ),
    ));

    stackChildren.add(Positioned(
      top: 50,
      left: 10,
      child: ElevatedButton(
        onPressed: _busy ? null : predictImagePicker,
        child: Text("Pick Image"),
      ),
    ));

    if (_image != null) {
      stackChildren.add(Positioned(
        top: 90,
        left: 10,
        right: 10,
        child: Image.file(_image!),
      ));
    }

    stackChildren.addAll(renderBoxes(size));

    if (_busy) {
      stackChildren.add(Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('TFLite Example')),
      body: Stack(children: stackChildren),
    );
  }
}
