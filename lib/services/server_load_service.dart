import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_config.dart';

class ServerLoadService {
  static final ServerLoadService instance = ServerLoadService._internal();
  ServerLoadService._internal();

  Future<String> getServerLoad() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.backendUrl}/api/load'))
          .timeout(const Duration(milliseconds: 500));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['load'] ?? 'medium';
      }
    } catch (e) {
      // Default to medium if ping fails
    }
    return 'medium';
  }
}
