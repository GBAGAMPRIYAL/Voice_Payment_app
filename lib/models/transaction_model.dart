class TransactionModel {
  final String receiverName;
  final int amount;
  final DateTime dateTime;

  final String? senderUserId;
  final String? senderName;
  final String? senderDeviceId;
  final String? receiverUserId;
  final String? receiverPhone;
  final String? status;
  final String? type;
  final String? failureReason;

  TransactionModel({
    required this.receiverName,
    required this.amount,
    required this.dateTime,
    this.senderUserId,
    this.senderName,
    this.senderDeviceId,
    this.receiverUserId,
    this.receiverPhone,
    this.status,
    this.type,
    this.failureReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'receiverName': receiverName,
      'amount': amount,
      'dateTime': dateTime.toIso8601String(),
      'senderUserId': senderUserId,
      'senderName': senderName,
      'senderDeviceId': senderDeviceId,
      'receiverUserId': receiverUserId,
      'receiverPhone': receiverPhone,
      'status': status,
      'type': type,
      'failureReason': failureReason,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      receiverName: map['receiverName'] ?? '',
      amount: map['amount'] ?? 0,
      dateTime: DateTime.tryParse(map['dateTime'] ?? '') ?? DateTime.now(),
      senderUserId: map['senderUserId'],
      senderName: map['senderName'],
      senderDeviceId: map['senderDeviceId'],
      receiverUserId: map['receiverUserId'],
      receiverPhone: map['receiverPhone'],
      status: map['status'],
      type: map['type'],
      failureReason: map['failureReason'],
    );
  }
}