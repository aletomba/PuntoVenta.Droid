---
name: flutter-feature
description: 'Implementar o modificar funcionalidades de la app Flutter en /app (Riverpod, go_router, Drift, Dio, offline-first). Usar para tareas [B]: pantallas, repositorios, base local, cliente HTTP, cola de sincronización y pruebas.'
---

# Funcionalidad Flutter en /app

Solo se edita `/app`. Nunca `/api` ni `docs/openapi.yaml` (eso va por la skill `contrato-openapi`).

## Antes de empezar
1. Leer el issue, `docs/plan.md` (sección de la tarea) y las operaciones relevantes de `docs/openapi.yaml`.
2. Mientras la API no esté lista, trabajar contra el mock: `npm run mock` (`tools/mock-server.mjs`, `http://localhost:4010`). No esperar al backend.
3. Al usar APIs puntuales de un paquete, consultar la documentación vigente (Context7 o la herramienta de pub.dev) y fijar la versión en `pubspec.yaml`.

## Estructura
```
app/lib/
  main.dart
  core/            app.dart, providers.dart, observability.dart (Sentry)
  data/local/      app_database.dart (Drift) y su .g.dart generado
  data/remote/     cliente Dio y DTOs
  features/<x>/    pantallas, controladores y providers por funcionalidad
app/test/          espejo de lib/
```

## Convenciones
- Estado y DI con Riverpod 3. Navegación con go_router.
- Offline-first: la UI lee y escribe en Drift. La red solo sincroniza vía cola local; una venta nunca depende de la conexión.
- Contrato: ids GUID, fechas UTC ISO 8601, **dinero como enteros en centavos** (nunca `double`), errores `{ "code": "...", "message": "..." }`. Formatear a moneda solo en la capa de presentación.
- Operaciones que se reintentan (ventas, anulaciones, sync) deben llevar un id generado en el cliente para que el backend las trate de forma idempotente.
- Tokens en `flutter_secure_storage`, nunca en Drift ni en logs. No registrar datos personales en Sentry.
- Sentry se inicializa solo si se pasa `--dart-define=SENTRY_DSN=...`.
- El archivo `app_database.g.dart` está versionado: si se cambian tablas o consultas Drift, regenerarlo y subirlo, y escribir la migración de esquema.

## Cambios en la base local
1. Editar `app_database.dart` y subir `schemaVersion`.
2. Agregar la migración en `onUpgrade`.
3. `dart run build_runner build` (en `/app`).
4. Probar la migración en `test/data/local/`.

## Verificación obligatoria (desde `/app`)
```powershell
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter build apk --debug   # si cambió Android, dependencias o plugins
```
Reportar cada comando con su resultado en el PR. El CI repite `analyze` y `test`.

## Pruebas
- Cada funcionalidad nueva trae pruebas: lógica con pruebas unitarias, pantallas con `testWidgets`, Drift con base en memoria.
- Cubrir los casos sin conexión y los reintentos.
- Probar importes con centavos (sin errores de redondeo).

## Dependencias
- Antes de actualizar plugins con código Android, comprobar compatibilidad con la versión de Kotlin/AGP del proyecto (`sentry_flutter` ya rompió la compilación una vez). Compilar el APK debug después de cualquier cambio.
- Cambios en dependencias van en su propio commit.
