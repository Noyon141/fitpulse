import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _todayDate => DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Get today's stats or create them if they don't exist
  Future<Map<String, dynamic>> getTodayStats() async {
    final userId = _client.auth.currentUser!.id;

    final response = await _client
        .from('daily_stats')
        .select()
        .eq('user_id', userId)
        .eq('date', _todayDate)
        .maybeSingle();

    if (response == null) {
      // Initialize today's row
      final newRow = await _client
          .from('daily_stats')
          .insert({
            'user_id': userId,
            'date': _todayDate,
            'steps': 0,
            'water_ml': 0,
          })
          .select()
          .single();
      return newRow;
    }
    return response;
  }

  // Update Water
  Future<void> updateWater(int waterAmount) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('daily_stats').update({'water_ml': waterAmount}).match({
      'user_id': userId,
      'date': _todayDate,
    });
  }

  // Update Steps
  Future<void> updateSteps(int steps) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('daily_stats').update({'steps': steps}).match({
      'user_id': userId,
      'date': _todayDate,
    });
  }

  // Sign Out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
