import 'package:flutter/material.dart';

import '../controllers/login_voice_controller.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/voice_record_service.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController pinController = TextEditingController();

  final FirestoreService firestoreService = FirestoreService();
  final VoiceRecordService voiceRecordService = VoiceRecordService();
  late final LoginVoiceController loginVoiceController;

  bool isRecording = false;
  bool hasRecorded = false;
  bool isPlaying = false;
  bool _voiceFlowStarted = false;

  @override
  void initState() {
    super.initState();
    loginVoiceController = LoginVoiceController(
      ttsService: TtsService.instance,
      sttService: SttService.instance,
    );
    _initializeVoiceModules();
  }

  Future<void> _initializeVoiceModules() async {
    await voiceRecordService.init();
    await TtsService.instance.init();
    await SttService.instance.init();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _voiceFlowStarted) return;
      _voiceFlowStarted = true;
      await loginVoiceController.startLoginFlow(
        onNameCaptured: (value) async {
          if (!mounted) return;
          setState(() {
            nameController.text = value;
          });
        },
        onPinCaptured: (value) async {
          if (!mounted) return;
          setState(() {
            pinController.text = value;
          });
        },
        onAskVoiceSample: () async {
          await TtsService.instance.speak(
            'Now record your voice sample using the record button.',
          );
        },
      );
    });
  }

  Future<void> _startRecording() async {
    final started = await voiceRecordService.startRecording();
    if (!started) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission not granted')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      isRecording = true;
    });
  }

  Future<void> _stopRecording() async {
    await voiceRecordService.stopRecording();
    if (!mounted) return;
    setState(() {
      isRecording = false;
      hasRecorded = true;
    });
  }

  Future<void> _playRecording() async {
    if (voiceRecordService.audioPath == null) return;

    if (voiceRecordService.player.isPlaying) {
      await voiceRecordService.player.stopPlayer();
      if (!mounted) return;
      setState(() {
        isPlaying = false;
      });
      return;
    }

    await voiceRecordService.togglePlayback(
      onPlaybackFinished: () {
        if (!mounted) return;
        setState(() {
          isPlaying = false;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      isPlaying = true;
    });
  }

  Future<void> _resetAll() async {
    nameController.clear();
    pinController.clear();
    await voiceRecordService.reset();

    if (!mounted) return;
    setState(() {
      isRecording = false;
      hasRecorded = false;
      isPlaying = false;
    });
  }

  Future<void> _submitUser() async {
    final String name = nameController.text.trim();
    final String pin = pinController.text.trim();

    if (name.isEmpty || pin.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Missing Details'),
          content: const Text('Please enter Username and PIN'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            )
          ],
        ),
      );
      return;
    }

    if (!hasRecorded) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Voice Sample Missing'),
          content: const Text('Please record voice sample'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            )
          ],
        ),
      );
      return;
    }

    try {
      final userId = name.toLowerCase().replaceAll(' ', '_');

      final user = UserModel(
        userId: userId,
        name: name,
        pin: pin,
        deviceId: 'test_device_001',
        voiceFeatureMatrix: [0.12, 0.45, 0.78, 0.23],
        balance: 5000,
      );

      await firestoreService.registerUser(user);
      final loggedInUser = await firestoreService.loginUser(name, pin);

      if (loggedInUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed')),
        );
        await TtsService.instance.speak('Login failed. Please try again.');
        return;
      }

      await TtsService.instance.stop();
      await SttService.instance.stop();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardPage(
            userName: loggedInUser.name,
            userId: loggedInUser.userId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    pinController.dispose();
    voiceRecordService.dispose();
    SttService.instance.stop();
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎙️ VoicePay'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'PIN Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              icon: Icon(isRecording ? Icons.stop : Icons.mic),
              label: Text(isRecording ? 'Stop Recording' : 'Record Voice Sample'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              ),
              onPressed: () async {
                if (isRecording) {
                  await _stopRecording();
                } else {
                  await _startRecording();
                }
              },
            ),
            const SizedBox(height: 20),
            if (hasRecorded)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                      onPressed: _playRecording,
                    ),
                    Expanded(
                      child: Container(
                        height: 5,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('Voice Sample'),
                  ],
                ),
              ),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _resetAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 15,
                    ),
                  ),
                  child: const Text(
                    'Reset',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  onPressed: _submitUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 15,
                    ),
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
