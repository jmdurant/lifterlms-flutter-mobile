import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Testing LifterLMS Login...\n');
  
  // Test JWT login
  try {
    final response = await http.post(
      Uri.parse('https://polite-tree.myliftersite.com/wp-json/jwt-auth/v1/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': 'trial',
        'password': 'Czha6w9USEEbpd2D6CCjVC',
      }),
    );
    
    print('Login Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('Login Success!');
      print('Token: ${data['token']?.substring(0, 50)}...');
      print('User: ${data['user_display_name']}');
      print('Email: ${data['user_email']}');
    } else {
      print('Login Failed: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
  
  // Test courses API
  print('\nTesting Courses API...');
  try {
    final auth = base64Encode(utf8.encode('ck_0f0e0588e103e6ef372015eaa36a6c8ee1cddd59:cs_08f3bc87adcb6a090a2620479d91031d75ec213a'));
    final response = await http.get(
      Uri.parse('https://polite-tree.myliftersite.com/wp-json/llms/v1/courses?per_page=2'),
      headers: {
        'Authorization': 'Basic $auth',
        'Content-Type': 'application/json',
      },
    );
    
    print('Courses Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      print('Found ${data.length} courses');
      for (var course in data) {
        print('- ${course['title']['rendered']}');
      }
    } else {
      print('Failed to load courses: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}