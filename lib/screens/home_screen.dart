// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseService _service = SupabaseService();

  // State Variables
  int _waterIntake = 0;
  int _steps = 0;

  // Goals (You could make these editable in a settings screen later)
  final int _waterGoal = 2500;
  final int _stepGoal = 6000;

  late Stream<StepCount> _stepCountStream;

  @override
  void initState() {
    super.initState();
    _initData();
    _initPedometer();
  }

  Future<void> _initData() async {
    final data = await _service.getTodayStats();
    if (mounted) {
      setState(() {
        _waterIntake = data['water_ml'] ?? 0;
        _steps = data['steps'] ?? 0;
      });
    }
  }

  Future<void> _initPedometer() async {
    await Permission.activityRecognition.request();
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream
        .listen((StepCount event) {
          setState(() => _steps = event.steps);
          // Debounce this in a real app, but for now it's fine
          _service.updateSteps(_steps);
        })
        .onError((error) => print('Pedometer Error: $error'));
  }

  void _addWater(int amount) {
    setState(() => _waterIntake += amount);
    _service.updateWater(_waterIntake);
  }

  // Helper to calculate Calories (approx 0.04 cal per step)
  String get _calories => (_steps * 0.04).toStringAsFixed(0);

  // Helper to calculate Distance (approx 0.0008 km per step)
  String get _distance => (_steps * 0.0008).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    // Get current date for the header
    String dateString = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light Grey Background
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
        centerTitle: false,
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
            // 1. DATE HEADER
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

            // 2. ACTIVITY CARD (Gradient & Details)
            _buildActivityCard(),

            const SizedBox(height: 25),

            // 3. HYDRATION CARD (Circular + Quick Add)
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
        // Modern Gradient
        gradient: const LinearGradient(
          colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 77),
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
              const Icon(Icons.directions_walk, color: Colors.white70),
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
          ),
          const SizedBox(height: 20),
          // Sub-stats: Calories & Distance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(Icons.local_fire_department, "$_calories kcal"),
              _buildStatItem(Icons.location_on, "$_distance km"),
              _buildStatItem(Icons.timer, "0h 0m"), // Placeholder for time
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
            color: Colors.grey.withValues(alpha: 26),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.water_drop, color: Colors.blueAccent),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Circular Indicator
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

          // Quick Add Buttons
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
              ), // Generic bottle shape
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
              color: Colors.blue.withValues(alpha: 13),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue.withValues(alpha: 26)),
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
