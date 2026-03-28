class TransactionModel {
  final String receiverName;
  final int amount;
  final DateTime dateTime;

  TransactionModel({
    required this.receiverName,
    required this.amount,
    required this.dateTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'receiverName': receiverName,
      'amount': amount,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      receiverName: map['receiverName'] ?? '',
      amount: map['amount'] ?? 0,
      dateTime: DateTime.tryParse(map['dateTime'] ?? '') ?? DateTime.now(),
    );
  }
}