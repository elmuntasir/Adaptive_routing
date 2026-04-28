import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

import 'app_state.dart';

class AppConfig {
  static final AppConfig instance = AppConfig._();
  AppConfig._();

  static String backendUrl = 'http://127.0.0.1:5005';
  static String geminiApiKey = '';
  static String geminiModel = 'gemini-2.5-flash'; // highly stable; must match dropdown items

  String get optimizationGoal => currentOperatingMode;

  String get apiMode => currentRoutingStrategy;

  static Future<void> initialize() async {
    if (!kIsWeb && Platform.isAndroid) {
      backendUrl = 'http://10.0.2.2:5005';
    }

    final prefs = await SharedPreferences.getInstance();
    backendUrl = prefs.getString('backend_url') ?? backendUrl;
    geminiApiKey = prefs.getString('gemini_api_key') ?? '';
    geminiModel = prefs.getString('gemini_model') ?? geminiModel;
  }

  static Future<void> setApiKey(String key) async {
    geminiApiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
  }

  static Future<void> setBackendUrl(String url) async {
    backendUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', url);
  }

  static Future<void> setGeminiModel(String model) async {
    geminiModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_model', model);
  }
}
