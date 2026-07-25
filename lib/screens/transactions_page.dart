import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../controllers/transaction_voice_controller.dart';
import '../services/firestore_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/voice_command_service.dart';
import '../services/voice_record_service.dart';

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

  bool confirmAmount = false;
  bool _verificationPassed = false;

  final FirestoreService firestoreService = FirestoreService();
  final VoiceRecordService voiceRecordService = VoiceRecordService();
  late final TransactionVoiceController transactionVoiceController;
  bool _voiceFlowStarted = false;

  static const String _verifyUrl = 'http://192.168.1.43:5000/verify_voice';
  static const double _similarityThreshold = 0.80;

  @override
  void initState() {
    super.initState();
    transactionVoiceController = TransactionVoiceController(
      ttsService: TtsService.instance,
      sttService: SttService.instance,
      commandService: VoiceCommandService(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _voiceFlowStarted) return;
      _voiceFlowStarted = true;
      await voiceRecordService.init();
      await _startTransactionFlow();
    });
  }

  Future<void> _startTransactionFlow() async {
    await transactionVoiceController.startTransactionFlow(
      onReceiverCaptured: (value) async {
        if (!mounted) return;
        setState(() => receiverController.text = value);
      },
      onAmountCaptured: (value) async {
        if (!mounted) return;
        setState(() => amountController.text = value);
      },
      onVoiceAuth: _performVoiceAuth,
      onPinVerify: _verifyPin,
      onConfirmChecked: () async {
        if (!mounted) return;
        setState(() => confirmAmount = true);
      },
      onConfirmedSubmit: submitTransaction,
      onReset: () async {
        _resetTransactionForm();
        await _startTransactionFlow();
      },
      onExit: () async {
        if (!mounted) return;
        Navigator.pop(context);
      },
      onClose: () async {
        await TtsService.instance.speak('Closing the app.');
        await SystemNavigator.pop();
      },
      onVerificationFailed: () async {
        if (!mounted) return;
        setState(() => _verificationPassed = false);
        Navigator.pop(context);
      },
    );
  }

  /// Records audio silently (no TTS during recording) and sends to server.
  Future<bool> _performVoiceAuth() async {
    await SttService.instance.stop();
    await TtsService.instance.stop();
    await Future.delayed(const Duration(milliseconds: 300));

    final started = await voiceRecordService.startRecording();
    if (!started) return false;

    // Record for 4 seconds while user says the fixed phrase
    await Future.delayed(const Duration(seconds: 4));
    await voiceRecordService.stopRecording();

    final audioPath = voiceRecordService.audioPath;
    if (audioPath == null) return false;

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_verifyUrl));
      request.files.add(await http.MultipartFile.fromPath('audio', audioPath));
      request.fields['user_id'] = widget.userId;
      debugPrint('Sending voice verify for user_id: ${widget.userId}');

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final json = jsonDecode(body);
        final similarity = (json['similarity'] as num).toDouble();
        debugPrint('Voice similarity: $similarity');
        if (similarity > _similarityThreshold) {
          setState(() => _verificationPassed = true);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Voice auth error: $e');
    }

    return false;
  }

  /// Verifies PIN against Firestore without executing the transaction.
  Future<bool> _verifyPin(String pin) async {
    try {
      final doc = await firestoreService.getUserDoc(widget.userId);
      if (doc == null) return false;
      final match = doc['pin'] == pin;
      if (match) setState(() => _verificationPassed = true);
      return match;
    } catch (e) {
      debugPrint('PIN verify error: $e');
      return false;
    }
  }

  void _resetTransactionForm() {
    receiverController.clear();
    amountController.clear();
    setState(() {
      confirmAmount = false;
      _verificationPassed = false;
    });
  }

  Future<void> submitTransaction() async {
    if (!_verificationPassed) {
      await TtsService.instance.speak('Verification failed. Transaction not allowed.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification failed. Transaction not allowed.')),
      );
      return;
    }

    if (receiverController.text.isEmpty ||
        amountController.text.isEmpty ||
        !confirmAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and confirm amount')),
      );
      await TtsService.instance.speak('Please fill all fields and confirm the amount.');
      return;
    }

    final amount = int.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      await TtsService.instance.speak('Please enter a valid amount.');
      return;
    }

    // PIN was already verified; pass it via the stored verified pin
    final result = await firestoreService.submitTransactionVerified(
      userId: widget.userId,
      receiverName: receiverController.text.trim(),
      amount: amount,
    );

    if (result == 'success') {
      final updatedBalance = await firestoreService.getBalance(widget.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction Successful 💸')),
      );
      await TtsService.instance.speak(
        'Transaction successful. Your current balance is rupees $updatedBalance',
      );
      _resetTransactionForm();
    } else if (result == 'insufficient_balance') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance')),
      );
      await TtsService.instance.speak(
        'Transaction failed. You do not have sufficient balance.',
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction failed')),
      );
      await TtsService.instance.speak('Transaction failed. Please try again.');
    }
  }

  @override
  void dispose() {
    receiverController.dispose();
    amountController.dispose();
    SttService.instance.stop();
    TtsService.instance.stop();
    voiceRecordService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              TextField(
                controller: receiverController,
                style: const TextStyle(fontSize: 22),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person, size: 30),
                  labelText: 'Receiver Name',
                  labelStyle: const TextStyle(fontSize: 20),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 22),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.currency_rupee, size: 30),
                  labelText: 'Amount',
                  labelStyle: const TextStyle(fontSize: 20),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Transform.scale(
                    scale: 1.4,
                    child: Checkbox(
                      value: confirmAmount,
                      onChanged: (value) {
                        setState(() {
                          confirmAmount = value ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'I confirm the amount',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 35),
              SizedBox(
                height: 65,
                child: ElevatedButton(
                  onPressed: submitTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _verificationPassed ? Colors.deepPurple : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'SUBMIT TRANSACTION',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
