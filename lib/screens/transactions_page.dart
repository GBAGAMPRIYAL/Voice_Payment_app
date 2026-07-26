import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/transaction_voice_controller.dart';
import '../services/device_service.dart';
import '../services/firestore_service.dart';
import '../services/head_tilt_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/tap_pattern_service.dart';
import '../services/voice_command_service.dart';
import '../models/user_model.dart';

class TransactionsPage extends StatefulWidget {
  final String userId;
  final String userName;

  const TransactionsPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final receiverController = TextEditingController();
  final amountController = TextEditingController();
  final pinController = TextEditingController();

  bool confirmAmount = false;
  bool _voiceFlowStarted = false;

  final FirestoreService firestoreService = FirestoreService();
  final TapPatternService tapService = TapPatternService();
  final HeadTiltService tiltService = HeadTiltService();
  bool _capturingTap = false;
  bool _capturingTilt = false;
  Completer<void> _tapDoneCompleter = Completer();
  Completer<void> _tiltDoneCompleter = Completer();
  late final TransactionVoiceController voiceController;

  @override
  void initState() {
    super.initState();
    voiceController = TransactionVoiceController(
      ttsService: TtsService.instance,
      sttService: SttService.instance,
      commandService: VoiceCommandService(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _voiceFlowStarted) return;
      _voiceFlowStarted = true;
      await _startFlow();
    });
  }

  Future<void> _startFlow() async {
    await voiceController.startTransactionFlow(
      onReceiverCaptured: (v) async { if (mounted) setState(() => receiverController.text = v); },
      onAmountCaptured: (v) async { if (mounted) setState(() => amountController.text = v); },
      onPinCaptured: (v) async { if (mounted) setState(() => pinController.text = v); },
      onConfirmChecked: () async { if (mounted) setState(() => confirmAmount = true); },
      onConfirmedSubmit: _submitTransaction,
      onReset: () async { _resetForm(); await _startFlow(); },
      onExit: () async { if (mounted) Navigator.pop(context); },
      onClose: () async {
        await TtsService.instance.speak('Closing the app.');
        await SystemNavigator.pop();
      },
    );
  }

  void _resetForm() {
    receiverController.clear();
    amountController.clear();
    pinController.clear();
    setState(() => confirmAmount = false);
  }

  Future<bool> _verifyDevice() async {
    final savedDeviceId = await firestoreService.getSavedDeviceId(widget.userId);
    final currentDeviceId = await DeviceService.getDeviceId();
    final match = savedDeviceId == currentDeviceId;
    debugPrint('Device check — saved: $savedDeviceId | current: $currentDeviceId | match: $match');
    return match;
  }

  Future<bool> _verifyTapPattern() async {
    final savedIntervals = await firestoreService.getSavedTapIntervals(widget.userId);
    tapService.reset();
    await TtsService.instance.speak('Tap your pattern now. Long press to finish.');
    setState(() => _capturingTap = true);
    await _tapDoneCompleter.future;
    setState(() => _capturingTap = false);
    return TapPatternService.compare(savedIntervals, tapService.getIntervals());
  }

  Future<bool> _verifyHeadTilt() async {
    final savedStrings = await firestoreService.getSavedTiltSequence(widget.userId);
    final savedSeq = UserModel.stringsToTilt(savedStrings);
    tiltService.reset();
    await TtsService.instance.speak('Now do your tilt pattern. Double tap the screen to finish.');
    setState(() => _capturingTilt = true);
    tiltService.startListening();
    await _tiltDoneCompleter.future;
    tiltService.stopListening();
    setState(() => _capturingTilt = false);
    return HeadTiltService.compare(savedSeq, tiltService.sequence);
  }

  Future<void> _submitTransaction() async {
    final amount = int.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      await TtsService.instance.speak('Invalid amount.');
      return;
    }
    final pin = pinController.text.trim();
    if (pin.length != 4) {
      await TtsService.instance.speak('PIN not captured. Please try again.');
      return;
    }

    // Step 1: Device verification
    _showDialog('Verifying device...');
    final deviceMatch = await _verifyDevice();
    if (mounted) Navigator.pop(context);

    if (!deviceMatch) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🚫 Device mismatch. Transaction blocked.'), backgroundColor: Colors.red),
      );
      await TtsService.instance.speak('Device verification failed. Transaction is blocked.');
      return;
    }

    // Step 2: Tap pattern verification
    _tapDoneCompleter = Completer();
    final tapMatch = await _verifyTapPattern();
    if (!tapMatch) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🚫 Tap pattern mismatch. Transaction blocked.'), backgroundColor: Colors.red),
      );
      await TtsService.instance.speak('Tap pattern did not match. Transaction is blocked.');
      return;
    }

    // Step 3: Head tilt verification
    _tiltDoneCompleter = Completer();
    final tiltMatch = await _verifyHeadTilt();
    if (!tiltMatch) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🚫 Tilt pattern mismatch. Transaction blocked.'), backgroundColor: Colors.red),
      );
      await TtsService.instance.speak('Tilt pattern did not match. Transaction is blocked.');
      return;
    }

    // Step 4: Submit transaction (PIN verified inside Firestore)
    final success = await firestoreService.submitTransaction(
      userId: widget.userId,
      receiverName: receiverController.text.trim(),
      amount: amount,
      pin: pin,
    );

    if (success) {
      final balance = await firestoreService.getBalance(widget.userId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction Successful 💸'), backgroundColor: Colors.green),
      );
      await TtsService.instance.speak('All verifications passed. Transaction successful. Your balance is rupees $balance.');
      _resetForm();
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction failed: wrong PIN or low balance'), backgroundColor: Colors.red),
      );
      await TtsService.instance.speak('Transaction failed. Check your pin or balance.');
    }
  }

  void _showDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    receiverController.dispose();
    amountController.dispose();
    pinController.dispose();
    tiltService.stopListening();
    SttService.instance.stop();
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions'), centerTitle: true),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _capturingTap ? () { tapService.recordTap(); setState(() {}); } : null,
        onLongPress: _capturingTap ? () { if (!_tapDoneCompleter.isCompleted) _tapDoneCompleter.complete(); } : null,
        onDoubleTap: _capturingTilt ? () { if (!_tiltDoneCompleter.isCompleted) _tiltDoneCompleter.complete(); } : null,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            _field(receiverController, 'Receiver Name', Icons.person),
            const SizedBox(height: 25),
            _field(amountController, 'Amount', Icons.currency_rupee, isNumber: true),
            const SizedBox(height: 20),
            Row(
              children: [
                Transform.scale(
                  scale: 1.4,
                  child: Checkbox(
                    value: confirmAmount,
                    onChanged: (v) => setState(() => confirmAmount = v ?? false),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('I confirm the amount', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 25),
            _field(pinController, 'Enter PIN', Icons.lock, isNumber: true, obscure: true),
            const SizedBox(height: 15),
            if (_capturingTap)
              const Text('Tap anywhere on screen. Long press when done.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.deepPurple)),
            if (_capturingTilt)
              const Text('Tilt phone now. Double tap anywhere when done.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.orange)),
            const SizedBox(height: 35),
            SizedBox(
              height: 65,
              child: ElevatedButton(
                onPressed: _submitTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('SUBMIT TRANSACTION',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool isNumber = false, bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 22),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 30),
        labelText: label,
        labelStyle: const TextStyle(fontSize: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
