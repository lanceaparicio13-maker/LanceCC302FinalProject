
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'auth_screen.dart';
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
  final _storage = LocalStorageService.instance;
  final _doctorService = DoctorApiService();
  final _searchController = TextEditingController();

  int _selectedIndex = 0;
  bool _loadingDoctors = true;
  String? _doctorError;
  String _specialty = 'All';
  List<Doctor> _doctors = [];
  List<Appointment> _appointments = [];

  List<String> get _specialties => [
        'All',
        ...DoctorApiService.specialties,
      ];

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    _loadAppointments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _loadingDoctors = true;
      _doctorError = null;
    });

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
        _doctorError = 'Could not load profiles. Check your connection.';
        _loadingDoctors = false;
      });
    }
  }

  Future<void> _loadAppointments() async {
    try {
      final appointments =
          await _storage.getAppointments(widget.user.email);

      if (!mounted) return;
      setState(() => _appointments = appointments);
    } catch (_) {
      _message('Could not load appointments.');
    }
  }

  List<Appointment> get _upcoming {
    final now = DateTime.now();

    return _appointments.where((appointment) {
      return appointment.status == 'Scheduled' &&
          DateTime.parse(appointment.appointmentDate).isAfter(now);
    }).toList()
      ..sort(
        (a, b) => a.appointmentDate.compareTo(b.appointmentDate),
      );
  }

  List<Appointment> get _past {
    final now = DateTime.now();

    return _appointments.where((appointment) {
      return appointment.status != 'Scheduled' ||
          !DateTime.parse(appointment.appointmentDate).isAfter(now);
    }).toList()
      ..sort(
        (a, b) => b.appointmentDate.compareTo(a.appointmentDate),
      );
  }

  List<Doctor> get _filteredDoctors {
    final query = _searchController.text.trim().toLowerCase();

    return _doctors.where((doctor) {
      final matchesText = doctor.name.toLowerCase().contains(query) ||
          doctor.specialty.toLowerCase().contains(query);

      return matchesText &&
          (_specialty == 'All' || doctor.specialty == _specialty);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  const [
                    'MedBook',
                    'Find Doctors',
                    'Appointments',
                    'My Profile',
                  ][_selectedIndex],
                  style: const TextStyle(
                    color: darkColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_selectedIndex == 0)
                  const Text(
                    'YOUR HEALTH, OUR PRIORITY',
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          if (_selectedIndex != 3)
            IconButton(
              tooltip: 'My profile',
              onPressed: () => setState(() => _selectedIndex = 3),
              icon: const Icon(Icons.account_circle_outlined),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: switch (_selectedIndex) {
  0 => _homePage(),
  1 => _doctorPage(),
  2 => _appointmentPage(),
  3 => _profilePage(),
  _ => _homePage(),
},
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 2 || index == 3) _loadAppointments();
        },
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDDF3F1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services_rounded),
            label: 'Doctors',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _homePage() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait<void>([
          _loadDoctors(),
          _loadAppointments(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _hero(),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Doctor profiles',
                  _loadingDoctors ? '...' : '${_doctors.length}',
                  Icons.medical_services_rounded,
                  primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Upcoming',
                  '${_upcoming.length}',
                  Icons.calendar_month_rounded,
                  accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _heading(
            'Find your doctor',
            'Explore available specialist profiles.',
            'See all',
            () => setState(() => _selectedIndex = 1),
          ),
          const SizedBox(height: 12),
          if (_loadingDoctors)
            const _Loading()
          else if (_doctorError != null)
            _errorView()
          else if (_doctors.isEmpty)
            const _Empty(
              icon: Icons.person_search_rounded,
              title: 'No profiles available',
              message: 'Please try again later.',
            )
          else
            ..._doctors.take(3).map(
                  (doctor) => _doctorCard(
                    doctor,
                    () => _book(doctor),
                  ),
                ),
          const SizedBox(height: 20),
          _heading(
            'Upcoming appointments',
            'Your next scheduled visits.',
            'View all',
            () => setState(() => _selectedIndex = 2),
          ),
          const SizedBox(height: 12),
          if (_upcoming.isEmpty)
            const _Empty(
              icon: Icons.event_available_rounded,
              title: 'No appointments yet',
              message: 'Book a doctor to see your appointments here.',
            )
          else
            ..._upcoming.take(3).map(_appointmentCard),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF176B87), Color(0xFF209DAB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: 0,
            child: Icon(
              Icons.health_and_safety_rounded,
              size: 105,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'CARE THAT MATTERS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Hello, ${widget.user.name.split(' ').first}!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your health, our priority.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Find doctors and manage your appointments with ease.',
                style: TextStyle(
                  color: Colors.white,
                  height: 1.5,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 19),
              FilledButton.icon(
                onPressed: () => setState(() => _selectedIndex = 1),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primaryColor,
                ),
                icon: const Icon(Icons.search_rounded),
                label: const Text(
                  'Find a doctor',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE7EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: darkColor,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            title,
            style: const TextStyle(color: mutedColor, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _heading(
    String title,
    String subtitle,
    String action,
    VoidCallback onAction,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: darkColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: mutedColor, fontSize: 11),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onAction, child: Text(action)),
      ],
    );
  }

  Widget _doctorPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search doctors or specialties',
              prefixIcon: const Icon(Icons.search, color: primaryColor),
              suffixIcon: IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _specialties.map((specialty) {
              final selected = _specialty == specialty;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(specialty),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: primaryColor,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : darkColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  onSelected: (_) => setState(() => _specialty = specialty),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: _loadingDoctors
              ? const _Loading()
              : _doctorError != null
                  ? _errorView()
                  : _filteredDoctors.isEmpty
                      ? const _Empty(
                          icon: Icons.search_off_rounded,
                          title: 'No matching doctors',
                          message: 'Try a different search or specialty.',
                        )
                      : RefreshIndicator(
                          onRefresh: _loadDoctors,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredDoctors.length,
                            itemBuilder: (context, index) {
                              final doctor = _filteredDoctors[index];
                              return _doctorCard(
                                doctor,
                                () => _book(doctor),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _doctorCard(Doctor doctor, VoidCallback onBook) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(color: Color(0xFFE7EDF3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            CircleAvatar(
              radius: 29,
              backgroundColor: const Color(0xFFE2F3F5),
              backgroundImage:
                  doctor.image.isNotEmpty ? NetworkImage(doctor.image) : null,
              child: doctor.image.isEmpty
                  ? const Icon(Icons.person, color: primaryColor)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: darkColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    doctor.specialty,
                    style: const TextStyle(
                      color: primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sample profile • Age ${doctor.age}',
                    style: const TextStyle(
                      color: mutedColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onBook,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: primaryColor,
              ),
              child: const Text('Book'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appointmentPage() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const TabBar(
              labelColor: primaryColor,
              unselectedLabelColor: mutedColor,
              indicatorColor: accentColor,
              tabs: [
                Tab(text: 'Upcoming'),
                Tab(text: 'Past'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _appointmentList(_upcoming),
                _appointmentList(_past),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appointmentList(List<Appointment> appointments) {
    if (appointments.isEmpty) {
      return const _Empty(
        icon: Icons.calendar_month_rounded,
        title: 'No appointments here',
        message: 'Your appointments will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appointments.length,
        itemBuilder: (context, index) =>
            _appointmentCard(appointments[index]),
      ),
    );
  }

  Widget _appointmentCard(Appointment appointment) {
    final date = DateTime.parse(appointment.appointmentDate);
    final isScheduled = appointment.status == 'Scheduled';

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(color: Color(0xFFE7EDF3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5F8),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('MMM').format(date).toUpperCase(),
                        style: const TextStyle(
                          color: primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${date.day}',
                        style: const TextStyle(
                          color: darkColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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
                          color: darkColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appointment.specialty,
                        style: const TextStyle(
                          color: primaryColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${DateFormat('EEE').format(date)} • ${DateFormat('hh:mm a').format(date)}',
                        style: const TextStyle(
                          color: mutedColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isScheduled
                        ? const Color(0xFFE0F5EA)
                        : const Color(0xFFECEFF3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    appointment.status,
                    style: TextStyle(
                      color: isScheduled
                          ? const Color(0xFF18764A)
                          : mutedColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 25),
            Text(
              'Patient: ${appointment.patientName}',
              style: const TextStyle(color: darkColor, fontSize: 12),
            ),
            const SizedBox(height: 5),
            Text(
              'Reason: ${appointment.reason}',
              style: const TextStyle(color: mutedColor, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 5,
              children: [
                if (isScheduled)
                  TextButton.icon(
                    onPressed: () => _reschedule(appointment),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 17),
                    label: const Text('Reschedule'),
                  ),
                TextButton.icon(
                  onPressed: () => _deleteAppointment(appointment),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 17,
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

  Widget _profilePage() {
    final initials = widget.user.name.trim().isEmpty
        ? 'U'
        : widget.user.name.trim().substring(0, 1).toUpperCase();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [primaryColor, Color(0xFF209DAB)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: primaryColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.user.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.user.email,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _profileTile(
          Icons.calendar_month_rounded,
          'My appointments',
          '${_appointments.length} saved appointments',
          () => setState(() => _selectedIndex = 2),
        ),
        const SizedBox(height: 10),
        _profileTile(
          Icons.medical_services_rounded,
          'Find a doctor',
          'Browse available sample profiles',
          () => setState(() => _selectedIndex = 1),
        ),
        const SizedBox(height: 10),
        _profileTile(
          Icons.info_outline_rounded,
          'About MedBook',
          'Medical appointment booking demo app',
          () => showAboutDialog(
            context: context,
            applicationName: 'MedBook',
            applicationVersion: '1.0.0',
            children: const [
              Text(
                'This student project demonstrates doctor search, local accounts, and appointment management. Doctor profiles and times are sample data, not real clinic availability.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4DE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Demo account: account details are stored locally in this browser or device. Do not use a real or reused password.',
            style: TextStyle(
              color: Color(0xFF77571B),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Log out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            padding: const EdgeInsets.all(15),
            side: const BorderSide(color: Color(0xFFFFD5D5)),
          ),
        ),
      ],
    );
  }

  Widget _profileTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE7EDF3)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5F8),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: primaryColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: darkColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: mutedColor, fontSize: 11),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Future<void> _book(Doctor doctor) async {
    final nameController = TextEditingController(text: widget.user.name);
    final reasonController = TextEditingController();

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String selectedTime = '09:00 AM';

    const times = [
      '09:00 AM',
      '10:00 AM',
      '11:00 AM',
      '01:00 PM',
      '02:00 PM',
      '03:00 PM',
      '04:00 PM',
    ];

    try {
      final appointment = await showDialog<Appointment>(
        context: context,
        builder: (dialogContext) {
          final formKey = GlobalKey<FormState>();

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text(
                  'Book appointment',
                  style: TextStyle(
                    color: darkColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                content: SizedBox(
                  width: 400,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFEAF5F8),
                              backgroundImage: doctor.image.isNotEmpty
                                  ? NetworkImage(doctor.image)
                                  : null,
                              child: doctor.image.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color: primaryColor,
                                    )
                                  : null,
                            ),
                            title: Text(doctor.name),
                            subtitle: Text(doctor.specialty),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Patient name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Enter the patient name.'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: reasonController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Reason for visit',
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? 'Enter the reason for the visit.'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final now = DateTime.now();
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                ),
                                lastDate: now.add(const Duration(days: 365)),
                              );

                              if (date != null) {
                                setDialogState(() => selectedDate = date);
                              }
                            },
                            icon: const Icon(Icons.calendar_month_rounded),
                            label: Text(
                              DateFormat('EEE, MMM d, yyyy')
                                  .format(selectedDate),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: selectedTime,
                            decoration: const InputDecoration(
                              labelText: 'Appointment time',
                              prefixIcon: Icon(Icons.access_time_rounded),
                            ),
                            items: times
                                .map(
                                  (time) => DropdownMenuItem(
                                    value: time,
                                    child: Text(time),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => selectedTime = value);
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
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;

                      final dateTime =
                          _combineDateTime(selectedDate, selectedTime);

                      if (!dateTime.isAfter(DateTime.now())) {
                        _message('Choose a future appointment time.');
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                        Appointment(
                          id: DateTime.now().microsecondsSinceEpoch,
                          doctorName: doctor.name,
                          specialty: doctor.specialty,
                          patientName: nameController.text.trim(),
                          reason: reasonController.text.trim(),
                          appointmentDate: dateTime.toIso8601String(),
                          accountEmail: widget.user.email,
                        ),
                      );
                    },
                    child: const Text('Confirm booking'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (appointment == null) return;

      try {
        await _storage.addAppointment(appointment);
        await _loadAppointments();

        if (!mounted) return;
        setState(() => _selectedIndex = 2);
        _message('Appointment saved successfully.');
      } catch (_) {
        _message('Could not save appointment. Please try again.');
      }
    } finally {
  await Future<void>.delayed(const Duration(milliseconds: 400));

  nameController.dispose();
  reasonController.dispose();
  }
  }

  DateTime _combineDateTime(DateTime date, String time) {
    final parts = time.split(' ');
    final clock = parts[0].split(':');

    int hour = int.parse(clock[0]);
    final minute = int.parse(clock[1]);

    if (parts[1] == 'PM' && hour != 12) hour += 12;
    if (parts[1] == 'AM' && hour == 12) hour = 0;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Future<void> _reschedule(Appointment appointment) async {
    DateTime selectedDate = DateTime.parse(appointment.appointmentDate);
    String selectedTime = DateFormat('hh:mm a').format(selectedDate);

    const times = [
      '09:00 AM',
      '10:00 AM',
      '11:00 AM',
      '01:00 PM',
      '02:00 PM',
      '03:00 PM',
      '04:00 PM',
    ];

    if (!times.contains(selectedTime)) selectedTime = times.first;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reschedule appointment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate.isBefore(now)
                            ? DateTime(now.year, now.month, now.day)
                                .add(const Duration(days: 1))
                            : selectedDate,
                        firstDate: DateTime(now.year, now.month, now.day),
                        lastDate: now.add(const Duration(days: 365)),
                      );

                      if (date != null) {
                        setDialogState(() => selectedDate = date);
                      }
                    },
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: Text(
                      DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTime,
                    decoration: const InputDecoration(labelText: 'New time'),
                    items: times
                        .map(
                          (time) => DropdownMenuItem(
                            value: time,
                            child: Text(time),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedTime = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final newDate =
                        _combineDateTime(selectedDate, selectedTime);

                    if (!newDate.isAfter(DateTime.now())) {
                      _message('Choose a future appointment time.');
                      return;
                    }

                    Navigator.pop(dialogContext, newDate);
                  },
                  child: const Text('Save changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      final updated = Appointment(
        id: appointment.id,
        doctorName: appointment.doctorName,
        specialty: appointment.specialty,
        patientName: appointment.patientName,
        reason: appointment.reason,
        appointmentDate: result.toIso8601String(),
        accountEmail: widget.user.email,
        status: 'Scheduled',
      );

      final success = await _storage.updateAppointment(updated);
      await _loadAppointments();

      _message(
        success ? 'Appointment rescheduled.' : 'Appointment was not found.',
      );
    } catch (_) {
      _message('Could not reschedule the appointment.');
    }
  }

  Future<void> _deleteAppointment(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete appointment?'),
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
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await _storage.deleteAppointment(
        appointment.id,
        widget.user.email,
      );

      await _loadAppointments();

      _message(success ? 'Appointment deleted.' : 'Appointment not found.');
    } catch (_) {
      _message('Could not delete the appointment.');
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out of MedBook?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _storage.logout();
    if (mounted) widget.onLogout();
  }

  Widget _errorView() {
    return _Empty(
      icon: Icons.cloud_off_rounded,
      title: 'Unable to load profiles',
      message: _doctorError ?? 'Check your internet connection.',
      action: TextButton.icon(
        onPressed: _loadDoctors,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Try again'),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(30),
      child: Center(
        child: CircularProgressIndicator(color: primaryColor),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE7EDF3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: primaryColor),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: darkColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: mutedColor,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
