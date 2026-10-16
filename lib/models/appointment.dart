class Appointment {
  final int id;
  final String doctorName;
  final String specialty;
  final String patientName;
  final String reason;
  final String appointmentDate;
  final String status;
  final String accountEmail;

  const Appointment({
    required this.id,
    required this.doctorName,
    required this.specialty,
    required this.patientName,
    required this.reason,
    required this.appointmentDate,
    required this.accountEmail,
    this.status = 'Scheduled',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'doctorName': doctorName,
        'specialty': specialty,
        'patientName': patientName,
        'reason': reason,
        'appointmentDate': appointmentDate,
        'status': status,
        'accountEmail': accountEmail,
      };

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: (map['id'] as num).toInt(),
      doctorName: map['doctorName'] as String? ?? '',
      specialty: map['specialty'] as String? ?? '',
      patientName: map['patientName'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      appointmentDate: map['appointmentDate'] as String? ?? '',
      accountEmail: map['accountEmail'] as String? ?? '',
      status: map['status'] as String? ?? 'Scheduled',
    );
  }
}
