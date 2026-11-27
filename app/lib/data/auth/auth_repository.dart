import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/providers.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory AuthTokens.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const AuthException('La respuesta de autenticación no es válida.');
    }

    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final expiresAtValue = json['expiresAt'];
    final expiresAt = expiresAtValue is String
        ? DateTime.tryParse(expiresAtValue)
        : null;
    if (accessToken is! String ||
        accessToken.trim().isEmpty ||
        refreshToken is! String ||
        refreshToken.trim().isEmpty ||
        expiresAt == null) {
      throw const AuthException('La respuesta de autenticación no es válida.');
    }

    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt.toUtc(),
    );
  }

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  Map<String, Object> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };
}

enum AuthRole { admin, cashier, unknown }

class AuthSession {
  const AuthSession({required this.userId, required this.role});

  final String userId;
  final AuthRole role;
}

abstract interface class AuthTokenStore {
  Future<void> save(AuthTokens tokens);
  Future<AuthTokens?> read();
}

class SecureAuthTokenStore implements AuthTokenStore {
  SecureAuthTokenStore(this._storage);

  static const _tokensKey = 'auth.tokens';

  final FlutterSecureStorage _storage;

  @override
  Future<void> save(AuthTokens tokens) async {
    try {
      await _storage.write(key: _tokensKey, value: jsonEncode(tokens.toJson()));
    } on PlatformException catch (error) {
      throw AuthException(
        'No se pudieron guardar las credenciales de forma segura: '
        '${error.message ?? error.code}',
      );
    } on MissingPluginException {
      throw const AuthException(
        'El almacenamiento seguro no está disponible en este dispositivo.',
      );
    }
  }

  @override
  Future<AuthTokens?> read() async {
    try {
      final value = await _storage.read(key: _tokensKey);
      if (value == null) {
        return null;
      }
      try {
        return AuthTokens.fromJson(jsonDecode(value));
      } on FormatException {
        throw const AuthException(
          'La sesión guardada no tiene un formato válido.',
        );
      }
    } on PlatformException catch (error) {
      throw AuthException(
        'No se pudieron leer las credenciales seguras: '
        '${error.message ?? error.code}',
      );
    } on MissingPluginException {
      throw const AuthException(
        'El almacenamiento seguro no está disponible en este dispositivo.',
      );
    }
  }
}

class AuthRepository {
  AuthRepository(this._client, this._tokenStore);

  final Dio _client;
  final AuthTokenStore _tokenStore;

  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const AuthException('Ingresa tu correo y contraseña.');
    }

    late final Response<Object?> response;
    try {
      response = await _client.post<Object?>(
        '/auth/login',
        data: {'email': normalizedEmail, 'password': password},
      );
    } on DioException catch (error) {
      throw _loginException(error);
    }

    final tokens = AuthTokens.fromJson(response.data);
    await _tokenStore.save(tokens);
    return tokens;
  }

  Future<AuthSession?> currentSession() async {
    final tokens = await _tokenStore.read();
    if (tokens == null || !tokens.expiresAt.isAfter(DateTime.now().toUtc())) {
      return null;
    }

    final parts = tokens.accessToken.split('.');
    if (parts.length != 3) {
      throw const AuthException(
        'El token de acceso no tiene un formato válido.',
      );
    }

    late final Object? payload;
    try {
      final bytes = base64Url.decode(base64Url.normalize(parts[1]));
      payload = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const AuthException(
        'El token de acceso no tiene un formato válido.',
      );
    }
    if (payload is! Map<String, dynamic>) {
      throw const AuthException(
        'El token de acceso no tiene un formato válido.',
      );
    }

    final userId = _claim(
      payload,
      'sub',
      'nameid',
      'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier',
    );
    final role = _claim(
      payload,
      'role',
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role',
    );
    if (userId == null || userId.trim().isEmpty) {
      throw const AuthException('El token no identifica al usuario.');
    }

    return AuthSession(
      userId: userId,
      role: switch (role) {
        'Admin' => AuthRole.admin,
        'Cajero' => AuthRole.cashier,
        _ => AuthRole.unknown,
      },
    );
  }

  String? _claim(
    Map<String, dynamic> claims,
    String first, [
    String? second,
    String? third,
  ]) {
    for (final name in [first, second, third]) {
      if (name == null) {
        continue;
      }
      final value = claims[name];
      if (value is String) {
        return value;
      }
    }
    return null;
  }

  AuthException _loginException(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'];
      if (message is String && message.trim().isNotEmpty) {
        return AuthException(message);
      }
    }

    if (error.response?.statusCode == 401) {
      return const AuthException('Correo o contraseña incorrectos.');
    }
    if (error.response == null) {
      return const AuthException(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }
    return const AuthException(
      'No se pudo iniciar sesión. Intenta nuevamente.',
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    SecureAuthTokenStore(ref.watch(secureStorageProvider)),
  );
});

final authSessionProvider = FutureProvider<AuthSession?>((ref) {
  return ref.watch(authRepositoryProvider).currentSession();
});
