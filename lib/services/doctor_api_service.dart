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
  static const List<String> specialties = [
    'All',
    'Cardiology',
    'Dermatology',
    'Neurology',
    'Pediatrics',
    'Orthopedics',
    'General Medicine',
  ];

  Future<List<Doctor>> fetchDoctors() async {
    final response = await http
        .get(Uri.parse('https://dummyjson.com/users?limit=20'))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Failed to load doctors.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final users = data['users'] as List<dynamic>;

    return users.asMap().entries.map((entry) {
      final user = entry.value as Map<String, dynamic>;
      final firstName = user['firstName']?.toString() ?? '';
      final lastName = user['lastName']?.toString() ?? '';
      final name = '$firstName $lastName'.trim();

      return Doctor(
        id: user['id'] as int? ?? entry.key + 1,
        name: name.isEmpty ? 'Doctor' : name,
        specialty: specialties[1 + (entry.key % (specialties.length - 1))],
        image: user['image']?.toString() ?? '',
        age: user['age'] as int? ?? 0,
      );
    }).toList();
  }
}
