import 'package:flutter/material.dart';
import 'screens/login_page.dart';

void main() {
  runApp(const VoicePayApp());
}

class VoicePayApp extends StatelessWidget {
  const VoicePayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VoicePay',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home:  LoginPage(),
    );
  }
}