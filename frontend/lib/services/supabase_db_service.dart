import 'package:supabase_flutter/supabase_flutter.dart';
import 'danger_labels.dart';

/// Lightweight Supabase DB service for basic CRUD against `profiles`, `plans`, and related tables.
/// Use this from UI code or providers to read/write data using the client's authenticated session.
class SupabaseDbService {
  final _client = Supabase.instance.client;

  // Danger labels are centralized in `danger_labels.dart`.

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
    // Include related route data (if any) so the UI can show route image or metadata.
    // Use the actual relationship name in PostgREST: `routes` (not `route`).
    final res = await _client.from('plans').select('*, routes(*)').eq('user_id', uid).order('id', ascending: false);
    return res as List<dynamic>;
  }

  /// Fetch the latest plan for the current user and return the danger snapshot
  /// field if present. This looks for common column names used in the schema
  /// such as `dangers_snapshot` or `danger_snapshot` and returns the first
  /// non-null, non-empty string found, otherwise returns null.
  Future<String?> getLatestDangerSnapshot() async {
    final uid = _uid;
    if (uid == null) return null;

    // Request the latest plan and read the explicit `dangers_snapshot` column.
    final res = await _client.from('plans').select('id, dangers_snapshot').eq('user_id', uid).order('id', ascending: false).limit(1).maybeSingle();
    if (res == null) return null;

    final Map<String, dynamic> row = Map<String, dynamic>.from(res);
    final val = row['dangers_snapshot'];

    // If the column is a plain string, return it trimmed.
    if (val is String && val.trim().isNotEmpty) return val.trim();

    // If it's a Map (jsonb object) — extract keys with truthy values and
    // produce a human-friendly joined string, using the VN mapping when available.
    if (val is Map) {
      final Map m = val;
      final active = <String>[];
      m.forEach((k, v) {
        if (v == true) {
            final key = k.toString();
            final label = dangerLabelForKey(key);
            active.add(label);
        }
      });
      if (active.isNotEmpty) return active.join(', ');
      return null;
    }

    // If it's a List, map items through the VN labels when possible, then join
    if (val is List) {
      final items = val.where((e) => e != null).map((e) {
        final key = e.toString();
        return dangerLabelForKey(key);
      }).toList();
      if (items.isNotEmpty) return items.join(', ');
    }

    return null;
  }

  /// Create a plan for the current user. `body` should contain route_id, name, start_date, end_date, data, etc.
  Future<Map<String, dynamic>> createPlan(Map<String, dynamic> body) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    // Normalize incoming keys to match DB column names.
    final Map<String, dynamic> data = {};
    data['user_id'] = uid;

    // route_id may be provided as an id or nested object
    if (body.containsKey('route_id')) {
      data['route_id'] = body['route_id'];
    } else if (body['route'] is Map && body['route']['id'] != null) {
      data['route_id'] = body['route']['id'];
    }

    data['name'] = body['name'] ?? body['title'];
    data['location'] = body['location'] ?? body['location_input'] ?? body['payload']?['location'];
    data['rest_type'] = body['rest_type'] ?? body['payload']?['rest_type'] ?? body['accommodation'];
    data['group_size'] = body['group_size'] ?? body['payload']?['group_size'] ?? body['pax_group'];
    data['start_date'] = body['start_date'] ?? body['payload']?['start_date'];
    data['duration_days'] = body['duration_days'] ?? body['payload']?['duration_days'];

    // DB uses 'difficulty' column
    data['difficulty'] = body['difficulty'] ?? body['difficulty_input'] ?? body['payload']?['difficulty'];

    // JSON fields
    data['personal_interests'] = body['personal_interests'] ?? body['personal_interest'] ?? body['payload']?['personal_interests'] ?? body['payload']?['personal_interest'];
    data['personalized_equipment_list'] = body['personalized_equipment_list'] ?? body['personal_equipment_list'] ?? body['payload']?['personalized_equipment_list'];
    data['dangers_snapshot'] = body['dangers_snapshot'] ?? body['dangers'] ?? body['payload']?['dangers_snapshot'] ?? body['payload']?['dangers'];

    // Remove null entries
    final insertPayload = <String, dynamic>{};
    data.forEach((k, v) {
      if (v != null) insertPayload[k] = v;
    });

    final res = await _client.from('plans').insert(insertPayload).select().single();
    return Map<String, dynamic>.from(res);
  }

  /// Delete a plan by id belonging to the current user.
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
