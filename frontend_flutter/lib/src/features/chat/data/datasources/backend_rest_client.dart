import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:http_parser/http_parser.dart';

@lazySingleton
class BackendRestClient {
  final Dio _dio;
  BackendRestClient() : _dio = Dio();

  set baseUrl(String url) => _dio.options.baseUrl = url;
  set bearer(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<String> uploadBytes(String name, List<int> bytes, {String? mime, void Function(int, int)? onProgress, void Function(void Function())? onCreateCancel}) async {
    final cancelToken = CancelToken();
    try {
      onCreateCancel?.call(() {
        try { cancelToken.cancel("user"); } catch (_) {}
      });
    } catch (_) {}
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: name,
        contentType: mime != null ? MediaType.parse(mime) : null,
      ),
    });
    final resp = await _dio.post('/v1/files', data: form, onSendProgress: onProgress, cancelToken: cancelToken);
    return (resp.data as Map<String, dynamic>)['fileId'] as String;
  }

  Future<List<int>> downloadBytes(String fileId) async {
    final resp = await _dio.get<List<int>>('/v1/files/' + fileId, options: Options(responseType: ResponseType.bytes));
    return resp.data ?? <int>[];
  }

  Future<Map<String, dynamic>> healthz() async {
    final resp = await _dio.get('/healthz');
    return (resp.data as Map<String, dynamic>);
  }
}


