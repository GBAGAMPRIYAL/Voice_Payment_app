import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/transaction_voice_controller.dart';
import '../services/firestore_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/voice_command_service.dart';

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

  final FirestoreService firestoreService = FirestoreService();
  late final TransactionVoiceController transactionVoiceController;
  bool _voiceFlowStarted = false;

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
      await _startTransactionFlow();
    });
  }

  Future<String> _getCurrentDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return info.fingerprint;
    }

    if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      return info.identifierForVendor ?? 'ios_unknown_device';
    }

    return 'unknown_device';
  }

  Future<void> _startTransactionFlow() async {
    await transactionVoiceController.startTransactionFlow(
      onReceiverCaptured: (value) async {
        if (!mounted) return;
        setState(() {
          receiverController.text = value;
        });
      },
      onAmountCaptured: (value) async {
        if (!mounted) return;
        setState(() {
          amountController.text = value;
        });
      },
      onPinCaptured: (value) async {
        if (!mounted) return;
        setState(() {
          pinController.text = value;
        });
      },
      onConfirmChecked: () async {
        if (!mounted) return;
        setState(() {
          confirmAmount = true;
        });
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
    );
  }

  void _resetTransactionForm() {
    receiverController.clear();
    amountController.clear();
    pinController.clear();
    setState(() {
      confirmAmount = false;
    });
  }

  Future<void> submitTransaction() async {
    if (receiverController.text.isEmpty ||
        amountController.text.isEmpty ||
        pinController.text.isEmpty ||
        confirmAmount == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and confirm amount')),
      );
      await TtsService.instance.speak(
        'Please fill all fields and confirm the amount.',
      );
      await _startTransactionFlow();
      return;
    }

    final amount = int.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      await TtsService.instance.speak('Please enter a valid amount.');
      await _startTransactionFlow();
      return;
    }

    final currentDeviceId = await _getCurrentDeviceId();

    final result = await firestoreService.submitSecureTransaction(
      senderUserId: widget.userId,
      senderName: widget.userName,
      receiverName: receiverController.text.trim(),
      amount: amount,
      pin: pinController.text.trim(),
      currentDeviceId: currentDeviceId,
    );

    final success = result['success'] == true;
    final message = (result['message'] ?? 'Transaction failed').toString();

    if (success) {
      final updatedBalance = await firestoreService.getBalance(widget.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction Successful 💸')),
      );
      await TtsService.instance.speak(
        'Transaction successful. Your current balance is rupees $updatedBalance',
      );
      _resetTransactionForm();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      await TtsService.instance.speak(message);
    }
  }

  @override
  void dispose() {
    receiverController.dispose();
    amountController.dispose();
    pinController.dispose();
    SttService.instance.stop();
    TtsService.instance.stop();
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
              const SizedBox(height: 25),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 22),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock, size: 30),
                  labelText: 'Enter PIN',
                  labelStyle: const TextStyle(fontSize: 20),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 35),
              SizedBox(
                height: 65,
                child: ElevatedButton(
                  onPressed: submitTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
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