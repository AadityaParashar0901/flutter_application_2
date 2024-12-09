// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, no_leading_underscores_for_local_identifiers, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  double totalSpent = 0.0;

  @override
  void initState() {
    super.initState();
    calculateTotalSpent();
  }

  Future<void> calculateTotalSpent() async {
    double total = 0.0;
    final expenses = await _firestore
        .collection('expenses')
        .where('hidden', isEqualTo: false)
        .get();
    for (var expense in expenses.docs) {
      total += expense['amount'];
    }
    setState(() {
      totalSpent = total;
    });
  }

  Future<void> _addOrEditExpense(
      {String? docId,
      String? description,
      double? amount,
      DateTime? date,
      bool hidden = false}) async {
    if (docId == null) {
      await _firestore.collection('expenses').add({
        'description': description,
        'amount': amount,
        'hidden': hidden,
        'date': date ?? DateTime.now(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore.collection('expenses').doc(docId).update({
        'description': description,
        'amount': amount,
        'date': date,
      });
    }
    calculateTotalSpent();
  }

  Future<void> _toggleHidden(String docId, bool currentStatus) async {
    await _firestore.collection('expenses').doc(docId).update({
      'hidden': !currentStatus,
    });
    calculateTotalSpent();
  }

  Future<void> _deleteExpense(String docId) async {
    await _firestore.collection('expenses').doc(docId).delete();
    calculateTotalSpent();
  }

  void _showExpenseDialog(BuildContext context,
      {String? docId, String? description, double? amount, DateTime? date}) {
    final descriptionController =
        TextEditingController(text: description ?? '');
    final amountController =
        TextEditingController(text: amount != null ? amount.toString() : '');
    DateTime selectedDate = date ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(docId == null ? 'Add Expense' : 'Edit Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(hintText: 'Description'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: amountController,
                decoration: InputDecoration(hintText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Date: ${DateFormat.yMMMd().format(selectedDate)}',
                    style: TextStyle(fontSize: 16),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.calendar_today),
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final desc = descriptionController.text;
                final amt = double.tryParse(amountController.text) ?? 0.0;

                if (desc.isNotEmpty && amt > 0) {
                  _addOrEditExpense(
                    docId: docId,
                    description: desc,
                    amount: amt,
                    date: selectedDate,
                  );
                  Navigator.of(context).pop();
                }
              },
              child: Text(docId == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expense Tracker'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showExpenseDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.teal,
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Total Spent: ${totalSpent.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _firestore
                  .collection('expenses')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No expenses added yet!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                final expenses = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    final description = expense['description'];
                    final amount = expense['amount'];
                    final date = (expense['date'] as Timestamp).toDate();
                    final isHidden = expense['hidden'];
                    final docId = expense.id;

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        title: Text(
                          description,
                          style: TextStyle(
                            decoration:
                                isHidden ? TextDecoration.lineThrough : null,
                            color: isHidden ? Colors.grey : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          '${DateFormat.yMMMd().format(date)} - ${amount.toStringAsFixed(2)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isHidden
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: isHidden ? Colors.grey : Colors.teal,
                              ),
                              onPressed: () => _toggleHidden(docId, isHidden),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showExpenseDialog(
                                context,
                                docId: docId,
                                description: description,
                                amount: amount,
                                date: date,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteExpense(docId),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
