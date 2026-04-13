import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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

  bool isRecording = false;
  bool hasRecorded = false;
  bool isPlaying = false;
  bool _voiceFlowStarted = false;
  bool _submitting = false;

  // Use the exact IP of the laptop where voice_server.py is running.
  // Change only this line if your laptop IP changes.
  final String serverUrl = "http://192.168.139.1:5000/extract_voice";

  @override
  void initState() {
    super.initState();
    _initializeVoiceModules();
  }

  Future<void> _initializeVoiceModules() async {
    await voiceRecordService.init();
    await TtsService.instance.init();
    await SttService.instance.init();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _voiceFlowStarted) return;
      _voiceFlowStarted = true;
      await _startGuidedLoginFlow();
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

  String _extractDigits(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<String> _listenWithRetry({
    required String prompt,
    String retryPrompt = 'I did not hear anything. Let me ask again.',
  }) async {
    while (mounted) {
      await TtsService.instance.speak(prompt);
      final heard = (await SttService.instance.listenOnce()).trim();

      if (!mounted) return '';

      if (heard.isEmpty) {
        await TtsService.instance.speak(retryPrompt);
        continue;
      }

      final lower = heard.toLowerCase();

      if (lower.contains('close')) {
        await TtsService.instance.speak('Closing the app.');
        await SystemNavigator.pop();
        return '';
      }

      if (lower.contains('exit')) {
        Navigator.of(context).maybePop();
        return '';
      }

      return heard;
    }

    return '';
  }

  Future<void> _startGuidedLoginFlow() async {
    await _captureName();
    if (!mounted) return;

    await _capturePin();
    if (!mounted) return;

    await _captureVoiceSample();
  }

  Future<void> _captureName() async {
    while (mounted && nameController.text.trim().isEmpty) {
      final heard = await _listenWithRetry(
        prompt:
            'Welcome to Voice Pay. Please say your name. You can also say reset, exit or close.',
      );

      if (!mounted) return;
      if (heard.isEmpty) continue;

      final lower = heard.toLowerCase();

      if (lower.contains('reset')) {
        await _resetAll();
        continue;
      }

      setState(() {
        nameController.text = heard.trim();
      });
    }
  }

  Future<void> _capturePin() async {
    while (mounted && pinController.text.trim().length != 4) {
      final heard = await _listenWithRetry(
        prompt:
            'Please say your four digit pin number. You can also say reset, exit or close.',
      );

      if (!mounted) return;
      if (heard.isEmpty) continue;

      final lower = heard.toLowerCase();

      if (lower.contains('reset')) {
        await _resetAll();
        await _captureName();
        continue;
      }

      final digits = _extractDigits(heard);

      if (digits.length == 4) {
        setState(() {
          pinController.text = digits;
        });
      } else {
        await TtsService.instance.speak(
          'Pin must contain exactly four digits. Let me ask again.',
        );
      }
    }
  }

  Future<void> _captureVoiceSample() async {
    while (mounted && !hasRecorded) {
      if (!isRecording) {
        await TtsService.instance.speak(
          'Now record your voice sample. Say record to start recording, stop to stop recording, reset to edit details, exit to go back, or close to close the app.',
        );
      }

      final heard =
          (await SttService.instance.listenOnce()).toLowerCase().trim();

      if (!mounted) return;

      if (heard.isEmpty) {
        if (!isRecording) {
          await TtsService.instance.speak(
            'I did not hear any command. Let me ask again.',
          );
        }
        continue;
      }

      if (heard.contains('record') || heard.contains('start')) {
        if (!isRecording) {
          await _startRecording();
          if (isRecording) {
            await TtsService.instance.speak(
              'Recording started. Say stop when you are done.',
            );
          }
        }
        continue;
      }

      if (heard.contains('stop')) {
        if (isRecording) {
          await _stopRecording();
          if (hasRecorded) {
            await TtsService.instance.speak(
              'Voice sample recorded successfully. Say submit to continue, play to hear it, or reset to edit the details.',
            );
            await _postRecordingCommandLoop();
            return;
          }
        } else {
          await TtsService.instance.speak(
            'Recording has not started yet. Say record to start.',
          );
        }
        continue;
      }

      if (heard.contains('reset')) {
        await _resetAll();
        await _startGuidedLoginFlow();
        return;
      }

      if (heard.contains('exit')) {
        Navigator.of(context).maybePop();
        return;
      }

      if (heard.contains('close')) {
        await TtsService.instance.speak('Closing the app.');
        await SystemNavigator.pop();
        return;
      }

      if (!isRecording) {
        await TtsService.instance.speak(
          'Invalid command. Please say record, stop, reset, exit or close.',
        );
      }
    }
  }

  Future<void> _postRecordingCommandLoop() async {
    while (mounted) {
      await TtsService.instance.speak(
        'Say submit to continue, play to hear your voice sample, reset to edit details, exit to go back, or close to close the app.',
      );

      final heard =
          (await SttService.instance.listenOnce()).toLowerCase().trim();

      if (!mounted) return;

      if (heard.isEmpty) {
        await TtsService.instance.speak(
          'I did not hear any command. Let me ask again.',
        );
        continue;
      }

      if (heard.contains('submit')) {
        await _submitUser();
        return;
      }

      if (heard.contains('play')) {
        await _playRecording();
        continue;
      }

      if (heard.contains('reset')) {
        await _resetAll();
        await _startGuidedLoginFlow();
        return;
      }

      if (heard.contains('exit')) {
        Navigator.of(context).maybePop();
        return;
      }

      if (heard.contains('close')) {
        await TtsService.instance.speak('Closing the app.');
        await SystemNavigator.pop();
        return;
      }

      await TtsService.instance.speak(
        'Invalid command. Please say submit, play, reset, exit or close.',
      );
    }
  }

  Future<void> _startRecording() async {
    await SttService.instance.stop();
    await TtsService.instance.stop();
    await Future.delayed(const Duration(milliseconds: 400));

    final started = await voiceRecordService.startRecording();
    if (!started) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission not granted')),
      );
      await TtsService.instance.speak('Microphone permission not granted.');
      return;
    }

    if (!mounted) return;
    setState(() {
      isRecording = true;
      hasRecorded = false;
    });
  }

  Future<void> _stopRecording() async {
    await voiceRecordService.stopRecording();

    if (!mounted) return;
    setState(() {
      isRecording = false;
      hasRecorded = voiceRecordService.audioPath != null;
    });

    // Important: give the file time to fully flush to storage
    await Future.delayed(const Duration(milliseconds: 900));
  }

  Future<void> _playRecording() async {
    if (voiceRecordService.audioPath == null) return;

    await SttService.instance.stop();
    await TtsService.instance.stop();

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

  Future<List<double>?> extractVoiceFeatures() async {
    try {
      final audioPath = voiceRecordService.audioPath;

      if (audioPath == null || audioPath.isEmpty) {
        debugPrint('Voice extraction failed: audio path is null or empty');
        return null;
      }

      final audioFile = File(audioPath);

      final exists = await audioFile.exists();
      if (!exists) {
        debugPrint('Voice extraction failed: file does not exist at $audioPath');
        return null;
      }

      final fileSize = await audioFile.length();
      if (fileSize <= 0) {
        debugPrint('Voice extraction failed: file is empty');
        return null;
      }

      debugPrint('Uploading file to $serverUrl');
      debugPrint('Audio path: $audioPath');
      debugPrint('Audio size: $fileSize bytes');

      final uri = Uri.parse(serverUrl);
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('audio', audioPath),
      );

      request.fields['user_id'] = pinController.text.trim();

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));

      final responseString = await streamedResponse.stream.bytesToString();

      debugPrint('Status code: ${streamedResponse.statusCode}');
      debugPrint('Response body: $responseString');

      if (streamedResponse.statusCode != 200) {
        return null;
      }

      final jsonData = jsonDecode(responseString);

      if (jsonData is! Map<String, dynamic>) {
        debugPrint('Voice extraction failed: invalid JSON object');
        return null;
      }

      if (!jsonData.containsKey('features')) {
        debugPrint('Voice extraction failed: missing "features" key');
        return null;
      }

      final rawFeatures = jsonData['features'];
      if (rawFeatures is! List) {
        debugPrint('Voice extraction failed: features is not a list');
        return null;
      }

      final features = rawFeatures
          .map((e) => (e as num).toDouble())
          .toList();

      if (features.isEmpty) {
        debugPrint('Voice extraction failed: empty features list');
        return null;
      }

      return features;
    } on TimeoutException {
      debugPrint('Voice extraction failed: request timed out');
      return null;
    } catch (e) {
      debugPrint('Voice extraction error: $e');
      return null;
    }
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
    if (_submitting) return;
    _submitting = true;

    final String name = nameController.text.trim();
    final String pin = pinController.text.trim();

    if (name.isEmpty) {
      _submitting = false;
      await TtsService.instance.speak('Username is missing. Let me ask again.');
      await _captureName();
      if (mounted && pinController.text.trim().length == 4 && hasRecorded) {
        await _postRecordingCommandLoop();
      }
      return;
    }

    if (pin.isEmpty || pin.length != 4) {
      _submitting = false;
      await TtsService.instance.speak(
        'Pin is missing or invalid. Let me ask again.',
      );
      await _capturePin();
      if (mounted && hasRecorded) {
        await _postRecordingCommandLoop();
      }
      return;
    }

    if (!hasRecorded || voiceRecordService.audioPath == null) {
      _submitting = false;
      await TtsService.instance.speak(
        'Voice sample is missing. Let me ask again.',
      );
      await _captureVoiceSample();
      return;
    }

    await SttService.instance.stop();
    await TtsService.instance.stop();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final List<double>? voiceFeatures = await extractVoiceFeatures();

      if (mounted) {
        Navigator.pop(context);
      }

      if (voiceFeatures == null) {
        _submitting = false;
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice extraction failed. Check server, laptop IP, ffmpeg, and recorded audio.',
            ),
          ),
        );

        await TtsService.instance.speak(
          'Voice extraction failed. Please check the voice server connection and try again.',
        );

        await _postRecordingCommandLoop();
        return;
      }

      final currentDeviceId = await _getCurrentDeviceId();

      final loggedInUser = await firestoreService.secureLoginOrRegisterUser(
        name: name,
        pin: pin,
        deviceId: currentDeviceId,
        voiceFeatureMatrix: voiceFeatures,
      );

      if (loggedInUser == null) {
        _submitting = false;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid user')),
        );
        await TtsService.instance.speak('Invalid user.');
        return;
      }

      await TtsService.instance.stop();
      await SttService.instance.stop();

      _submitting = false;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardPage(
            userName: loggedInUser.name,
            userId: loggedInUser.userId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }

      _submitting = false;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      await TtsService.instance.speak(
        'An error occurred while logging in.',
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
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'PIN Number',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              icon: Icon(isRecording ? Icons.stop : Icons.mic),
              label: Text(
                isRecording ? 'Stop Recording' : 'Record Voice Sample',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 15,
                ),
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
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _submitUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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