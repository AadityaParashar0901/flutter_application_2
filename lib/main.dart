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

  void _renameList(BuildContext context, String listId, String currentName) {
    final listNameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename List'),
        content: TextField(
          controller: listNameController,
          decoration: InputDecoration(hintText: 'New List Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = listNameController.text.trim();
              if (newName.isNotEmpty) {
                _firestore
                    .collection('expense_lists')
                    .doc(listId)
                    .update({'name': newName});
                Navigator.of(context).pop();
              }
            },
            child: Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _deleteList(String listId) {
    _firestore.collection('expense_lists').doc(listId).delete();
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

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 3,
                child: InkWell(
                  onTap: () => _openList(listId, listName),
                  onLongPress: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Icon(Icons.edit, color: Colors.blue),
                            title: Text('Rename'),
                            onTap: () {
                              Navigator.pop(context);
                              _renameList(context, listId, listName);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text('Delete'),
                            onTap: () {
                              Navigator.pop(context);
                              _deleteList(listId);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade400, Colors.teal.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.all(15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          listName,
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        Icon(Icons.arrow_forward_ios, color: Colors.white),
                      ],
                    ),
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
        .collection('expenses')
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

  void _addOrEditExpense(BuildContext context, {String? docId, Map<String, dynamic>? initialData}) {
    final descriptionController = TextEditingController(text: initialData?['description'] ?? '');
    final amountController = TextEditingController(
        text: initialData != null ? initialData['amount'].toString() : '');
    DateTime selectedDate = initialData != null
        ? (initialData['date'] as Timestamp).toDate()
        : DateTime.now();

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
                final description = descriptionController.text.trim();
                final amount = double.tryParse(amountController.text.trim()) ?? 0.0;

                if (description.isNotEmpty && amount > 0) {
                  if (docId == null) {
                    // Add new expense
                    _firestore.collection('expenses').add({
                      'description': description,
                      'amount': amount,
                      'date': selectedDate,
                      'hidden': false,
                      'listId': widget.listId,
                    });
                  } else {
                    // Update existing expense
                    _firestore.collection('expenses').doc(docId).update({
                      'description': description,
                      'amount': amount,
                      'date': selectedDate,
                    });
                  }
                  Navigator.of(context).pop();
                  calculateTotalSpent();
                }
              },
              child: Text(docId == null ? 'Add' : 'Update'),
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
            onPressed: () => _addOrEditExpense(context),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _firestore
            .collection('expenses')
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
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          _addOrEditExpense(
                            context,
                            docId: docId,
                            initialData: expense.data() as Map<String, dynamic>,
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          isHidden ? Icons.visibility_off : Icons.visibility,
                          color: isHidden ? Colors.grey : Colors.teal,
                        ),
                        onPressed: () => _firestore
                            .collection('expenses')
                            .doc(docId)
                            .update({'hidden': !isHidden}),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _firestore.collection('expenses').doc(docId).delete(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(10),
        color: Colors.teal.shade600,
        child: Text(
          'Total Spent: \$${totalSpent.toStringAsFixed(2)}',
          style: TextStyle(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}