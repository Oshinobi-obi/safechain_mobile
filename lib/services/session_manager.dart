import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// A simple data class for the logged-in user
class UserModel {
  final String residentId;
  final String name;
  final String email;
  final String address;
  final String contact;
  final List<String> medicalConditions;

  UserModel({
    required this.residentId,
    required this.name,
    required this.email,
    required this.address,
    required this.contact,
    this.medicalConditions = const [],
  });

  // Factory constructor to create a UserModel from a map (like the one from our API)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<String> conditions = [];
    if (json['medical_conditions'] != null && json['medical_conditions'].isNotEmpty) {
      // The data from the DB is a JSON string, so we need to decode it first
      final decodedConditions = jsonDecode(json['medical_conditions']);
      if (decodedConditions is List) {
        conditions = List<String>.from(decodedConditions);
      }
    }

    return UserModel(
      residentId: json['resident_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      address: json['address'] ?? '',
      contact: json['contact'] ?? '',
      medicalConditions: conditions,
    );
  }

  // Method to convert UserModel to a map for storing in SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'resident_id': residentId,
      'name': name,
      'email': email,
      'address': address,
      'contact': contact,
      // Storing medical conditions as a JSON string within the user JSON
      'medical_conditions': jsonEncode(medicalConditions),
    };
  }
}

class SessionManager {
  static const String _userKey = 'currentUser';

  // Save user data to SharedPreferences
  static Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    // toJson already handles encoding medical_conditions
    final userJson = jsonEncode(user.toJson()); 
    await prefs.setString(_userKey, userJson);
  }

  // Retrieve user data from SharedPreferences
  static Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      // The outer layer is the user model string, which needs to be decoded.
      return UserModel.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  // Check if a user is currently logged in
  static Future<bool> isLoggedIn() async {
    final user = await getUser();
    return user != null;
  }

  // Clear user data on logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
