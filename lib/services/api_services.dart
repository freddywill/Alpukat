import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String apiUrl =
      'http://<IP_BACKEND>:5000/predict'; // ganti dengan IP backend-mu

  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  /// Panggil API backend untuk prediksi
  static Future<Map<String, dynamic>?> predict(File image) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final decoded = jsonDecode(respStr);
        return decoded; // misal {label: ..., confidence: ...}
      } else {
        return null;
      }
    } catch (e) {
      print("Error saat prediksi: $e");
      return null;
    }
  }

  /// Upload gambar ke Storage + simpan riwayat ke Firestore
  static Future<void> saveDetectionResult(
    File image,
    String label,
    double confidence,
  ) async {
    try {
      final filename = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = _storage.ref().child('uploads/$filename.jpg');

      await ref.putFile(image);
      final imageUrl = await ref.getDownloadURL();

      await _firestore.collection('detections').add({
        'label': label,
        'confidence': confidence,
        'image_url': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error saat simpan riwayat: $e");
    }
  }

  /// Ambil riwayat deteksi
  static Future<List<Map<String, dynamic>>> getHistory() async {
    final snapshot = await _firestore
        .collection('detections')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Hapus riwayat + file di Storage
  static Future<void> deleteHistoryItem(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();

      final query = await _firestore
          .collection('detections')
          .where('image_url', isEqualTo: imageUrl)
          .get();

      for (var doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print("Error saat hapus riwayat: $e");
    }
  }
}
