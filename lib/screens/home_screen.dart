// ignore_for_file: unused_field, avoid_print

import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
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
  int _stepOffset = 0; // To calculate daily steps relative to boot
  final int _waterGoal = 2000; // 2000ml goal
  final int _stepGoal = 5000;

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
    // Request permission for Android 10+
    await Permission.activityRecognition.request();
    
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen((StepCount event) {
      // NOTE: event.steps is total steps since last boot. 
      // In a real production app, you need logic to store the 'boot' offset.
      // For this MVP, we will just display the sensor data directly.
      setState(() {
        _steps = event.steps; 
      });
      // Save to Supabase occasionally (Debouncing recommended in real app)
      _service.updateSteps(_steps);
    }).onError((error) {
      print('Pedometer Error: $error');
    });
  }

  void _addWater() {
    setState(() {
      _waterIntake += 250; // Add 250ml cup
    });
    _service.updateWater(_waterIntake);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FitPulse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _service.signOut(),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // 1. Water Section
              const Text("Hydration", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              CircularPercentIndicator(
                radius: 80.0,
                lineWidth: 13.0,
                animation: true,
                percent: (_waterIntake / _waterGoal).clamp(0.0, 1.0),
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.water_drop, size: 30, color: Colors.blue),
                    Text("$_waterIntake ml", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                footer: Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Add 250ml"),
                    onPressed: _addWater,
                  ),
                ),
                circularStrokeCap: CircularStrokeCap.round,
                progressColor: Colors.blueAccent,
                backgroundColor: Colors.blue.shade100,
              ),

              const Divider(height: 60),

              // 2. Steps Section
              const Text("Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      const Icon(Icons.directions_walk, size: 50, color: Colors.orange),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("$_steps", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                          Text("Goal: $_stepGoal", style: const TextStyle(color: Colors.grey)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}