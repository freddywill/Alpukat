import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alpukat_ku/main.dart'; // Ganti dengan nama package-mu
import 'package:alpukat_ku/pages/home_page.dart';

void main() {
  testWidgets('Tampilan awal menampilkan tombol kamera dan galeri', (
    WidgetTester tester,
  ) async {
    // Jalankan aplikasi
    await tester.pumpWidget(const AlpukatDetectorApp());

    // Verifikasi tampilan awal
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text("Ambil dari Kamera"), findsOneWidget);
    expect(find.text("Pilih dari Galeri"), findsOneWidget);
    expect(find.text("Deteksi"), findsOneWidget);
    expect(find.text("Belum ada gambar"), findsOneWidget);
  });

  testWidgets('Tombol deteksi tanpa gambar tidak menyebabkan crash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AlpukatDetectorApp());

    final deteksiButton = find.text("Deteksi");
    expect(deteksiButton, findsOneWidget);

    await tester.tap(deteksiButton);
    await tester.pump(); // Update UI

    // Karena tidak ada gambar, kita tidak mengharapkan error, hanya diam
    expect(find.textContaining("Jenis Alpukat"), findsNothing);
  });
}
