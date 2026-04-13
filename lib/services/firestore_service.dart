import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/contact_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> registerUser(UserModel user) async {
    final userRef = _users.doc(user.userId);

    final existingDoc = await userRef.get();
    if (existingDoc.exists) {
      return;
    }

    await userRef.set({
      ...user.toMap(),
      'nameLower': user.name.trim().toLowerCase(),
    });

    await addDefaultContactsIfEmpty(user.userId);
  }

  Future<void> addDefaultContactsIfEmpty(String userId) async {
    final userRef = _users.doc(userId);
    final contactsRef = userRef.collection('contacts');

    final snapshot = await contactsRef.get();
    if (snapshot.docs.isNotEmpty) {
      return;
    }

    final defaultContacts = [
      ContactModel(name: 'mary', phone: '7339557366'),
      ContactModel(name: 'Priya', phone: '9043949982'),
      ContactModel(name: 'Anu', phone: '9486877486'),
      ContactModel(name: 'Riya', phone: '8270835891'),
      ContactModel(name: 'Neha', phone: '9384156404'),
    ];

    final batch = _firestore.batch();
    for (final contact in defaultContacts) {
      final docRef = contactsRef.doc();
      batch.set(docRef, contact.toMap());
    }
    await batch.commit();
  }

  Future<void> _logLoginAttempt({
    required String userId,
    required String userName,
    required String deviceId,
    required String status,
    required String reason,
  }) async {
    await _firestore.collection('login_attempts').add({
      'userId': userId,
      'userName': userName,
      'deviceId': deviceId,
      'status': status,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<UserModel?> secureLoginOrRegisterUser({
    required String name,
    required String pin,
    required String deviceId,
    required List<double> voiceFeatureMatrix,
  }) async {
    final userId = name.trim().toLowerCase().replaceAll(' ', '_');
    final userRef = _users.doc(userId);
    final existingDoc = await userRef.get();

    if (!existingDoc.exists) {
      final newUser = UserModel(
        userId: userId,
        name: name.trim(),
        pin: pin,
        deviceId: deviceId,
        voiceFeatureMatrix: voiceFeatureMatrix,
        balance: 5000,
      );

      await userRef.set({
        ...newUser.toMap(),
        'nameLower': name.trim().toLowerCase(),
      });

      await addDefaultContactsIfEmpty(userId);

      await _logLoginAttempt(
        userId: userId,
        userName: name.trim(),
        deviceId: deviceId,
        status: 'success',
        reason: 'first_time_login',
      );

      return newUser;
    }

    final data = existingDoc.data()!;
    final storedPin = (data['pin'] ?? '').toString();
    final storedDeviceId = (data['deviceId'] ?? '').toString();

    final bool canBindDevice =
        storedDeviceId.isEmpty || storedDeviceId == 'test_device_001';
    final bool pinMatches = storedPin == pin;
    final bool deviceMatches =
        storedDeviceId == deviceId || canBindDevice;

    if (pinMatches && deviceMatches) {
      final updates = <String, dynamic>{
        'nameLower': name.trim().toLowerCase(),
      };

      if (canBindDevice) {
        updates['deviceId'] = deviceId;
      }

      if (voiceFeatureMatrix.isNotEmpty) {
        updates['voiceFeatureMatrix'] = voiceFeatureMatrix;
      }

      await userRef.update(updates);
      await addDefaultContactsIfEmpty(userId);

      await _logLoginAttempt(
        userId: userId,
        userName: name.trim(),
        deviceId: deviceId,
        status: 'success',
        reason: 'validated',
      );

      final refreshed = await userRef.get();
      return UserModel.fromMap(refreshed.data()!);
    }

    await _logLoginAttempt(
      userId: userId,
      userName: name.trim(),
      deviceId: deviceId,
      status: 'fail',
      reason: !pinMatches ? 'pin_mismatch' : 'device_mismatch',
    );

    return null;
  }

  Future<UserModel?> loginUser(String name, String pin) async {
    final query = await _users
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
    final doc = await _users.doc(userId).get();
    final data = doc.data();
    return data?['balance'] ?? 0;
  }

  Future<List<ContactModel>> getContacts(String userId) async {
    final snapshot = await _users.doc(userId).collection('contacts').get();

    return snapshot.docs
        .map((doc) => ContactModel.fromMap(doc.data()))
        .toList();
  }

  Future<void> addTransaction(String userId, TransactionModel transaction) async {
    await _users.doc(userId).collection('transactions').add(transaction.toMap());
  }

  Future<ContactModel?> _getMatchingContact(
    String userId,
    String receiverName,
  ) async {
    final contacts = await getContacts(userId);

    for (final contact in contacts) {
      if (contact.name.trim().toLowerCase() ==
          receiverName.trim().toLowerCase()) {
        return contact;
      }
    }
    return null;
  }

  Future<void> _logFailedTransaction({
    required String senderUserId,
    required String senderName,
    required String senderDeviceId,
    required String receiverName,
    required int amount,
    required String status,
    required String failureReason,
    String? receiverPhone,
  }) async {
    final failedTransaction = TransactionModel(
      receiverName: receiverName,
      amount: amount,
      dateTime: DateTime.now(),
      senderUserId: senderUserId,
      senderName: senderName,
      senderDeviceId: senderDeviceId,
      receiverPhone: receiverPhone,
      status: status,
      type: 'debit',
      failureReason: failureReason,
    );

    await addTransaction(senderUserId, failedTransaction);
  }

  Future<Map<String, dynamic>> submitSecureTransaction({
    required String senderUserId,
    required String senderName,
    required String receiverName,
    required int amount,
    required String pin,
    required String currentDeviceId,
  }) async {
    final senderRef = _users.doc(senderUserId);
    final senderDoc = await senderRef.get();

    if (!senderDoc.exists) {
      return {
        'success': false,
        'message': 'Transaction failed',
      };
    }

    final senderData = senderDoc.data()!;
    final storedPin = (senderData['pin'] ?? '').toString();
    final storedDeviceId = (senderData['deviceId'] ?? '').toString();
    final currentBalance = (senderData['balance'] ?? 0) as int;

    if (storedPin != pin || storedDeviceId != currentDeviceId) {
      await _logFailedTransaction(
        senderUserId: senderUserId,
        senderName: senderName,
        senderDeviceId: currentDeviceId,
        receiverName: receiverName,
        amount: amount,
        status: 'fail',
        failureReason: storedPin != pin ? 'pin_mismatch' : 'device_mismatch',
      );

      return {
        'success': false,
        'message': 'Transaction failed',
      };
    }

    final matchingContact = await _getMatchingContact(senderUserId, receiverName);
    if (matchingContact == null) {
      await _logFailedTransaction(
        senderUserId: senderUserId,
        senderName: senderName,
        senderDeviceId: currentDeviceId,
        receiverName: receiverName,
        amount: amount,
        status: 'fail',
        failureReason: 'invalid_contact',
      );

      return {
        'success': false,
        'message': 'Invalid contact',
      };
    }

    if (currentBalance < amount) {
      await _logFailedTransaction(
        senderUserId: senderUserId,
        senderName: senderName,
        senderDeviceId: currentDeviceId,
        receiverName: receiverName,
        amount: amount,
        status: 'fail',
        failureReason: 'insufficient_balance',
        receiverPhone: matchingContact.phone,
      );

      return {
        'success': false,
        'message': 'Transaction failed',
      };
    }

    final receiverQuery = await _users
        .where('nameLower', isEqualTo: receiverName.trim().toLowerCase())
        .limit(1)
        .get();

    if (receiverQuery.docs.isEmpty) {
      await _logFailedTransaction(
        senderUserId: senderUserId,
        senderName: senderName,
        senderDeviceId: currentDeviceId,
        receiverName: receiverName,
        amount: amount,
        status: 'fail',
        failureReason: 'receiver_not_found',
        receiverPhone: matchingContact.phone,
      );

      return {
        'success': false,
        'message': 'Transaction failed',
      };
    }

    final receiverRef = receiverQuery.docs.first.reference;
    final receiverData = receiverQuery.docs.first.data();
    final receiverUserId = (receiverData['userId'] ?? '').toString();
    final receiverCurrentBalance = (receiverData['balance'] ?? 0) as int;

    final senderTxnRef = senderRef.collection('transactions').doc();
    final receiverTxnRef = receiverRef.collection('transactions').doc();

    await _firestore.runTransaction((transaction) async {
      transaction.update(senderRef, {
        'balance': currentBalance - amount,
      });

      transaction.update(receiverRef, {
        'balance': receiverCurrentBalance + amount,
      });

      transaction.set(senderTxnRef, {
        'receiverName': receiverName,
        'receiverUserId': receiverUserId,
        'receiverPhone': matchingContact.phone,
        'senderUserId': senderUserId,
        'senderName': senderName,
        'senderDeviceId': currentDeviceId,
        'amount': amount,
        'dateTime': DateTime.now().toIso8601String(),
        'status': 'success',
        'type': 'debit',
        'failureReason': null,
      });

      transaction.set(receiverTxnRef, {
        'receiverName': receiverName,
        'receiverUserId': receiverUserId,
        'receiverPhone': matchingContact.phone,
        'senderUserId': senderUserId,
        'senderName': senderName,
        'senderDeviceId': currentDeviceId,
        'amount': amount,
        'dateTime': DateTime.now().toIso8601String(),
        'status': 'success',
        'type': 'credit',
        'failureReason': null,
      });
    });

    return {
      'success': true,
      'message': 'Transaction successful',
    };
  }
}