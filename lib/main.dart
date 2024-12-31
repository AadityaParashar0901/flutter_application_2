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
      home: ListSelector(),
    );
  }
}

class ListSelector extends StatefulWidget {
  @override
  _ListSelectorState createState() => _ListSelectorState();
}

class _ListSelectorState extends State<ListSelector> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _addList(BuildContext context) {
    final listNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create New List'),
        content: TextField(
          controller: listNameController,
          decoration: InputDecoration(hintText: 'List Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final listName = listNameController.text.trim();
              if (listName.isNotEmpty) {
                _firestore.collection('expense_lists').add({'name': listName});
                Navigator.of(context).pop();
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  void _openList(String listId, String listName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(listId: listId, listName: listName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select List'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _addList(context),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _firestore.collection('expense_lists').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No lists available.'));
          }

          final lists = snapshot.data!.docs;
          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              final listId = list.id;
              final listName = list['name'];

              return ListTile(
                title: Text(listName),
                onTap: () => _openList(listId, listName),
              );
            },
          );
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final String listId;
  final String listName;

  HomePage({required this.listId, required this.listName});

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
        .collection('expenses2')
        .where('listId', isEqualTo: widget.listId)
        .where('hidden', isEqualTo: false)
        .get();
    for (var expense in expenses.docs) {
      total += expense['amount'];
    }
    setState(() {
      totalSpent = total;
    });
  }

  void _generateReport() async {
    final expenses = await _firestore
        .collection('expenses2')
        .where('listId', isEqualTo: widget.listId)
        .get();

    String report = 'Expense Report for ${widget.listName}\n\n';
    double total = 0.0;
    for (var expense in expenses.docs) {
      final description = expense['description'];
      final amount = expense['amount'];
      final date = (expense['date'] as Timestamp).toDate();
      final isHidden = expense['hidden'];

      if (!isHidden) {
        total += amount;
      }

      report +=
          '${DateFormat.yMMMd().format(date)} - $description: \$${amount.toStringAsFixed(2)} ${isHidden ? "(Hidden)" : ""}\n';
    }

    report += '\nTotal: \$${total.toStringAsFixed(2)}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Expense Report'),
        content: SingleChildScrollView(
          child: Text(report),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showExpenseDialog(BuildContext context,
      {String? docId, String? description, double? amount, DateTime? date}) {
    final descriptionController = TextEditingController(text: description ?? '');
    final amountController = TextEditingController(text: amount != null ? amount.toString() : '');
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
                  _firestore.collection('expenses2').doc(docId).set({
                    'description': desc,
                    'amount': amt,
                    'date': selectedDate,
                    'hidden': false,
                    'listId': widget.listId,
                  }, SetOptions(merge: true));
                  Navigator.of(context).pop();
                  calculateTotalSpent();
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
        title: Text(widget.listName),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showExpenseDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.insert_chart),
            onPressed: _generateReport,
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _firestore
            .collection('expenses2')
            .where('listId', isEqualTo: widget.listId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No expenses added yet!'));
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
                      decoration: isHidden ? TextDecoration.lineThrough : null,
                      color: isHidden ? Colors.grey : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                      '${DateFormat.yMMMd().format(date)} - \$${amount.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isHidden ? Icons.visibility_off : Icons.visibility,
                          color: isHidden ? Colors.grey : Colors.teal,
                        ),
                        onPressed: () => _firestore
                            .collection('expenses2')
                            .doc(docId)
                            .update({'hidden': !isHidden}),
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
                        onPressed: () =>
                            _firestore.collection('expenses2').doc(docId).delete(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}