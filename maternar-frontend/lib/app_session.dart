import 'package:shared_preferences/shared_preferences.dart';

class AppSession {
  static const String _tokenKey = 'auth_token';
  static const String _nameKey = 'profile_name';
  static const String _emailKey = 'profile_email';
  static const String _dueDateKey = 'profile_due_date';

  static String? _token;
  static String? _name;
  static String? _email;
  static DateTime? _dueDate;

  static String? get token => _token;
  static bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  static String? get profileName => _name;
  static String? get profileEmail => _email;
  static DateTime? get dueDate => _dueDate;
    static int? get currentWeek =>
      _dueDate == null ? null : _currentWeekFromDueDate(_dueDate!);
    static int? get daysToBirth =>
      _dueDate == null ? null : _daysToBirthFromDueDate(_dueDate!);
  static bool get hasProfile =>
      (_name != null && _name!.isNotEmpty) &&
      (_email != null && _email!.isNotEmpty) &&
      _dueDate != null;

  static Future<void> init() async {
    final preferences = await SharedPreferences.getInstance();
    _token = preferences.getString(_tokenKey);
    _name = preferences.getString(_nameKey);
    _email = preferences.getString(_emailKey);

    final dueDateValue = preferences.getString(_dueDateKey);
    _dueDate = dueDateValue == null ? null : DateTime.tryParse(dueDateValue);
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
  }

  static Future<void> saveProfile({
    required String name,
    required String email,
    required DateTime dueDate,
  }) async {
    _name = name;
    _email = email;
    _dueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_nameKey, name);
    await preferences.setString(_emailKey, email);
    await preferences.setString(_dueDateKey, _dueDate!.toIso8601String());
  }

  static Future<void> clear() async {
    _token = null;
    _name = null;
    _email = null;
    _dueDate = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_nameKey);
    await preferences.remove(_emailKey);
    await preferences.remove(_dueDateKey);
  }

  static int _daysToBirthFromDueDate(DateTime dueDate) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final difference = due.difference(todayDate).inDays;
    return difference < 0 ? 0 : difference;
  }

  static int _currentWeekFromDueDate(DateTime dueDate) {
    final daysToBirth = _daysToBirthFromDueDate(dueDate);
    final elapsedDays = 280 - daysToBirth;
    final elapsedWeeks = (elapsedDays / 7).floor();
    if (elapsedWeeks < 1) return 1;
    if (elapsedWeeks > 40) return 40;
    return elapsedWeeks;
  }
}
