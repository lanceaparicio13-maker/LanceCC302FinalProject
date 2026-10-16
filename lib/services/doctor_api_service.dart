import 'dart:convert';

import 'package:http/http.dart' as http;

class Doctor {
  final int id;
  final String name;
  final String specialty;
  final String image;
  final int age;

  const Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.image,
    required this.age,
  });
}

class DoctorApiService {
  static const String apiUrl = 'https://dummyjson.com/users?limit=20';

  static const List<String> specialties = [
    'General Medicine',
    'Cardiology',
    'Dermatology',
    'Pediatrics',
    'Neurology',
    'Orthopedics',
  ];

  Future<List<Doctor>> fetchDoctors() async {
    final response = await http
        .get(Uri.parse(apiUrl))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Unable to load doctor profiles.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final users = data['users'] as List<dynamic>;

    return users.asMap().entries.map((entry) {
      final index = entry.key;
      final user = entry.value as Map<String, dynamic>;

      return Doctor(
        id: user['id'] as int,
        name: 'Dr. ${user['firstName']} ${user['lastName']}',
        specialty: specialties[index % specialties.length],
        image: user['image'] as String? ?? '',
        age: user['age'] as int? ?? 0,
      );
    }).toList();
  }
}
