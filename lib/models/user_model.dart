import '../services/head_tilt_service.dart';

class UserModel {
  final String userId;
  final String name;
  final String pin;
  final String deviceId;
  final List<int> tapIntervals;
  final List<String> tiltSequence;
  final int balance;

  UserModel({
    required this.userId,
    required this.name,
    required this.pin,
    required this.deviceId,
    required this.tapIntervals,
    required this.tiltSequence,
    required this.balance,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'name': name,
    'pin': pin,
    'deviceId': deviceId,
    'tapIntervals': tapIntervals,
    'tiltSequence': tiltSequence,
    'balance': balance,
  };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    userId: map['userId'] ?? '',
    name: map['name'] ?? '',
    pin: map['pin'] ?? '',
    deviceId: map['deviceId'] ?? '',
    tapIntervals: List<int>.from(map['tapIntervals'] ?? []),
    tiltSequence: List<String>.from(map['tiltSequence'] ?? []),
    balance: map['balance'] ?? 0,
  );

  static List<String> tiltToStrings(List<TiltDirection> seq) =>
      seq.map((d) => d.name).toList();

  static List<TiltDirection> stringsToTilt(List<String> seq) =>
      seq.map((s) => TiltDirection.values.firstWhere((d) => d.name == s)).toList();
}
