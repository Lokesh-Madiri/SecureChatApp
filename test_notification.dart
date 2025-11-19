import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('Testing notification server...');

  try {
    final String serverUrl = 'https://secure-chat-app-thb4.vercel.app';
    print('Server URL: $serverUrl');

    final response = await http.post(
      Uri.parse('$serverUrl/api/send-notification'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': 'test-user-id',
        'title': 'Test Notification',
        'body': 'This is a test notification',
        'data': {'type': 'test'},
      }),
    );

    print('Response Status: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      print('SUCCESS: Server is working correctly');
    } else {
      print('ERROR: Server returned status ${response.statusCode}');
    }
  } catch (e) {
    print('EXCEPTION: $e');
  }
}
