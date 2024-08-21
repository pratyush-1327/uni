import 'package:http/http.dart' as http;

class CallbackClient extends http.BaseClient {
  CallbackClient(http.Client inner,
      {required Future<http.StreamedResponse> Function(http.BaseRequest) send})
      : _inner = inner,
        _send = send;

  final http.Client _inner;
  final Future<http.StreamedResponse> Function(http.BaseRequest) _send;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _send(request);

  @override
  void close() => _inner.close();
}
