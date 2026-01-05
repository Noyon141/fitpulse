// ignore_for_file: unused_field, avoid_print, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseService _service = SupabaseService();

  // Data State
  int _waterIntake = 0;
  int _steps = 0;

  // Goals
  final int _waterGoal = 2500;
  final int _stepGoal = 6000;

  // Pedometer State
  late Stream<StepCount> _stepCountStream;
  int _stepOffset = 0; // The sensor value at the "start" of our counting
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    // Load data from Supabase
    final data = await _service.getTodayStats();
    if (mounted) {
      setState(() {
        _waterIntake = data['water_ml'] ?? 0;
        _steps = data['steps'] ?? 0;
      });
    }

    // Start Pedometer listening
    _initPedometer();
  }

  Future<void> _initPedometer() async {
    await Permission.activityRecognition.request();

    _stepCountStream = Pedometer.stepCountStream;

    _stepCountStream
        .listen((StepCount event) async {
          if (!mounted) return;

          int sensorSteps = event.steps;
          SharedPreferences prefs = await SharedPreferences.getInstance();

          String todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
          String? savedDate = prefs.getString('last_step_date');
          int? savedOffset = prefs.getInt('day_step_offset');

          //If it's a NEW day, or we haven't set an offset yet
          if (savedDate != todayKey || savedOffset == null) {
            // Set new offset
            _stepOffset = sensorSteps - _steps;

            // Save these for future events
            await prefs.setString('last_step_date', todayKey);
            await prefs.setInt('day_step_offset', _stepOffset);
          } else {
            // Use existing offset
            _stepOffset = savedOffset;
          }

          // Calculate real steps for today
          int calculatedSteps = sensorSteps - _stepOffset;

          // Handle corner case: Device rebooted (sensor resets to 0, making result negative)
          if (calculatedSteps < 0) {
            _stepOffset = sensorSteps; // Reset offset
            calculatedSteps = 0;
            await prefs.setInt('day_step_offset', _stepOffset);
          }

          setState(() {
            _steps = calculatedSteps;
            _isInitialized = true;
          });

          // Update Database
          _service.updateSteps(_steps);
        })
        .onError((error) {
          print('Pedometer Error: $error');
        });
  }

  // RESET BUTTON LOGIC
  Future<void> _resetSteps() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() => _steps = 0);
    _service.updateSteps(0);

    await prefs.remove('day_step_offset');
  }

  void _addWater(int amount) {
    setState(() => _waterIntake += amount);
    _service.updateWater(_waterIntake);
  }

  String get _calories => (_steps * 0.04).toStringAsFixed(0);
  String get _distance => (_steps * 0.0008).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    String dateString = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'FitPulse',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: () => _service.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's Overview",
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
            ),
            Text(
              dateString,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 25),
            _buildActivityCard(),
            const SizedBox(height: 25),
            _buildHydrationCard(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard() {
    double progress = (_steps / _stepGoal).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Walking",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // RESET BUTTON
              GestureDetector(
                onTap: _resetSteps,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "$_steps",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "/ $_stepGoal steps",
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          LinearPercentIndicator(
            lineHeight: 8.0,
            percent: progress,
            backgroundColor: Colors.white24,
            progressColor: Colors.white,
            barRadius: const Radius.circular(10),
            padding: EdgeInsets.zero,
            animation: true,
            animateFromLastPercent: true,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(Icons.local_fire_department, "$_calories kcal"),
              _buildStatItem(Icons.location_on, "$_distance km"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 5),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildHydrationCard() {
    double percent = (_waterIntake / _waterGoal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hydration",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Goal: $_waterGoal ml",
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.water_drop, color: Colors.blueAccent),
            ],
          ),
          const SizedBox(height: 20),
          CircularPercentIndicator(
            radius: 70.0,
            lineWidth: 12.0,
            animation: true,
            percent: percent,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "${(percent * 100).toInt()}%",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                Text(
                  "Daily Goal",
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: const Color(0xFF4facfe),
            backgroundColor: Colors.blue.shade50,
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDrinkButton(
                "Small",
                "200ml",
                200,
                Icons.local_cafe_outlined,
              ),
              _buildDrinkButton(
                "Glass",
                "350ml",
                350,
                Icons.local_drink_outlined,
              ),
              _buildDrinkButton(
                "Bottle",
                "500ml",
                500,
                Icons.check_box_outline_blank_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrinkButton(
    String label,
    String amount,
    int value,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () => _addWater(value),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue.withOpacity(0.1)),
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
