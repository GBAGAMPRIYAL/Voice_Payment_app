import 'package:flutter/material.dart';
import '../models/contact_model.dart';
import '../services/firestore_service.dart';
import 'transactions_page.dart';

class DashboardPage extends StatelessWidget {
  final String userName;
  final String userId;

  const DashboardPage({
    super.key,
    required this.userName,
    required this.userId,
  });

  Future<void> _showBalance(BuildContext context) async {
    final firestoreService = FirestoreService();
    final balance = await firestoreService.getBalance(userId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Balance"),
        content: Text("Current Balance: ₹$balance"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  Future<void> _showContacts(BuildContext context) async {
    final firestoreService = FirestoreService();
    final List<ContactModel> contacts = await firestoreService.getContacts(userId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Contacts"),
        content: SizedBox(
          width: double.maxFinite,
          child: contacts.isEmpty
              ? const Text("No contacts found")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(contact.name),
                      subtitle: Text(contact.phone),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Help & Support"),
        content: const Text("Support section coming soon."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("VoicePay - $userName"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TransactionsPage(userId: userId),
                  ),
                );
              },
              child: buildBar(Icons.receipt_long, "Transactions"),
            ),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: () => _showBalance(context),
              child: buildBar(Icons.account_balance_wallet, "Balance"),
            ),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: () => _showContacts(context),
              child: buildBar(Icons.contacts, "Contact"),
            ),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: () => _showHelp(context),
              child: buildBar(Icons.support_agent, "Help & Support"),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBar(IconData icon, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: Colors.deepPurple),
          const SizedBox(width: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, size: 18)
        ],
      ),
    );
  }
}