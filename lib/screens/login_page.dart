import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_model.dart';
import '../services/device_service.dart';
import '../services/firestore_service.dart';
import '../services/head_tilt_service.dart';
import '../services/stt_service.dart';
import '../services/tap_pattern_service.dart';
import '../services/tts_service.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final nameController = TextEditingController();
  final pinController = TextEditingController();

  final FirestoreService firestoreService = FirestoreService();
  final TapPatternService tapService = TapPatternService();
  final HeadTiltService tiltService = HeadTiltService();

  bool _voiceFlowStarted = false;
  bool _submitting = false;
  bool _capturingTap = false;
  bool _capturingTilt = false;
  bool _isReturningUser = false;
  UserModel? _existingUser;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await TtsService.instance.init();
    await SttService.instance.init();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _voiceFlowStarted) return;
      _voiceFlowStarted = true;
      await _startGuidedLoginFlow();
    });
  }

  String _extractDigits(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

  Future<String> _listenWithRetry({required String prompt}) async {
    while (mounted) {
      await TtsService.instance.speak(prompt);
      final heard = (await SttService.instance.listenOnce()).trim();
      if (!mounted) return '';
      if (heard.isEmpty) { await TtsService.instance.speak('I did not hear anything. Let me ask again.'); continue; }
      final lower = heard.toLowerCase();
      if (lower.contains('close')) { await TtsService.instance.speak('Closing the app.'); await SystemNavigator.pop(); return ''; }
      if (lower.contains('exit')) { Navigator.of(context).maybePop(); return ''; }
      return heard;
    }
    return '';
  }

  Future<void> _startGuidedLoginFlow() async {
    await _captureName();
    if (!mounted) return;

    if (_isReturningUser) {
      // Returning user: verify tap + tilt pattern
      await _captureVerifyTapPattern();
    } else {
      // New user: ask PIN then register tap + tilt
      await _capturePin();
      if (!mounted) return;
      await _captureTapPattern();
    }
  }

  Future<void> _captureName() async {
    while (mounted && nameController.text.trim().isEmpty) {
      final heard = await _listenWithRetry(prompt: 'Welcome to Voice Pay. Please say your name.');
      if (!mounted || heard.isEmpty) continue;
      if (heard.toLowerCase().contains('reset')) { await _resetAll(); continue; }

      final name = heard.trim();
      setState(() => nameController.text = name);

      // Check Firebase if user already exists
      if (mounted) showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      final existing = await firestoreService.getUserByName(name);
      if (mounted) Navigator.pop(context);

      if (existing != null) {
        _existingUser = existing;
        _isReturningUser = true;
        await TtsService.instance.speak('Welcome back, $name. Please verify your pattern.');
      } else {
        _isReturningUser = false;
        await TtsService.instance.speak('Hello $name. Let us set up your account.');
      }
    }
  }

  Future<void> _capturePin() async {
    while (mounted && pinController.text.trim().length != 4) {
      final heard = await _listenWithRetry(prompt: 'Please say your four digit pin number.');
      if (!mounted || heard.isEmpty) continue;
      if (heard.toLowerCase().contains('reset')) { await _resetAll(); await _captureName(); continue; }
      final digits = _extractDigits(heard);
      if (digits.length == 4) {
        setState(() => pinController.text = digits);
      } else {
        await TtsService.instance.speak('Pin must be exactly four digits. Let me ask again.');
      }
    }
  }

  // ── NEW USER: record tap pattern ──────────────────────────────────────────
  Future<void> _captureTapPattern() async {
    tapService.reset();
    await TtsService.instance.speak(
      'Now set your tap pattern. Tap the screen at least 4 times in your own rhythm. Long press to finish.',
    );
    setState(() => _capturingTap = true);
  }

  Future<void> _onTapDone() async {
    if (_isReturningUser) {
      await _onVerifyTapDone();
    } else {
      if (tapService.tapCount < 4) {
        await TtsService.instance.speak('Please tap at least 4 times first.');
        return;
      }
      setState(() => _capturingTap = false);
      await TtsService.instance.speak('Tap pattern saved with ${tapService.tapCount} taps.');
      await _captureHeadTilt();
    }
  }

  Future<void> _captureHeadTilt() async {
    tiltService.reset();
    await TtsService.instance.speak(
      'Now set your tilt pattern. Tilt your phone left, right, up or down at least 3 times. Double tap the screen to finish.',
    );
    setState(() => _capturingTilt = true);
    tiltService.startListening();
  }

  Future<void> _onTiltDone() async {
    if (_isReturningUser) {
      await _onVerifyTiltDone();
    } else {
      if (tiltService.sequence.length < 3) {
        await TtsService.instance.speak('Please do at least 3 tilts first.');
        return;
      }
      tiltService.stopListening();
      setState(() => _capturingTilt = false);
      await TtsService.instance.speak('Tilt pattern saved with ${tiltService.sequence.length} tilts.');
      await _submitNewUser();
    }
  }

  // ── RETURNING USER: verify tap pattern ───────────────────────────────────
  Future<void> _captureVerifyTapPattern() async {
    tapService.reset();
    await TtsService.instance.speak(
      'Please tap your pattern to verify. Long press when done.',
    );
    setState(() => _capturingTap = true);
  }

  Future<void> _onVerifyTapDone() async {
    if (tapService.tapCount < 2) {
      await TtsService.instance.speak('Please tap at least a few times.');
      return;
    }
    setState(() => _capturingTap = false);
    await _captureVerifyTiltPattern();
  }

  Future<void> _captureVerifyTiltPattern() async {
    tiltService.reset();
    await TtsService.instance.speak(
      'Now tilt your phone to verify your tilt pattern. Double tap when done.',
    );
    setState(() => _capturingTilt = true);
    tiltService.startListening();
  }

  Future<void> _onVerifyTiltDone() async {
    if (tiltService.sequence.isEmpty) {
      await TtsService.instance.speak('Please do at least one tilt.');
      return;
    }
    tiltService.stopListening();
    setState(() => _capturingTilt = false);
    await _verifyAndLogin();
  }

  Future<void> _verifyAndLogin() async {
    final user = _existingUser!;
    final tapMatch = TapPatternService.compare(user.tapIntervals, tapService.getIntervals());
    final tiltMatch = HeadTiltService.compare(
      UserModel.stringsToTilt(user.tiltSequence),
      tiltService.sequence,
    );

    if (tapMatch && tiltMatch) {
      await TtsService.instance.speak('Pattern verified. Welcome back, ${user.name}.');
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => DashboardPage(userName: user.name, userId: user.userId),
      ));
    } else {
      await TtsService.instance.speak('Pattern did not match. Please try again.');
      if (!mounted) return;
      await _captureVerifyTapPattern();
    }
  }

  // ── NEW USER: submit & register ───────────────────────────────────────────
  Future<void> _submitNewUser() async {
    if (_submitting) return;
    _submitting = true;

    final name = nameController.text.trim();
    final pin = pinController.text.trim();

    if (name.isEmpty || pin.length != 4 || tapService.getIntervals().isEmpty || tiltService.sequence.isEmpty) {
      _submitting = false;
      await TtsService.instance.speak('Some details are missing. Please try again.');
      await _startGuidedLoginFlow();
      return;
    }

    await SttService.instance.stop();
    await TtsService.instance.stop();

    if (mounted) showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final userId = name.toLowerCase().replaceAll(' ', '_');
      final deviceId = await DeviceService.getDeviceId();

      final user = UserModel(
        userId: userId,
        name: name,
        pin: pin,
        deviceId: deviceId,
        tapIntervals: tapService.getIntervals(),
        tiltSequence: UserModel.tiltToStrings(tiltService.sequence),
        balance: 5000,
      );

      await firestoreService.registerUser(user);
      final loggedInUser = await firestoreService.loginUser(name, pin);

      if (mounted) Navigator.pop(context);

      if (loggedInUser == null) {
        _submitting = false;
        if (!mounted) return;
        await TtsService.instance.speak('Login failed. Please try again.');
        return;
      }

      _submitting = false;
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => DashboardPage(userName: loggedInUser.name, userId: loggedInUser.userId),
      ));
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _submitting = false;
      debugPrint('Submit error: $e');
      if (!mounted) return;
      await TtsService.instance.speak('An error occurred. Please try again.');
    }
  }

  Future<void> _resetAll() async {
    nameController.clear();
    pinController.clear();
    tapService.reset();
    tiltService.reset();
    tiltService.stopListening();
    _existingUser = null;
    _isReturningUser = false;
    if (!mounted) return;
    setState(() { _capturingTap = false; _capturingTilt = false; });
  }

  @override
  void dispose() {
    nameController.dispose();
    pinController.dispose();
    tiltService.stopListening();
    SttService.instance.stop();
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎙️ VoicePay'), centerTitle: true),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _capturingTap ? () { tapService.recordTap(); setState(() {}); } : null,
        onLongPress: _capturingTap ? _onTapDone : null,
        onDoubleTap: _capturingTilt ? _onTiltDone : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              if (!_isReturningUser)
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'PIN Number', border: OutlineInputBorder(), counterText: ''),
                ),
              if (!_isReturningUser) const SizedBox(height: 20),
              if (_capturingTap)
                Text(
                  _isReturningUser
                      ? 'Tap your pattern to verify. Long press when done.'
                      : 'Tap anywhere on screen. Long press when done.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.deepPurple),
                ),
              if (_capturingTilt)
                Text(
                  _isReturningUser
                      ? 'Tilt to verify your pattern. Double tap when done.'
                      : 'Tilt phone now. Double tap anywhere when done.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.orange),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () async { await _resetAll(); await _startGuidedLoginFlow(); },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                    child: const Text('Reset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  if (!_isReturningUser)
                    ElevatedButton(
                      onPressed: _submitNewUser,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                      child: const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
