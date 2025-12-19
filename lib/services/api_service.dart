import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:5000/api';
    if (Platform.isAndroid) return 'http://192.168.1.115:5000/api';
    return 'http://127.0.0.1:5000/api'; // iOS/Desktop
  } 
  
  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 45),
  ));

  ApiService() {
    print('ApiService initialized with baseUrl: $baseUrl');
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        print('API Request [${options.method}] => ${options.uri}');
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Handle global errors here if needed
        print('API Error: ${e.response?.statusCode} - ${e.message}');
        if (e.type == DioExceptionType.connectionTimeout) {
          print('Connection Timeout occurred. BaseUrl: $baseUrl');
        } else if (e.type == DioExceptionType.receiveTimeout) {
          print('Receive Timeout occurred.');
        }
        
        if (e.response != null) {
          print('Response Data: ${e.response?.data}');
        }
        return handler.next(e);
      },
      onResponse: (response, handler) {
        print('API Response [${response.statusCode}] => ${response.realUri}');
        return handler.next(response);
      },
    ));
  }

  Dio get dio => _dio;
}
