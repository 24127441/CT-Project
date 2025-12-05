import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight Supabase DB service for basic CRUD against `profiles`, `plans`, and related tables.
/// Use this from UI code or providers to read/write data using the client's authenticated session.
class SupabaseDbService {
  final _client = Supabase.instance.client;

  /// Returns the current user's id or null if not signed in.
  String? get _uid => _client.auth.currentUser?.id;

  /// Fetch the current user's profile (or null if not found).
  Future<Map<String, dynamic>?> getProfile() async {
    final uid = _uid;
    if (uid == null) return null;

    final resp = await _client.from('profiles').select().eq('user_id', uid).maybeSingle();
    if (resp == null) return null;
    return Map<String, dynamic>.from(resp);
  }

  /// Upsert the profile for the current user. `data` can include `full_name`, `email`, `metadata`, etc.
  Future<void> upsertProfile(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    // Ensure we set user_id so RLS checks allow the insert/update
    final payload = Map<String, dynamic>.from(data);
    payload['user_id'] = uid;

    final res = await _client.from('profiles').upsert(payload).select().maybeSingle();
    if (res == null) throw Exception('Upsert profile returned null');
  }

  /// Fetch plans for the current user.
  Future<List<dynamic>> getPlans() async {
    final uid = _uid;
    if (uid == null) return [];

    final res = await _client.from('plans').select().eq('user_id', uid);
    return res as List<dynamic>;
  }

  /// Create a plan for the current user. `body` should contain route_id, name, start_date, end_date, data, etc.
  Future<Map<String, dynamic>> createPlan(Map<String, dynamic> body) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    final payload = Map<String, dynamic>.from(body);
    payload['user_id'] = uid;

    final res = await _client.from('plans').insert(payload).select().single();
    return Map<String, dynamic>.from(res);
  }

  /// Delete a plan by id (only if it belongs to current user)
  Future<void> deletePlan(int id) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    await _client.from('plans').delete().eq('id', id).eq('user_id', uid);
  }

  /// Fetch history input templates for current user.
  Future<List<Map<String, dynamic>>> getHistoryInputs() async {
    final uid = _uid;
    if (uid == null) return [];

    final res = await _client.from('history_inputs').select().eq('user_id', uid).order('id', ascending: false);
    return List<Map<String, dynamic>>.from(res as List<dynamic>);
  }

  /// Delete a history input by id (only if it belongs to current user)
  Future<void> deleteHistoryInput(int id) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    await _client.from('history_inputs').delete().eq('id', id).eq('user_id', uid);
  }

  /// Save a history input (template)
  Future<Map<String, dynamic>> saveHistoryInput(String name, Map<String, dynamic> payload) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    // Normalize payload: accept either a flattened payload (fields) or a nested payload map.
    final Map<String, dynamic> data = {};

    // Use explicit fields when present, falling back to nested keys in `payload`.
    data['user_id'] = uid;
    data['template_name'] = name;
    data['location'] = payload['location'] ?? payload['payload']?['location'];
    data['rest_type'] = payload['rest_type'] ?? payload['payload']?['rest_type'] ?? payload['accommodation'] ?? payload['payload']?['accommodation'];
    data['group_size'] = payload['group_size'] ?? payload['payload']?['group_size'] ?? payload['pax_group'] ?? payload['payload']?['pax_group'];
    data['start_date'] = payload['start_date'] ?? payload['payload']?['start_date'];
    data['duration_days'] = payload['duration_days'] ?? payload['payload']?['duration_days'];
    data['difficulty'] = payload['difficulty'] ?? payload['payload']?['difficulty'] ?? payload['difficulty_level'] ?? payload['payload']?['difficulty_level'];
    data['personal_interests'] = payload['personal_interest'] ?? payload['personal_interests'] ?? payload['payload']?['personal_interest'] ?? payload['payload']?['personal_interests'] ?? payload['interests'] ?? payload['payload']?['interests'];

    // Remove null keys so Supabase doesn't try to insert them as nulls unnecessarily.
    final insertPayload = <String, dynamic>{};
    data.forEach((k, v) {
      if (v != null) insertPayload[k] = v;
    });

    // Straightforward insert: expect table schema to match the keys we send.
    final res = await _client.from('history_inputs').insert(insertPayload).select().single();
    return Map<String, dynamic>.from(res);
  }
}
