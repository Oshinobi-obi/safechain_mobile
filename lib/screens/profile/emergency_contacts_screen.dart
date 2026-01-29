import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:safechain/services/session_manager.dart';
import 'package:safechain/widgets/phone_number_formatter.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<dynamic> _allContacts = [];
  List<dynamic> _filteredContacts = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchContacts() async {
    final user = await SessionManager.getUser();
    if (user == null) return;

    setState(() => _isLoading = true);
    final uri = Uri.parse('https://safechain.site/api/mobile/get_contacts.php?resident_id=${user.residentId}');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['status'] == 'success') {
          setState(() {
            _allContacts = body['contacts'];
            _filteredContacts = _allContacts;
          });
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _allContacts.where((contact) {
        return contact['name'].toLowerCase().contains(query) ||
               contact['contact_number'].contains(query);
      }).toList();
    });
  }

  void _showAddContactSheet({Map<String, dynamic>? contact}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => _AddContactSheet(contact: contact, onSave: _fetchContacts),
    );
  }

  void _showContactOptions(BuildContext context, Map<String, dynamic> contact) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(const Offset(-120, 0), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(const Offset(0, 0)), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        PopupMenuItem(
          onTap: () => Future.delayed(Duration.zero, () => _showAddContactSheet(contact: contact)),
          child: Row(children: [Image.asset('images/edit-contact.png', width: 20), const SizedBox(width: 12), const Text('Edit')]),
        ),
        PopupMenuItem(
          onTap: () => _deleteContact(contact['contact_id']),
          child: Row(children: [Image.asset('images/delete-contact.png', width: 20, color: Colors.red), const SizedBox(width: 12), const Text('Delete', style: TextStyle(color: Colors.red))]),
        ),
      ],
    );
  }

  Future<void> _deleteContact(int contactId) async {
    final uri = Uri.parse('https://safechain.site/api/mobile/delete_contact.php');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'contact_id': contactId}),
      );
      if (response.statusCode == 200) {
        _fetchContacts();
      }
    } catch (e) {
      // Handle error
    }
  }

  String getInitials(String name) {
    List<String> names = name.split(" ");
    String initials = "";
    int numWords = names.length > 2 ? 2 : names.length;
    for (var i = 0; i < numWords; i++) {
      if (names[i].isNotEmpty) {
        initials += names[i][0];
      }
    }
    return initials.toUpperCase();
  }

  Color _getColorForContact(String name) {
    return Colors.primaries[name.hashCode % Colors.primaries.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: _isSearching ? const SizedBox.shrink() : IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching 
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search contacts...',
                  border: InputBorder.none,
                ),
              )
            : const Text(
                'Emergency Contacts',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
        centerTitle: true,
        actions: [
          _isSearching
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black54),
                onPressed: () => setState(() {
                  _isSearching = false;
                  _searchController.clear();
                }),
              )
            : IconButton(
                icon: Image.asset('images/search-icon.png', width: 24, color: Colors.black54),
                onPressed: () => setState(() => _isSearching = true),
              ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF20C997)))
          : _filteredContacts.isEmpty
              ? Center(
                  child: Text(
                    _allContacts.isEmpty ? 'No emergency contacts added yet.' : 'No contacts found.',
                    style: const TextStyle(color: Colors.grey, fontSize: 16)
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _filteredContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _filteredContacts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: _getColorForContact(contact['name']),
                        child: Text(
                          getInitials(contact['name']),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        contact['name']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        contact['contact_number']!,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: Builder(
                        builder: (context) => IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.black54),
                          onPressed: () => _showContactOptions(context, contact),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddContactSheet(),
        backgroundColor: const Color(0xFF20C997),
        elevation: 4,
        child: Image.asset('images/useradd-icon.png', width: 24, color: Colors.white),
      ),
    );
  }
}

class _AddContactSheet extends StatefulWidget {
  final Map<String, dynamic>? contact;
  final VoidCallback onSave;

  const _AddContactSheet({this.contact, required this.onSave});

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _contactController;
  String? _selectedRelationship;
  bool _isLoading = false;

  bool get isUpdating => widget.contact != null;

  final List<String> _relationships = [
    'Parent', 'Partner / Spouse', 'Sibling', 'Friend', 'Other', 'None / Prefer not to say'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact?['name']);
    _contactController = TextEditingController(text: widget.contact?['contact_number']);
    _selectedRelationship = widget.contact?['relationship'];
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = await SessionManager.getUser();
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final url = isUpdating 
      ? 'https://safechain.site/api/mobile/update_contact.php'
      : 'https://safechain.site/api/mobile/add_contact.php';

    final body = {
      'resident_id': user.residentId,
      'name': _nameController.text,
      'contact_number': _contactController.text,
      'relationship': _selectedRelationship,
    };
    
    if(isUpdating) {
      body['contact_id'] = widget.contact!['contact_id'];
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );
      
      if(response.statusCode == 200 || response.statusCode == 201) {
        widget.onSave();
        Navigator.pop(context);
      }

    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  isUpdating ? 'Edit Emergency Contact' : 'Add Emergency Contact',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
                decoration: InputDecoration(
                  hintText: 'Enter Full Name',
                  fillColor: const Color(0xFFF1F5F9),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Contact Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [Image.asset('images/philippine_flag.png', width: 24), const SizedBox(width: 8), const Text('+63', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))],
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [PhoneNumberFormatter()],
                      validator: (value) => value!.isEmpty ? 'Please enter a contact number' : null,
                      decoration: const InputDecoration(
                        fillColor: Color(0xFFF1F5F9),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Relationship (optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedRelationship,
                items: _relationships.map((relationship) => DropdownMenuItem(value: relationship, child: Text(relationship))).toList(),
                onChanged: (value) => setState(() => _selectedRelationship = value),
                decoration: InputDecoration(
                  hintText: 'Select relationship',
                  fillColor: const Color(0xFFF1F5F9),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveContact,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20C997),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isUpdating ? 'Save Changes' : 'Add Contact', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}