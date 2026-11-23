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

abstract interface class AuthTokenStore {
  Future<void> save(AuthTokens tokens);
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
