import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dashboard_page.dart';
class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController pinController = TextEditingController();

  FlutterSoundRecorder recorder = FlutterSoundRecorder();
  FlutterSoundPlayer player = FlutterSoundPlayer();

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

  @override
  void dispose() {
    recorder.closeRecorder();
    player.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("🎙️ VoicePay"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Username
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Username",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),

            // PIN
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4, // ⭐ limit to 6 digits
              decoration: InputDecoration(
                labelText: "4 Digit PIN",
                border: OutlineInputBorder(),
                counterText: "", // hides 0/6 text
              ),
            ),
            SizedBox(height: 25),

            // RECORD BUTTON
            ElevatedButton.icon(
              icon: Icon(isRecording ? Icons.stop : Icons.mic),
              label: Text(isRecording
                  ? "Stop Recording"
                  : "Record Voice Sample"),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              ),
              onPressed: () {
                if (isRecording) {
                  _stopRecording();
                } else {
                  _startRecording();
                }
              },
            ),
            SizedBox(height: 20),

            // VOICE PREVIEW LIKE WHATSAPP
            if (hasRecorded)
              Container(
                padding: EdgeInsets.all(10),
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
                    SizedBox(width: 10),
                    Text("Voice Sample"),
                  ],
                ),
              ),

            SizedBox(height: 30),

            // RESET & SUBMIT BUTTONS SIDE BY SIDE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _resetAll,
                  style: ElevatedButton.styleFrom(
                      padding:
                      EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      backgroundColor: Colors.blue),
                  child: Text(
                    "Reset",
                    style: TextStyle(
                      color: Colors.white, // <-- change text color here
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    String name = nameController.text.trim();
                    String pin = pinController.text.trim();

                    // ❌ if fields empty -> show alert
                    if (name.isEmpty || pin.isEmpty) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Missing Details"),
                          content: Text("Please enter Username and PIN"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text("OK"),
                            )
                          ],
                        ),
                      );
                      return;
                    }

                    // ✅ if filled -> go to next page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DashboardPage(userName: name),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      padding:
                      EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      backgroundColor: Colors.blue),
                  child: Text(
                    "Submit",
                    style: TextStyle(
                      color: Colors.white, // <-- change text color here
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