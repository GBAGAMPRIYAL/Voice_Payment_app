import 'package:flutter/material.dart';
import 'transactions_page.dart';

class DashboardPage extends StatelessWidget {
  final String userName;

  const DashboardPage({super.key, required this.userName});

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
                    builder: (context) => const TransactionsPage(),
                  ),
                );
              },
              child: buildBar(Icons.receipt_long, "Transactions"),
            ),
            const SizedBox(height: 20),

            buildBar(Icons.account_balance_wallet, "Balance"),
            const SizedBox(height: 20),

            buildBar(Icons.contacts, "Contact"),
            const SizedBox(height: 20),

            buildBar(Icons.support_agent, "Help & Support"),
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