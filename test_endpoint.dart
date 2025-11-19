import 'package:http/http.dart' as http;

void main() async {
  print('Testing endpoint...');

  try {
    // If you've set root to /api, use this URL:
    final String serverUrl = 'https://secure-chat-app-thb4.vercel.app';
    print('Server URL: $serverUrl');

    final response = await http.get(
      // If you've set root to /api, remove the /api prefix:
      Uri.parse('$serverUrl/send-notification'),
    );

    print('GET Response Status: ${response.statusCode}');
    print('GET Response Body: ${response.body}');

    if (response.statusCode == 200) {
      print('SUCCESS: Endpoint is accessible');
    } else {
      print('ERROR: Endpoint returned status ${response.statusCode}');
    }
  } catch (e) {
    print('EXCEPTION: $e');
  }
}
