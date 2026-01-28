import 'package:flutter/material.dart';

class EmergencyContactsScreen extends StatelessWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> mockContacts = [
      {'name': 'Maria Santos', 'phone': '+63 912 345 6789'},
      {'name': 'Danny Santos', 'phone': '+63 980 890 1234'},
      {'name': 'Rosa Martinez', 'phone': '+63 970 789 0123'},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Image.asset('images/search-icon.png', width: 24, color: Colors.black54),
            onPressed: () {},
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: mockContacts.length,
        itemBuilder: (context, index) {
          final contact = mockContacts[index];
          return ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundImage: const AssetImage('images/profile-picture.png'),
              backgroundColor: Colors.grey[200],
            ),
            title: Text(
              contact['name']!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              contact['phone']!,
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.black54),
              onPressed: () {},
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF20C997),
        elevation: 4,
        child: Image.asset('images/useradd-icon.png', width: 24, color: Colors.white),
      ),
    );
  }
}