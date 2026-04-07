import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';

class SystemStatusApi {
  Future<SystemStatus> fetchStatus() async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl.replaceFirst('/api', '')}/api/v1/system-status',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch system status');
    }
    final data = jsonDecode(response.body);
    return SystemStatus(
      status: data['status'] ?? 'live',
      comingSoonFinalDate: data['coming_soon_final_date'],
    );
  }
}

class SystemStatus {
  final String status;
  final String? comingSoonFinalDate;
  SystemStatus({required this.status, this.comingSoonFinalDate});
}
