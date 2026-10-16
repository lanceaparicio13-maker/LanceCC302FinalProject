import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/appointment.dart';
import '../services/doctor_api_service.dart';
import '../services/local_storage_service.dart';

class HomeScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocalStorageService _storage = LocalStorageService.instance;
  final DoctorApiService _doctorService = DoctorApiService();
  final TextEditingController _searchController = TextEditingController();

  static const Color _primaryColor = Color(0xFF176B87);
  static const Color _accentColor = Color(0xFF27B8A5);
  static const Color _backgroundColor = Color(0xFFF4F8FC);
  static const Color _darkColor = Color(0xFF17324D);
  static const Color _mutedColor = Color(0xFF75869A);

  int _selectedIndex = 0;
  bool _loadingDoctors = true;
  bool _loadingAppointments = true;
  String? _doctorError;
  String _selectedSpecialty = 'All';
  String? _profilePhoto;

  List<Doctor> _doctors = [];
  List<Appointment> _appointments = [];

  List<String> get _specialties => DoctorApiService.specialties;

  String get _photoKey => 'profile_photo_${widget.user.email.toLowerCase()}';

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    _loadAppointments();
    _loadProfilePhoto();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    if (mounted) {
      setState(() {
        _loadingDoctors = true;
        _doctorError = null;
      });
    }

    try {
      final doctors = await _doctorService.fetchDoctors();

      if (!mounted) return;

      setState(() {
        _doctors = doctors;
        _loadingDoctors = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _doctorError = 'Unable to load doctors. Check your connection.';
        _loadingDoctors = false;
      });
    }
  }

  Future<void> _loadAppointments() async {
    if (mounted) {
      setState(() => _loadingAppointments = true);
    }

    try {
      final appointments = await _storage.getAppointments(widget.user.email);

      if (!mounted) return;

      setState(() {
        _appointments = appointments
          ..sort(
            (a, b) => a.appointmentDate.compareTo(b.appointmentDate),
          );
        _loadingAppointments = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _loadingAppointments = false);
      _message('Unable to load appointments.');
    }
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final photo = prefs.getString(_photoKey);

      if (!mounted) return;
      setState(() => _profilePhoto = photo);
    } catch (_) {
      // Keep the default profile image if loading fails.
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 700,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final encoded = base64Encode(bytes);
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_photoKey, encoded);

      if (!mounted) return;

      setState(() => _profilePhoto = encoded);
      _message('Profile photo updated.');
    } catch (_) {
      _message('Unable to select the profile photo.');
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  List<Doctor> get _filteredDoctors {
    final query = _searchController.text.trim().toLowerCase();

    return _doctors.where((doctor) {
      final matchesSearch = doctor.name.toLowerCase().contains(query) ||
          doctor.specialty.toLowerCase().contains(query);

      final matchesSpecialty =
          _selectedSpecialty == 'All' || doctor.specialty == _selectedSpecialty;

      return matchesSearch && matchesSpecialty;
    }).toList();
  }

  List<Appointment> get _upcomingAppointments {
    final now = DateTime.now();

    return _appointments.where((appointment) {
      return appointment.status == 'Scheduled' &&
          appointment.appointmentDate.isAfter(now);
    }).toList();
  }

  List<Appointment> get _pastAppointments {
    final now = DateTime.now();

    return _appointments.where((appointment) {
      return appointment.status != 'Scheduled' ||
          !appointment.appointmentDate.isAfter(now);
    }).toList();
  }

  String get _pageTitle {
    switch (_selectedIndex) {
      case 1:
        return 'Find Doctors';
      case 2:
        return 'My Appointments';
      case 3:
        return 'Notifications';
      case 4:
        return 'My Profile';
      default:
        return 'MedBook';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _homePage(),
      _doctorsPage(),
      _appointmentsPage(),
      _notificationsPage(),
      _profilePage(),
    ];

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          _pageTitle,
          style: const TextStyle(
            color: _darkColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor,
        elevation: 0,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);

          if (index == 2 || index == 3) {
            _loadAppointments();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services),
            label: 'Doctors',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _homePage() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadDoctors(),
          _loadAppointments(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryColor, _accentColor],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your health matters.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Welcome, ${widget.user.name}. Find a doctor and manage your appointments in one place.',
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _primaryColor,
                  ),
                  onPressed: () {
                    setState(() => _selectedIndex = 1);
                  },
                  child: const Text('Find a Doctor'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Doctors',
                  _loadingDoctors ? '...' : '${_doctors.length}',
                  Icons.medical_services_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Upcoming',
                  '${_upcomingAppointments.length}',
                  Icons.calendar_month_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionHeader(
            'Recommended Doctors',
            'See all',
            () => setState(() => _selectedIndex = 1),
          ),
          const SizedBox(height: 10),
          if (_loadingDoctors)
            const Center(child: CircularProgressIndicator())
          else if (_doctorError != null)
            _errorState(_doctorError!, _loadDoctors)
          else if (_doctors.isEmpty)
            _emptyState(Icons.person_search, 'No doctors available.')
          else
            ..._doctors.take(3).map(_doctorCard),
          const SizedBox(height: 20),
          _sectionHeader(
            'Upcoming Appointments',
            'View all',
            () => setState(() => _selectedIndex = 2),
          ),
          const SizedBox(height: 10),
          if (_loadingAppointments)
            const Center(child: CircularProgressIndicator())
          else if (_upcomingAppointments.isEmpty)
            _emptyState(
              Icons.event_available,
              'You have no upcoming appointments.',
            )
          else
            ..._upcomingAppointments.take(3).map(_appointmentCard),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Card(
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _primaryColor, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: _darkColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: const TextStyle(color: _mutedColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    String title,
    String action,
    VoidCallback onTap,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _darkColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: Text(action),
        ),
      ],
    );
  }

  Widget _doctorsPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search doctors or specialties',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.clear),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _specialties.map((specialty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(specialty),
                  selected: _selectedSpecialty == specialty,
                  onSelected: (_) {
                    setState(() => _selectedSpecialty = specialty);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: _loadingDoctors
              ? const Center(child: CircularProgressIndicator())
              : _doctorError != null
                  ? _errorState(_doctorError!, _loadDoctors)
                  : _filteredDoctors.isEmpty
                      ? _emptyState(
                          Icons.search_off,
                          'No matching doctors found.',
                        )
                      : RefreshIndicator(
                          onRefresh: _loadDoctors,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredDoctors.length,
                            itemBuilder: (context, index) {
                              return _doctorCard(_filteredDoctors[index]);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _doctorCard(Doctor doctor) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _DoctorAvatar(doctor: doctor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.name,
                    style: const TextStyle(
                      color: _darkColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doctor.specialty,
                    style: const TextStyle(color: _mutedColor),
                  ),
                  Text(
                    'Age ${doctor.age}',
                    style: const TextStyle(
                      color: _mutedColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: () => _bookAppointment(doctor),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryColor,
              ),
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appointmentsPage() {
    return DefaultTabController(
      key: const ValueKey('appointment-tabs'),
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: _primaryColor,
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
          Expanded(
            child: _loadingAppointments
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      _appointmentList(_upcomingAppointments),
                      _appointmentList(_pastAppointments),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentList(List<Appointment> appointments) {
    if (appointments.isEmpty) {
      return _emptyState(
        Icons.calendar_month,
        'No appointments to display.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          return _appointmentCard(appointments[index]);
        },
      ),
    );
  }

  Widget _appointmentCard(Appointment appointment) {
    final date = appointment.appointmentDate;
    final scheduled =
        appointment.status == 'Scheduled' && date.isAfter(DateTime.now());

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFDCEEF4),
                  child: Icon(
                    Icons.medical_services,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.doctorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _darkColor,
                        ),
                      ),
                      Text(
                        appointment.specialty,
                        style: const TextStyle(color: _mutedColor),
                      ),
                    ],
                  ),
                ),
                _statusChip(appointment.status),
              ],
            ),
            const Divider(height: 24),
            _detailRow(
              Icons.person_outline,
              'Patient: ${appointment.patientName}',
            ),
            const SizedBox(height: 8),
            _detailRow(
              Icons.calendar_month_outlined,
              DateFormat('MMM d, yyyy • hh:mm a').format(date),
            ),
            const SizedBox(height: 8),
            _detailRow(Icons.notes_outlined, appointment.reason),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (scheduled)
                  OutlinedButton.icon(
                    onPressed: () => _rescheduleAppointment(appointment),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: const Text('Reschedule'),
                  ),
                TextButton.icon(
                  onPressed: () => _deleteAppointment(appointment),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'Scheduled' ? _accentColor : _mutedColor;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _mutedColor),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _notificationsPage() {
    final upcoming = _upcomingAppointments;

    if (_loadingAppointments) {
      return const Center(child: CircularProgressIndicator());
    }

    if (upcoming.isEmpty) {
      return _emptyState(
        Icons.notifications_none,
        'You have no upcoming appointment reminders.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Appointment reminders',
          style: TextStyle(
            color: _darkColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Review your upcoming appointments below.',
          style: TextStyle(color: _mutedColor),
        ),
        const SizedBox(height: 16),
        ...upcoming.map((appointment) {
          final date = appointment.appointmentDate;

          return Card(
            color: Colors.white,
            elevation: 0,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDCEEF4),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: _primaryColor,
                ),
              ),
              title: Text(appointment.doctorName),
              subtitle: Text(
                '${DateFormat('MMM d, yyyy • hh:mm a').format(date)}\n'
                '${appointment.specialty}',
              ),
              isThreeLine: true,
            ),
          );
        }),
      ],
    );
  }

  Widget _profilePage() {
    ImageProvider? profileImage;

    if (_profilePhoto != null) {
      try {
        profileImage = MemoryImage(base64Decode(_profilePhoto!));
      } catch (_) {
        profileImage = null;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: GestureDetector(
            onTap: _pickProfilePhoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: const Color(0xFFDCEEF4),
                  backgroundImage: profileImage,
                  child: profileImage == null
                      ? const Icon(
                          Icons.person,
                          size: 52,
                          color: _primaryColor,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: _primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.user.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _darkColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          widget.user.email,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _mutedColor),
        ),
        const SizedBox(height: 24),
        Card(
          color: Colors.white,
          elevation: 0,
          child: ListTile(
            leading: const Icon(
              Icons.calendar_month,
              color: _primaryColor,
            ),
            title: const Text('Total appointments'),
            trailing: Text('${_appointments.length}'),
          ),
        ),
        Card(
          color: Colors.white,
          elevation: 0,
          child: const ListTile(
            leading: Icon(Icons.info_outline, color: _primaryColor),
            title: Text('About MedBook'),
            subtitle: Text(
              'A demonstration application for doctor search and '
              'appointment management.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _pickProfilePhoto,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Change Profile Photo'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Log Out'),
          style: FilledButton.styleFrom(
            backgroundColor: _primaryColor,
            padding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Doctor profiles are sample data. This application does not '
          'provide medical advice or confirm real clinic appointments.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _mutedColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: _mutedColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _mutedColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String message, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 42,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: retry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bookAppointment(Doctor doctor) async {
    final result = await showDialog<Appointment>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BookingDialog(
        doctor: doctor,
        accountEmail: widget.user.email,
      ),
    );

    if (result == null || !mounted) return;

    try {
      await _storage.addAppointment(result);
      await _loadAppointments();

      if (!mounted) return;

      setState(() => _selectedIndex = 2);
      _message('Appointment booked successfully.');
    } catch (_) {
      _message('Unable to save the appointment. Please try again.');
    }
  }

  Future<void> _rescheduleAppointment(
    Appointment appointment,
  ) async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => _RescheduleDialog(
        appointment: appointment,
      ),
    );

    if (result == null || !mounted) return;

    try {
      final updated = Appointment(
        id: appointment.id,
        doctorName: appointment.doctorName,
        specialty: appointment.specialty,
        patientName: appointment.patientName,
        reason: appointment.reason,
        appointmentDate: result,
        accountEmail: appointment.accountEmail,
        status: 'Scheduled',
      );

      await _storage.updateAppointment(updated);
      await _loadAppointments();

      if (!mounted) return;
      _message('Appointment rescheduled successfully.');
    } catch (_) {
      _message('Unable to reschedule the appointment.');
    }
  }

  Future<void> _deleteAppointment(
    Appointment appointment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Appointment?'),
        content: Text(
          'Delete the appointment with ${appointment.doctorName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _storage.deleteAppointment(
        appointment.id,
        widget.user.email,
      );
      await _loadAppointments();

      if (!mounted) return;
      _message('Appointment deleted.');
    } catch (_) {
      _message('Unable to delete the appointment.');
    }
  }
}

class _BookingDialog extends StatefulWidget {
  final Doctor doctor;
  final String accountEmail;

  const _BookingDialog({
    required this.doctor,
    required this.accountEmail,
  });

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _patientController = TextEditingController();
  final _reasonController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(
    const Duration(days: 1),
  );
  String _selectedTime = '09:00 AM';

  static const List<String> _times = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
  ];

  @override
  void dispose() {
    _patientController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final initialDate =
        _selectedDate.isBefore(firstDate) ? firstDate : _selectedDate;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (!mounted || date == null) return;

    setState(() => _selectedDate = date);
  }

  DateTime _combineDateAndTime() {
    final parts = _selectedTime.split(' ');
    final clock = parts[0].split(':');
    int hour = int.parse(clock[0]);
    final minute = int.parse(clock[1]);

    if (parts[1] == 'PM' && hour != 12) hour += 12;
    if (parts[1] == 'AM' && hour == 12) hour = 0;

    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
      minute,
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final date = _combineDateAndTime();

    if (!date.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a future appointment time.'),
        ),
      );
      return;
    }

    final appointment = Appointment(
      id: DateTime.now().microsecondsSinceEpoch,
      doctorName: widget.doctor.name,
      specialty: widget.doctor.specialty,
      patientName: _patientController.text.trim(),
      reason: _reasonController.text.trim(),
      appointmentDate: date,
      accountEmail: widget.accountEmail,
      status: 'Scheduled',
    );

    Navigator.of(context).pop(appointment);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Book Appointment'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.doctor.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(widget.doctor.specialty),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _patientController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Patient name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter the patient name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason for visit',
                    hintText: 'General consultation',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a reason for the visit.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Appointment date',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: _chooseDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    DateFormat('MMM d, yyyy').format(_selectedDate),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTime,
                  decoration: const InputDecoration(
                    labelText: 'Appointment time',
                    border: OutlineInputBorder(),
                  ),
                  items: _times.map((time) {
                    return DropdownMenuItem<String>(
                      value: time,
                      child: Text(time),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedTime = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Confirm Booking'),
        ),
      ],
    );
  }
}

class _RescheduleDialog extends StatefulWidget {
  final Appointment appointment;

  const _RescheduleDialog({
    required this.appointment,
  });

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  static const List<String> _times = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '01:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
  ];

  late DateTime _selectedDate;
  late String _selectedTime;

  @override
  void initState() {
    super.initState();

    final current = widget.appointment.appointmentDate;
    final now = DateTime.now();

    _selectedDate = current.isBefore(now)
        ? DateTime(now.year, now.month, now.day).add(
            const Duration(days: 1),
          )
        : current;

    _selectedTime = DateFormat('hh:mm a').format(current);

    if (!_times.contains(_selectedTime)) {
      _selectedTime = _times.first;
    }
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final initialDate =
        _selectedDate.isBefore(firstDate) ? firstDate : _selectedDate;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (!mounted || date == null) return;

    setState(() => _selectedDate = date);
  }

  void _submit() {
    final parts = _selectedTime.split(' ');
    final clock = parts[0].split(':');
    int hour = int.parse(clock[0]);
    final minute = int.parse(clock[1]);

    if (parts[1] == 'PM' && hour != 12) hour += 12;
    if (parts[1] == 'AM' && hour == 12) hour = 0;

    final date = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
      minute,
    );

    if (!date.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a future appointment time.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(date);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reschedule Appointment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Appointment with ${widget.appointment.doctorName}',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _chooseDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(
              DateFormat('MMM d, yyyy').format(_selectedDate),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedTime,
            decoration: const InputDecoration(
              labelText: 'New time',
            ),
            items: _times.map((time) {
              return DropdownMenuItem<String>(
                value: time,
                child: Text(time),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedTime = value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
}

class _DoctorAvatar extends StatelessWidget {
  final Doctor doctor;

  const _DoctorAvatar({
    required this.doctor,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 30,
      backgroundColor: const Color(0xFFDCEEF4),
      child: ClipOval(
        child: SizedBox(
          width: 60,
          height: 60,
          child: doctor.image.isEmpty
              ? const Icon(
                  Icons.person,
                  color: _HomeScreenState._primaryColor,
                  size: 34,
                )
              : Image.network(
                  doctor.image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.person,
                      color: _HomeScreenState._primaryColor,
                      size: 34,
                    );
                  },
                ),
        ),
      ),
    );
  }
}
