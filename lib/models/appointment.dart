class Appointment {
  final int id;
  final String doctorName;
  final String specialty;
  final String patientName;
  final String reason;
  final DateTime appointmentDate;
  final String accountEmail;
  final String status;

  Appointment({
    required this.id,
    required this.doctorName,
    required this.specialty,
    required this.patientName,
    required this.reason,
    required this.appointmentDate,
    required this.accountEmail,
    this.status = 'Scheduled',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctorName': doctorName,
      'specialty': specialty,
      'patientName': patientName,
      'reason': reason,
      'appointmentDate': appointmentDate.toIso8601String(),
      'accountEmail': accountEmail,
      'status': status,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse(map['id']?.toString() ?? '') ?? 0,
      doctorName: map['doctorName']?.toString() ?? '',
      specialty: map['specialty']?.toString() ?? '',
      patientName: map['patientName']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      appointmentDate: DateTime.tryParse(
            map['appointmentDate']?.toString() ?? '',
          ) ??
          DateTime.now(),
      accountEmail: map['accountEmail']?.toString() ?? '',
      status: map['status']?.toString() ?? 'Scheduled',
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment.fromMap(json);
  }
}
