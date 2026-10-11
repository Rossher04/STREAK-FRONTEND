// B2 contra el backend real: ver y editar el perfil (PATCH /usuarios/me/).
// Ver instrucciones de ejecución en auth_e2e_test.dart.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/core/network/dio_client.dart';
import 'package:streak_mobile/features/auth/data/auth_repository.dart';

import 'support/e2e_support.dart';

/// PNG de 1x1 píxel (el backend valida que sea una imagen real).
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  late AppE2E app;

  setUp(() async => app = await AppE2E.crear());
  tearDown(() => app.cerrar());

  test('editar nombre, apellidos y teléfono; usuario y correo no cambian', () async {
    final username = await app.registrarNuevo('perfil');
    final antes = app.sesion.user!;

    await app.auth.actualizarPerfil(firstName: 'Lucía', lastName: 'Gómez', telefono: '5555-1234');

    final u = app.sesion.user!;
    expect(u.firstName, 'Lucía');
    expect(u.lastName, 'Gómez');
    expect(u.telefono, '5555-1234');
    expect(u.username, username);
    expect(u.email, antes.email);

    // Persistido en el servidor: se vuelve a leer con una sesión nueva.
    final otra = await AppE2E.crear();
    addTearDown(otra.cerrar);
    await otra.auth.login(username, clave);
    expect(otra.sesion.user?.firstName, 'Lucía');
    expect(otra.sesion.user?.telefono, '5555-1234');
  });

  test('username, correo y es_pro son de solo lectura aunque se envíen', () async {
    final username = await app.registrarNuevo('soloLectura');
    final dio = app.container.read(dioProvider);
    final resp = await dio.patch('/usuarios/me/', data: {
      'username': 'hackeado',
      'email': 'hackeado@e2e.test',
      'es_pro': true,
      'first_name': 'Ok',
    });
    expect(resp.data['username'], username);
    expect(resp.data['email'], isNot('hackeado@e2e.test'));
    expect(resp.data['es_pro'], false);
    expect(resp.data['first_name'], 'Ok');
  });

  test('foto por multipart/form-data: queda una URL descargable', () async {
    await app.registrarNuevo('foto');
    expect(app.sesion.user?.fotoUrl, isNull);

    await app.auth.actualizarPerfil(
      firstName: 'Con',
      lastName: 'Foto',
      telefono: '',
      foto: FotoPerfil(bytes: _png, nombre: 'avatar.png'),
    );
    final url = app.sesion.user?.fotoUrl;
    expect(url, isNotNull);
    expect(url, startsWith('http'));
    final descarga = await app.container.read(dioProvider).get<List<int>>(
          url!,
          options: _bytes,
        );
    expect(descarga.statusCode, 200);
    expect(descarga.data, isNotEmpty);

    // Un PATCH posterior sin foto no la borra.
    await app.auth.actualizarPerfil(firstName: 'Sin', lastName: 'Cambio', telefono: '');
    expect(app.sesion.user?.fotoUrl, url);
  });

  test('error por campo: teléfono demasiado largo', () async {
    await app.registrarNuevo('largo');
    await expectLater(
      app.auth.actualizarPerfil(firstName: 'A', lastName: 'B', telefono: '1' * 30),
      throwsA(isA<AppException>().having((e) => e.mensaje, 'mensaje', startsWith('Teléfono: '))),
    );
  });
}

final _bytes = Options(responseType: ResponseType.bytes);
