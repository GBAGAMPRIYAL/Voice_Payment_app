import 'package:flutter/material.dart';

import '../controllers/transaction_voice_controller.dart';
import '../services/firestore_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/voice_command_service.dart';

class TransactionsPage extends StatefulWidget {
  final String userId;

  const TransactionsPage({super.key, required this.userId});

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

  @override
  void initState() {
    super.initState();
    transactionVoiceController = TransactionVoiceController(
      ttsService: TtsService.instance,
      sttService: SttService.instance,
      commandService: VoiceCommandService(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
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
      );
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

    final success = await firestoreService.submitTransaction(
      userId: widget.userId,
      receiverName: receiverController.text.trim(),
      amount: amount,
      pin: pinController.text.trim(),
    );

    if (success) {
      final updatedBalance = await firestoreService.getBalance(widget.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction Successful 💸')),
      );
      await TtsService.instance.speak(
        'Transaction successful. Your current balance is rupees $updatedBalance',
      );

      receiverController.clear();
      amountController.clear();
      pinController.clear();

      setState(() {
        confirmAmount = false;
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction failed: wrong PIN or insufficient balance'),
        ),
      );
      await TtsService.instance.speak(
        'Transaction failed. Please check your pin or account balance.',
      );
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
                          confirmAmount = value!;
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
