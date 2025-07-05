import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tflite/tflite.dart';
import '../services/api_services.dart';
import 'history_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  String _result = "";
  bool _loading = false;

  final picker = ImagePicker();
  List<String> _labels = [];
  static const int _modelOutputClasses = 5;

  @override
  void initState() {
    super.initState();
    _loadModel().then((_) => _loadLabels());
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  Future<void> _loadModel() async {
    try {
      String? res = await Tflite.loadModel(
        model: "assets/model.tflite",
        labels: "assets/labels.txt",
      );
      print("Model loaded: $res");
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  Future<void> _loadLabels() async {
    try {
      final raw = await DefaultAssetBundle.of(
        context,
      ).loadString("assets/labels.txt");
      final labels = raw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      setState(() => _labels = labels);

      if (_labels.length != _modelOutputClasses) {
        setState(() {
          _result =
              "Error: Jumlah label (${_labels.length}) ≠ kelas model ($_modelOutputClasses)";
        });
      } else {
        print("Labels loaded: $_labels");
      }
    } catch (e) {
      print("Error loading labels: $e");
    }
  }

  Future<void> _getImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _result = "";
      });
    }
  }

  Future<void> _submitImage() async {
    if (_image == null) return;
    setState(() => _loading = true);

    try {
      final resized = await _resizeImage(_image!);
      await _classifyImage(resized);
    } catch (e) {
      setState(() => _result = "Terjadi kesalahan saat deteksi");
    }

    setState(() => _loading = false);
  }

  Future<File> _resizeImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final oriImage = img.decodeImage(bytes);
    if (oriImage == null) return imageFile;

    final resized = img.copyResize(oriImage, width: 224, height: 224);
    final tempDir = await getTemporaryDirectory();
    final resizedPath = "${tempDir.path}/resized.png";

    return File(resizedPath)..writeAsBytesSync(img.encodePng(resized));
  }

  Future<void> _classifyImage(File image) async {
    final recognitions = await Tflite.runModelOnImage(
      path: image.path,
      imageMean: 0.0,
      imageStd: 255.0,
      numResults: 5,
      threshold: 0.05,
    );

    print("Recognitions: $recognitions");

    if (recognitions != null && recognitions.isNotEmpty) {
      final label = recognitions.first["label"] ?? "Tidak terdeteksi";
      final confidence = recognitions.first["confidence"] ?? 0.0;

      setState(() {
        _result = label;
      });

      // Simpan ke Firebase dengan error handling dan feedback UI
      try {
        await ApiService.saveDetectionResult(image, label.trim(), confidence);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menyimpan hasil deteksi: \$e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      setState(() {
        _result = "Tidak terdeteksi";
      });
    }
  }

  Widget _buildButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: Colors.black87),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/bg_alpukat.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            color: Colors.black.withOpacity(0.3),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        const Center(
                          child: Text(
                            "Deteksi Daun Alpukat",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Column(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.info_outline,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  showAboutDialog(
                                    context: context,
                                    applicationName: "Deteksi Daun Alpukat",
                                    applicationVersion: "1.0",
                                    children: const [
                                      Text(
                                        "Aplikasi untuk mendeteksi jenis daun tanaman alpukat.",
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const Text(
                                "tentang\naplikasi",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _image == null
                        ? Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: Colors.white54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                "BELUM ADA GAMBAR",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _image!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          _result.isEmpty
                              ? "jenis alpukat"
                              : "Jenis Alpukat: $_result",
                          style: TextStyle(
                            color: _result.isEmpty
                                ? Colors.black54
                                : Colors.green[900],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildButton(
                          Icons.camera_alt,
                          "kamera",
                          () => _getImage(ImageSource.camera),
                        ),
                        _buildButton(
                          Icons.photo_library,
                          "galeri",
                          () => _getImage(ImageSource.gallery),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[900],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(160, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: (_loading || _image == null)
                          ? null
                          : _submitImage,
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : const Text("deteksi"),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green[900],
                        minimumSize: const Size(160, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.green),
                        ),
                      ),
                      icon: const Icon(Icons.history),
                      label: const Text("Riwayat"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HistoryPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
