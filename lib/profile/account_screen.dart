import 'package:flutter/material.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.orange),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Account'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16.0),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Lorem Ipsum',
              style: TextStyle(fontSize: 16),
            ),
            Divider(height: 32),
            Text(
              'Contact',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              '1234567890',
              style: TextStyle(fontSize: 16),
            ),
            Divider(height: 32),
            Text(
              'Email',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'lorem@mail.com',
              style: TextStyle(fontSize: 16),
            ),
            Divider(height: 32),
            Text(
              'DOB',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              '13-05-25',
              style: TextStyle(fontSize: 16),
            ),
            Divider(height: 32),
            Text(
              'Address',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Lorem Ipsum Lorem Ipsum Lorem Ipsum',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}