import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ttc_ict_mobile/core/network/api_client.dart';

class _NeverRespondingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Completer<http.StreamedResponse>().future;
}

void main() {
  test('local API URL uses host loopback outside Android', () {
    expect(ApiClient.baseUrl, 'http://127.0.0.1:3001/api');
  });

  test('network request exits loading state through a timeout', () async {
    final api = ApiClient(
      client: _NeverRespondingClient(),
      requestTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(api.get('/health'), throwsA(isA<TimeoutException>()));
  });
}
