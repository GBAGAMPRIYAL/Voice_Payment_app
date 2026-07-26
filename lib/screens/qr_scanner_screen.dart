import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/firestore_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import 'transactions_page.dart';

class QrScannerScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const QrScannerScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _processing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final raw = barcode!.rawValue!.trim();
    setState(() => _processing = true);
    await _controller.stop();

    String receiverName;
    String receiverId;

    if (raw.startsWith('upi://')) {
      // Parse UPI QR: upi://pay?pa=vpa@upi&pn=Name&...
      final uri = Uri.tryParse(raw);
      final vpa = uri?.queryParameters['pa'] ?? '';
      final name = uri?.queryParameters['pn'] ?? vpa;
      if (vpa.isEmpty) {
        await TtsService.instance.speak('Invalid UPI QR code. Please try again.');
        setState(() => _processing = false);
        await _controller.start();
        return;
      }
      receiverName = name;
      receiverId = vpa; // UPI VPA used as receiver identifier
    } else {
      // VoicePay QR — raw value is userId
      if (raw == widget.userId) {
        await TtsService.instance.speak('You cannot pay yourself.');
        setState(() => _processing = false);
        await _controller.start();
        return;
      }
      final doc = await _firestoreService.getUserDoc(raw);
      if (!mounted) return;
      if (doc == null) {
        await TtsService.instance.speak('User not found. Please try again.');
        setState(() => _processing = false);
        await _controller.start();
        return;
      }
      receiverName = doc['name'] as String? ?? raw;
      receiverId = raw;
    }

    await TtsService.instance.speak('Receiver $receiverName found. Opening payment.');
    if (!mounted) return;

    await TtsService.instance.stop();
    await SttService.instance.stop();
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    // Pop back to dashboard with the receiver name — dashboard will open TransactionsPage
    Navigator.pop(context, receiverName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR to Pay'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.deepPurple, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Supports VoicePay & UPI QR codes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
