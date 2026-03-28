class UserModel {
  final String userId;
  final String name;
  final String pin;
  final String deviceId;
  final List<double> voiceFeatureMatrix;
  final int balance;

  UserModel({
    required this.userId,
    required this.name,
    required this.pin,
    required this.deviceId,
    required this.voiceFeatureMatrix,
    required this.balance,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'pin': pin,
      'deviceId': deviceId,
      'voiceFeatureMatrix': voiceFeatureMatrix,
      'balance': balance,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      pin: map['pin'] ?? '',
      deviceId: map['deviceId'] ?? '',
      voiceFeatureMatrix: List<double>.from(map['voiceFeatureMatrix'] ?? []),
      balance: map['balance'] ?? 0,
    );
  }
}