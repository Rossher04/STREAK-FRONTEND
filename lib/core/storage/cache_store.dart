import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Caché local de la última respuesta (RN-74: modo lectura sin conexión).
abstract class CacheStore {
  Future<Map<String, dynamic>?> leer(String clave);
  Future<void> guardar(String clave, Map<String, dynamic> datos);

  /// Borra todo (al cerrar sesión, para no dejar datos de otra cuenta en el teléfono).
  Future<void> limpiar();
}

class HiveCacheStore implements CacheStore {
  static const _nombreBox = 'streak_cache';

  Future<Box<String>> _box() => Hive.openBox<String>(_nombreBox);

  @override
  Future<Map<String, dynamic>?> leer(String clave) async {
    try {
      final raw = (await _box()).get(clave);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } on Object {
      return null; // caché corrupta o no disponible: se trata como vacía
    }
  }

  @override
  Future<void> guardar(String clave, Map<String, dynamic> datos) async {
    try {
      await (await _box()).put(clave, jsonEncode(datos));
    } on Object {
      // La caché es opcional: un fallo al guardar no debe romper la pantalla.
    }
  }

  @override
  Future<void> limpiar() async {
    try {
      await (await _box()).clear();
    } on Object {
      // nada que limpiar
    }
  }
}

/// Implementación en memoria (pruebas).
class MemoryCacheStore implements CacheStore {
  final datos = <String, String>{};

  @override
  Future<Map<String, dynamic>?> leer(String clave) async {
    final raw = datos[clave];
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> guardar(String clave, Map<String, dynamic> valor) async =>
      datos[clave] = jsonEncode(valor);

  @override
  Future<void> limpiar() async => datos.clear();
}

final cacheStoreProvider = Provider<CacheStore>((ref) => HiveCacheStore());
