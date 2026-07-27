import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/dashboard_voice_controller.dart';
import '../models/contact_model.dart';
import '../services/firestore_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/voice_command_service.dart';
import 'qr_scanner_screen.dart';
import 'qr_screen.dart';
import 'transactions_page.dart';

class DashboardPage extends StatefulWidget {
  final String userName;
  final String userId;

  const DashboardPage({
    super.key,
    required this.userName,
    required this.userId,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirestoreService firestoreService = FirestoreService();
  late DashboardVoiceController dashboardVoiceController;

  void _reinitVoiceController() {
    dashboardVoiceController = DashboardVoiceController(
      ttsService: TtsService.instance,
      sttService: SttService.instance,
      commandService: VoiceCommandService(),
    );
  }

  @override
  void initState() {
    super.initState();
    _reinitVoiceController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _startHomeVoiceFlow();
    });
  }

  Future<void> _startHomeVoiceFlow() async {
    await dashboardVoiceController.start(
      userName: widget.userName,
      onTransaction: _openTransactionsPage,
      onBalance: () => _showBalance(context, speakOut: true),
      onContact: () => _showContacts(context, speakOut: true),
      onHelp: () => _showHelp(context, speakOut: true),
      onScan: _openQrScanner,
      onClose: _closeApp,
    );
  }

  Future<void> _closeApp() async {
    await TtsService.instance.speak('Closing the app.');
    await SystemNavigator.pop();
  }

  Future<void> _waitForOkVoiceCommand() async {
    while (mounted) {
      await TtsService.instance.speak(
        'Say ok to continue or close to close the app.',
      );

      final commandText = await SttService.instance.listenOnce();
      final command = VoiceCommandService().parse(commandText);

      if (command == VoiceCommandType.ok) {
        if (mounted) Navigator.pop(context);
        return;
      }

      if (command == VoiceCommandType.close) {
        if (mounted) Navigator.pop(context);
        await _closeApp();
        return;
      }

      await TtsService.instance.speak('I did not understand. Please say ok or close.');
    }
  }

  Future<void> _showBalance(BuildContext context, {bool speakOut = false}) async {
    final balance = await firestoreService.getBalance(widget.userId);

    if (speakOut) {
      await TtsService.instance.speak(
        'Your current balance is rupees $balance',
      );
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Balance'),
        content: Text('Current Balance: ₹$balance'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );

    await _waitForOkVoiceCommand();
  }

  Future<void> _showContacts(BuildContext context, {bool speakOut = false}) async {
    final List<ContactModel> contacts =
        await firestoreService.getContacts(widget.userId);

    if (speakOut) {
      if (contacts.isEmpty) {
        await TtsService.instance.speak('No contacts found.');
      } else {
        final names = contacts.map((contact) => contact.name).join(', ');
        await TtsService.instance.speak('Your contacts are $names');
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Contacts'),
        content: SizedBox(
          width: double.maxFinite,
          child: contacts.isEmpty
              ? const Text('No contacts found')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(contact.name),
                      subtitle: Text(contact.phone),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );

    await _waitForOkVoiceCommand();
  }

  Future<void> _showHelp(BuildContext context, {bool speakOut = false}) async {
    const helpText =
        'Available options are transaction to send money, balance to check balance, contact your contact list, help, and close to close the app.';

    if (speakOut) {
      await TtsService.instance.speak(helpText);
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(helpText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );

    await _waitForOkVoiceCommand();
  }

  Future<void> _openQrScanner() async {
    dashboardVoiceController.dispose();
    await TtsService.instance.stop();
    await SttService.instance.stop();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final receiverName = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          userId: widget.userId,
          userName: widget.userName,
        ),
      ),
    );

    if (!mounted) return;

    if (receiverName != null && receiverName.isNotEmpty) {
      // Scanner returned a receiver — go straight to transactions, skip home voice flow
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionsPage(
            userId: widget.userId,
            userName: widget.userName,
            prefillReceiver: receiverName,
          ),
        ),
      );
    }

    if (!mounted) return;
    _reinitVoiceController();
    await _startHomeVoiceFlow();
  }

  Future<void> _showMyQr() async {
    dashboardVoiceController.dispose();
    await TtsService.instance.stop();
    await SttService.instance.stop();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrScreen(
          userId: widget.userId,
          userName: widget.userName,
        ),
      ),
    );
    if (!mounted) return;
    _reinitVoiceController();
    await _startHomeVoiceFlow();
  }

  Future<void> _openTransactionsPage() async {
    dashboardVoiceController.dispose();
    await TtsService.instance.stop();
    await SttService.instance.stop();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionsPage(
          userId: widget.userId,
          userName: widget.userName,
        ),
      ),
    );
    if (!mounted) return;
    _reinitVoiceController();
    await _startHomeVoiceFlow();
  }

  @override
  void dispose() {
    dashboardVoiceController.dispose();
    SttService.instance.stop();
    TtsService.instance.stop();
    super.dispose();
  }

  Widget buildBar(IconData icon, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: Colors.deepPurple),
          const SizedBox(width: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, size: 18),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('VoicePay - ${widget.userName}'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _openTransactionsPage,
              child: buildBar(Icons.receipt_long, 'Transactions'),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _openQrScanner,
              child: buildBar(Icons.qr_code_scanner, 'Scan QR to Pay'),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _showMyQr,
              child: buildBar(Icons.qr_code, 'My QR Code'),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _showBalance(context),
              child: buildBar(Icons.account_balance_wallet, 'Balance'),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _showContacts(context),
              child: buildBar(Icons.contacts, 'Contact'),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _showHelp(context),
              child: buildBar(Icons.support_agent, 'Help & Support'),
            ),
          ],
        ),
      ),
    );
  }
}