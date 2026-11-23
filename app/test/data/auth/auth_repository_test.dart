import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punto_venta/data/auth/auth_repository.dart';

void main() {
  late Dio client;
  late _LoginAdapter adapter;
  late _MemoryAuthTokenStore tokenStore;
  late AuthRepository repository;

  setUp(() {
    adapter = _LoginAdapter();
    client = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = adapter;
    tokenStore = _MemoryAuthTokenStore();
    repository = AuthRepository(client, tokenStore);
  });

  tearDown(() {
    client.close(force: true);
  });

  test('sends credentials to the API and saves the returned tokens', () async {
    adapter.responseData = {
      'accessToken': 'access-token',
      'refreshToken': 'refresh-token',
      'expiresAt': '2026-11-23T20:30:00Z',
    };

    final tokens = await repository.login(
      email: '  user@example.test ',
      password: 'secret',
    );

    final request = adapter.requestOptions!;
    final requestData = request.data;
    final credentials = requestData is String
        ? jsonDecode(requestData)
        : requestData;
    expect(request.method, 'POST');
    expect(request.path, '/auth/login');
    expect(credentials, {'email': 'user@example.test', 'password': 'secret'});
    expect(tokens.accessToken, 'access-token');
    expect(tokens.refreshToken, 'refresh-token');
    expect(tokens.expiresAt.isUtc, isTrue);
    expect(tokenStore.savedTokens, tokens);
  });

  test('surfaces API login errors without storing tokens', () async {
    adapter.statusCode = 401;
    adapter.responseData = {
      'code': 'invalid_credentials',
      'message': 'Correo o contraseña incorrectos.',
    };

    await expectLater(
      repository.login(email: 'user@example.test', password: 'wrong'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          'Correo o contraseña incorrectos.',
        ),
      ),
    );
    expect(tokenStore.savedTokens, isNull);
  });

  test('rejects malformed token responses without storing them', () async {
    adapter.responseData = {
      'accessToken': 'access-token',
      'expiresAt': '2026-11-23T20:30:00Z',
    };

    await expectLater(
      repository.login(email: 'user@example.test', password: 'secret'),
      throwsA(isA<AuthException>()),
    );
    expect(tokenStore.savedTokens, isNull);
  });

  test(
    'reads the Admin role and user id from the stored access token',
    () async {
      tokenStore.savedTokens = AuthTokens(
        accessToken: _tokenWithClaims({'sub': 'admin-user', 'role': 'Admin'}),
        refreshToken: 'refresh-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      );

      final session = await repository.currentSession();

      expect(session?.userId, 'admin-user');
      expect(session?.role, AuthRole.admin);
    },
  );

  test('does not expose a session after the access token expires', () async {
    tokenStore.savedTokens = AuthTokens(
      accessToken: _tokenWithClaims({'sub': 'admin-user', 'role': 'Admin'}),
      refreshToken: 'refresh-token',
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );

    expect(await repository.currentSession(), isNull);
  });
}

class _MemoryAuthTokenStore implements AuthTokenStore {
  AuthTokens? savedTokens;

  @override
  Future<void> save(AuthTokens tokens) async {
    savedTokens = tokens;
  }

  @override
  Future<AuthTokens?> read() async => savedTokens;
}

class _LoginAdapter implements HttpClientAdapter {
  int statusCode = 200;
  Object? responseData;
  RequestOptions? requestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestOptions = options;
    return ResponseBody.fromString(
      jsonEncode(responseData),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _tokenWithClaims(Map<String, Object> claims) {
  final payload = base64Url.encode(utf8.encode(jsonEncode(claims)));
  return 'header.$payload.signature';
}
