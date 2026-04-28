import 'package:connectivity_plus/connectivity_plus.dart';

/// Labels used in Gemini context and CSV (`wifi` / `4g` / `3g` / `none` / `unknown`).
Future<String> networkTypeForResearch() async {
  final result = await Connectivity().checkConnectivity();
  if (result.contains(ConnectivityResult.wifi)) return 'wifi';
  if (result.contains(ConnectivityResult.mobile)) return '4g';
  if (result.contains(ConnectivityResult.none)) return 'none';
  return 'unknown';
}
