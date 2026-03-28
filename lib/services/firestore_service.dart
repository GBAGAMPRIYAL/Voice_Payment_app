import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/contact_model.dart';
import '../models/transaction_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> registerUser(UserModel user) async {
    final userRef = _firestore.collection('users').doc(user.userId);

    final existingDoc = await userRef.get();
    if (existingDoc.exists) {
      return;
    }

    await userRef.set(user.toMap());

    final defaultContacts = [
      ContactModel(name: 'Ravi', phone: '9000000001'),
      ContactModel(name: 'Priya', phone: '9000000002'),
      ContactModel(name: 'Kumar', phone: '9000000003'),
      ContactModel(name: 'Divya', phone: '9000000004'),
      ContactModel(name: 'Arun', phone: '9000000005'),
    ];

    for (final contact in defaultContacts) {
      await userRef.collection('contacts').add(contact.toMap());
    }
  }

  Future<UserModel?> loginUser(String name, String pin) async {
    final query = await _firestore
        .collection('users')
        .where('name', isEqualTo: name)
        .where('pin', isEqualTo: pin)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return UserModel.fromMap(query.docs.first.data());
  }

  Future<int> getBalance(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    final data = doc.data();
    return data?['balance'] ?? 0;
  }

  Future<List<ContactModel>> getContacts(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .get();

    return snapshot.docs
        .map((doc) => ContactModel.fromMap(doc.data()))
        .toList();
  }

  Future<void> addTransaction(String userId, TransactionModel transaction) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .add(transaction.toMap());
  }

  Future<bool> submitTransaction({
    required String userId,
    required String receiverName,
    required int amount,
    required String pin,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    final doc = await userRef.get();

    if (!doc.exists) return false;

    final data = doc.data()!;
    final currentPin = data['pin'];
    final currentBalance = data['balance'];

    if (currentPin != pin) return false;
    if (currentBalance < amount) return false;

    await userRef.update({
      'balance': currentBalance - amount,
    });

    final transaction = TransactionModel(
      receiverName: receiverName,
      amount: amount,
      dateTime: DateTime.now(),
    );

    await addTransaction(userId, transaction);

    return true;
  }
}