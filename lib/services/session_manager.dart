import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final String residentId;
  final String name;
  final String email;
  final String address;
  final String contact;
  final List<String> medicalConditions;
  final String? profilePictureUrl;
  final String? avatar;

  UserModel({
    required this.residentId,
    required this.name,
    required this.email,
    required this.address,
    required this.contact,
    this.medicalConditions = const [],
    this.profilePictureUrl,
    this.avatar,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<String> conditions = [];
    if (json['medical_conditions'] != null && json['medical_conditions'].isNotEmpty) {
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
      profilePictureUrl: json['profile_picture_url'],
      avatar: json['avatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resident_id': residentId,
      'name': name,
      'email': email,
      'address': address,
      'contact': contact,
      'medical_conditions': jsonEncode(medicalConditions),
      'profile_picture_url': profilePictureUrl,
      'avatar': avatar,
    };
  }
}

class SessionManager {
  static const String _userKey = 'currentUser';

  static Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = jsonEncode(user.toJson()); 
    await prefs.setString(_userKey, userJson);
  }

  static Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return UserModel.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  static Future<bool> isLoggedIn() async {
    final user = await getUser();
    return user != null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}