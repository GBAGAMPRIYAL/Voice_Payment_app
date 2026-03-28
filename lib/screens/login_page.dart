import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController pinController = TextEditingController();

  FlutterSoundRecorder recorder = FlutterSoundRecorder();
  FlutterSoundPlayer player = FlutterSoundPlayer();

  final FirestoreService firestoreService = FirestoreService();

  bool isRecording = false;
  bool hasRecorded = false;
  bool isPlaying = false;
  String? audioPath;

  @override
  void initState() {
    super.initState();
    initRecorder();
  }

  Future initRecorder() async {
    await Permission.microphone.request();
    await recorder.openRecorder();
    await player.openPlayer();
  }

  Future<void> _startRecording() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      print("Microphone permission not granted");
      return;
    }

    Directory tempDir = await getTemporaryDirectory();
    audioPath = '${tempDir.path}/voice.aac';

    await recorder.startRecorder(toFile: audioPath);
    setState(() {
      isRecording = true;
    });
  }

  Future<void> _stopRecording() async {
    await recorder.stopRecorder();
    setState(() {
      isRecording = false;
      hasRecorded = true;
    });
  }

  Future<void> _playRecording() async {
    if (audioPath != null && !isPlaying) {
      await player.startPlayer(
        fromURI: audioPath,
        whenFinished: () {
          setState(() {
            isPlaying = false;
          });
        },
      );
      setState(() {
        isPlaying = true;
      });
    } else if (isPlaying) {
      await player.stopPlayer();
      setState(() {
        isPlaying = false;
      });
    }
  }

  void _resetAll() {
    nameController.clear();
    pinController.clear();
    if (isRecording) {
      _stopRecording();
    }
    if (isPlaying) {
      player.stopPlayer();
    }
    setState(() {
      hasRecorded = false;
      audioPath = null;
    });
  }

  Future<void> _submitUser() async {
    String name = nameController.text.trim();
    String pin = pinController.text.trim();

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
          title: const Text("Voice Sample Missing"),
          content: const Text("Please record voice sample"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login failed")),
        );
        return;
      }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  void dispose() {
    recorder.closeRecorder();
    player.closePlayer();
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
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "PIN Number",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),

            ElevatedButton.icon(
              icon: Icon(isRecording ? Icons.stop : Icons.mic),
              label: Text(isRecording
                  ? "Stop Recording"
                  : "Record Voice Sample"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
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
                        horizontal: 30, vertical: 15),
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
                        horizontal: 30, vertical: 15),
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