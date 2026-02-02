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

    var rawConditions = json['medical_conditions'];

    if (rawConditions != null) {
      if (rawConditions is List) {
        conditions = List<String>.from(rawConditions.map((e) => e.toString()));
      } else if (rawConditions is String && rawConditions.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawConditions);
          if (decoded is List) {
            conditions = List<String>.from(decoded.map((e) => e.toString()));
          }
        } catch (e) {
          print('Error parsing medical_conditions: $e');
        }
      }
    }

    return UserModel(
      residentId: json['resident_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      contact: json['contact']?.toString() ?? '',
      medicalConditions: conditions,
      profilePictureUrl: json['profile_picture_url']?.toString(),
      avatar: json['avatar']?.toString(),
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
      try {
        return UserModel.fromJson(jsonDecode(userJson));
      } catch (e) {
        await logout();
        return null;
      }
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