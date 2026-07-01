import 'dart:io';
import 'package:dio/dio.dart';

void main() async {
  final apiKey = 'YOUR_API_KEY';
  final isBearerToken = apiKey.length > 40 || apiKey.startsWith('eyJ');
  final dio = Dio();
  dio.options.baseUrl = 'https://api.themoviedb.org/3';
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (isBearerToken) {
        options.headers['Authorization'] = 'Bearer $apiKey';
      } else {
        options.queryParameters['api_key'] = apiKey;
      }
      handler.next(options);
    },
  ));

  try {
    final response = await dio.get('/search/movie', queryParameters: {'query': 'The Matrix'});
    print('Success: ${response.data}');
  } on DioException catch (e) {
    print('Dio Error: ${e.response?.statusCode} ${e.response?.data}');
  } catch (e) {
    print('Error: $e');
  }
}
