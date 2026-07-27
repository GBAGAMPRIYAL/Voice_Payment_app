import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecordService {
  final FlutterSoundRecorder recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer player = FlutterSoundPlayer();

  bool _initialized = false;
  String? audioPath;

  Future<void> init() async {
    if (_initialized) return;
    await Permission.microphone.request();
    await recorder.openRecorder();
    await player.openPlayer();
    _initialized = true;
  }

  Future<bool> startRecording() async {
    await init();
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;

    final tempDir = await getTemporaryDirectory();
    audioPath = '${tempDir.path}/voice_sample.aac';
    await recorder.startRecorder(toFile: audioPath);
    return true;
  }

  Future<void> stopRecording() async {
    if (recorder.isRecording) {
      await recorder.stopRecorder();
    }
  }

  Future<bool> startPinRecording() async {
    await init();
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;
    final tempDir = await getTemporaryDirectory();
    audioPath = '${tempDir.path}/pin_voice_sample.aac';
    await recorder.startRecorder(toFile: audioPath);
    return true;
  }

  Future<void> stopPinRecording() async {
    if (recorder.isRecording) {
      await recorder.stopRecorder();
    }
  }

  Future<void> togglePlayback({required void Function() onPlaybackFinished}) async {
    if (audioPath == null) return;

    if (player.isPlaying) {
      await player.stopPlayer();
      return;
    }

    await player.startPlayer(
      fromURI: audioPath,
      whenFinished: onPlaybackFinished,
    );
  }

  Future<void> reset() async {
    if (recorder.isRecording) {
      await recorder.stopRecorder();
    }
    if (player.isPlaying) {
      await player.stopPlayer();
    }

    if (audioPath != null) {
      final file = File(audioPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    audioPath = null;
  }

  Future<void> dispose() async {
    if (recorder.isRecording) {
      await recorder.stopRecorder();
    }
    if (player.isPlaying) {
      await player.stopPlayer();
    }
    await recorder.closeRecorder();
    await player.closePlayer();
  }
}
