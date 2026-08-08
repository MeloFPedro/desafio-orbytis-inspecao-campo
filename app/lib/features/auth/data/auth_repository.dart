import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/user.dart';
import 'auth_api.dart';

class AuthRepository {
  const AuthRepository(this._api, this._storage);

  final AuthApi _api;
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  /// Autentica e persiste sessão. Lança [Failure] em caso de erro.
  Future<User> login({required String email, required String password}) async {
    final data = await _api.login(email: email, password: password);

    final token = data['accessToken'] as String;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);

    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

    return user;
  }

  /// Devolve o usuário da sessão salva, ou null se não houver.
  ///
  /// Lê apenas do disco: funciona sem rede, que é o comportamento correto
  /// para um app de campo.
  Future<User?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    final rawUser = await _storage.read(key: _userKey);

    if (token == null || rawUser == null) return null;

    return User.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
  }

  /// Usado pelo interceptor para montar o header Authorization.
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
