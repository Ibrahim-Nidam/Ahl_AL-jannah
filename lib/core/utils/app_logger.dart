import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Comprehensive logging service that saves logs to device storage
/// for debugging purposes. Logs can be accessed and shared from the device.
class AppLogger {
  static const int _maxLogLines = 500;
  static const String _logKey = 'app_logs';
  static const String _logTimestampKey = 'last_log_timestamp';
  
  static final List<String> _inMemoryLogs = [];
  static bool _initialized = false;
  
  /// Initialize the logger
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLogs = prefs.getStringList(_logKey) ?? [];
      _inMemoryLogs.addAll(savedLogs);
      _initialized = true;
      debugPrint('AppLogger initialized with ${_inMemoryLogs.length} saved logs');
    } catch (e) {
      debugPrint('Failed to initialize AppLogger: $e');
      _initialized = true;
    }
  }
  
  /// Log a message with timestamp and category
  static void log(String category, String message, {Object? error, StackTrace? stackTrace}) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final logEntry = '[$timestamp] [$category] $message';
    
    _inMemoryLogs.add(logEntry);
    
    if (_inMemoryLogs.length > _maxLogLines) {
      _inMemoryLogs.removeRange(0, _inMemoryLogs.length - _maxLogLines);
    }
    
    // Also print to console for immediate debugging
    debugPrint(logEntry);
    
    if (error != null) {
      debugPrint('Error: $error');
      if (stackTrace != null) {
        debugPrint('StackTrace: $stackTrace');
      }
      _inMemoryLogs.add('Error: $error');
      if (stackTrace != null) {
        _inMemoryLogs.add('StackTrace: $stackTrace');
      }
    }
    
    // Persist logs asynchronously
    _persistLogs();
  }
  
  /// Convenience methods for different log levels
  static void info(String message) => log('INFO', message);
  static void warning(String message) => log('WARNING', message);
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    log('ERROR', message, error: error, stackTrace: stackTrace);
  }
  static void debug(String message) => log('DEBUG', message);
  
  /// Get all logs as a single string
  static String getAllLogs() {
    return _inMemoryLogs.join('\n');
  }
  
  /// Get logs as a list
  static List<String> getLogs() {
    return List.from(_inMemoryLogs);
  }
  
  /// Clear all logs
  static Future<void> clearLogs() async {
    _inMemoryLogs.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_logKey);
      await prefs.remove(_logTimestampKey);
      debugPrint('Logs cleared');
    } catch (e) {
      debugPrint('Failed to clear logs: $e');
    }
  }
  
  /// Export logs to a file that can be shared
  static Future<String?> exportLogsToFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/ahl_jannah_logs_$timestamp.txt');
      
      final logContent = getAllLogs();
      await file.writeAsString(logContent);
      
      debugPrint('Logs exported to: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('Failed to export logs: $e');
      return null;
    }
  }
  
  /// Persist logs to SharedPreferences
  static Future<void> _persistLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_logKey, _inMemoryLogs);
      await prefs.setString(_logTimestampKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Failed to persist logs: $e');
    }
  }
  
  /// Get the last N logs
  static List<String> getRecentLogs(int count) {
    if (_inMemoryLogs.length <= count) {
      return List.from(_inMemoryLogs);
    }
    return _inMemoryLogs.sublist(_inMemoryLogs.length - count);
  }
}
