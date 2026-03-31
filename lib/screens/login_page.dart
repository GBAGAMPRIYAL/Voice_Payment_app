import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/user_model.dart';
import '../services/firestore_service.dart';
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

  late FlutterSoundRecorder recorder;
  late FlutterSoundPlayer player;

  bool isRecorderReady = false;
  bool isRecording = false;
  bool hasRecorded = false;
  bool isPlaying = false;

  String? audioPath;

  // Change this if testing on real device / different PC setup
  final String serverUrl = "http://192.168.1.6:5000/extract_voice";

  @override
  void initState() {
    super.initState();
    initRecorder();
  }

  Future<void> initRecorder() async {
    final status = await Permission.microphone.request();

    if (status != PermissionStatus.granted) {
      return;
    }

    recorder = FlutterSoundRecorder();
    player = FlutterSoundPlayer();

    await recorder.openRecorder();
    await player.openPlayer();

    isRecorderReady = true;
    setState(() {});
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone permission not granted")),
      );
      return;
    }

    if (!isRecorderReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Recorder is not ready")),
      );
      return;
    }

    final Directory tempDir = await getTemporaryDirectory();
    audioPath = '${tempDir.path}/voice_sample.aac';

    await recorder.startRecorder(
      toFile: audioPath,
      codec: Codec.aacADTS,
    );

    setState(() {
      isRecording = true;
      hasRecorded = false;
    });
  }

  Future<void> _stopRecording() async {
    if (!isRecorderReady) return;

    audioPath = await recorder.stopRecorder();

    setState(() {
      isRecording = false;
      hasRecorded = audioPath != null;
    });
  }

  Future<void> _playRecording() async {
    if (audioPath == null) return;

    if (!isPlaying) {
      await player.startPlayer(
        fromURI: audioPath,
        whenFinished: () {
          if (mounted) {
            setState(() {
              isPlaying = false;
            });
          }
        },
      );

      setState(() {
        isPlaying = true;
      });
    } else {
      await player.stopPlayer();
      setState(() {
        isPlaying = false;
      });
    }
  }

  Future<List<double>?> extractVoiceFeatures() async {
    try {
      if (audioPath == null) {
        debugPrint("No audio file found");
        return null;
      }

      final uri = Uri.parse(serverUrl);
      final request = http.MultipartRequest("POST", uri);

      request.files.add(
        await http.MultipartFile.fromPath('audio', audioPath!),
      );

      request.fields['user_id'] = pinController.text.trim();

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseString = await response.stream.bytesToString();
        final jsonData = jsonDecode(responseString);

        final List<dynamic> features = jsonData["features"];
        return List<double>.from(features);
      } else {
        debugPrint("Server error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Voice extraction error: $e");
      return null;
    }
  }

  void _resetAll() async {
    nameController.clear();
    pinController.clear();

    if (isRecording) {
      await _stopRecording();
    }

    if (isPlaying) {
      await player.stopPlayer();
    }

    setState(() {
      hasRecorded = false;
      isPlaying = false;
      audioPath = null;
    });
  }

  Future<void> _submitUser() async {
    final String name = nameController.text.trim();
    final String pin = pinController.text.trim();

    if (name.isEmpty || pin.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Missing Details"),
          content: const Text("Please enter Username and PIN"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    if (pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PIN must be 4 digits")),
      );
      return;
    }

    if (!hasRecorded || audioPath == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Voice Sample Missing"),
          content: const Text("Please record voice sample"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    // loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final List<double>? voiceFeatures = await extractVoiceFeatures();

      if (mounted) Navigator.pop(context);

      if (voiceFeatures == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Voice extraction failed")),
        );
        return;
      }

      final userId = name.toLowerCase().replaceAll(' ', '_');

      final user = UserModel(
        userId: userId,
        name: name,
        pin: pin,
        deviceId: 'test_device_001',
        voiceFeatureMatrix: voiceFeatures,
        balance: 5000,
      );

      // Using your existing service
      await firestoreService.registerUser(user);

      final loggedInUser = await firestoreService.loginUser(name, pin);

      if (loggedInUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login failed")),
        );
        return;
      }

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
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  void dispose() {
    if (isRecorderReady) {
      recorder.closeRecorder();
      player.closePlayer();
    }
    nameController.dispose();
    pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🎙️ VoicePay"),
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
                labelText: "Username",
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
                labelText: "PIN Number",
                border: OutlineInputBorder(),
                counterText: "",
              ),
            ),
            const SizedBox(height: 25),

            ElevatedButton.icon(
              icon: Icon(isRecording ? Icons.stop : Icons.mic),
              label: Text(
                isRecording ? "Stop Recording" : "Record Voice Sample",
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 15,
                ),
              ),
              onPressed: () {
                if (isRecording) {
                  _stopRecording();
                } else {
                  _startRecording();
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
                    const Text("Voice Sample"),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _resetAll,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text(
                    "Reset",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _submitUser,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text(
                    "Submit",
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