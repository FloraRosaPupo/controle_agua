import 'package:dio/dio.dart';

class ApiClient {
  static const String baseUrl = 'https://controleagua-production.up.railway.app';


  final Dio dio;

  ApiClient()
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 90),
          headers: {
            'Content-Type': 'application/json',
            'x-timezone-offset': DateTime.now().timeZoneOffset.inMinutes.toString(),
          },
        ),
      ) {
    dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));
  }

  void setToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearToken() {
    dio.options.headers.remove('Authorization');
  }
}
