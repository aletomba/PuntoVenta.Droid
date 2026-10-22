---
name: code-reviewer
description: 'Revisar cambios o PR de PuntoVenta.Droid: contrato OpenAPI, dinero en centavos, idempotencia, multi-tenant, seguridad, offline-first y límites de rol. Usar antes de pedir o dar una aprobación.'
---

# Revisión de código de PuntoVenta.Droid

Solo lectura: se analiza y se reporta; no se modifican archivos. Revisar el diff completo (`git diff main...HEAD` o `gh pr diff <N>`) y leer el issue enlazado.

## 1. Alcance y roles
- [ ] El PR resuelve **una** tarea y cierra su issue (`Closes #N`).
- [ ] Un PR de `/app` no toca `/api`, y al revés; `docs/` y `.github/` solo por PR del dueño.
- [ ] `docs/openapi.yaml` no cambia en un PR de implementación; si cambia, es un PR `contrato` aparte.
- [ ] Sin cambios no relacionados ni archivos generados por error (`bin/`, `obj/`, `build/`, `.vscode/`).

## 2. Contrato
- [ ] Rutas, DTOs, códigos HTTP y nombres coinciden con `docs/openapi.yaml`.
- [ ] Errores con forma `{ "code", "message" }`; sin trazas ni datos internos.
- [ ] Ids GUID y fechas UTC ISO 8601 en ambos lados.
- [ ] El mock sigue alineado con el contrato.

## 3. Dinero
- [ ] Siempre enteros en centavos. Sin `double`/`float`/`decimal` en DTOs, base de datos ni estado de la app.
- [ ] Totales calculados con aritmética entera; precio guardado en la venta, no releído del catálogo.
- [ ] Formato de moneda solo al mostrar.

## 4. Backend (`/api`)
- [ ] **Tenant:** toda consulta filtra por el `TenantId` del JWT; ningún endpoint lo toma del cliente.
- [ ] **Autorización:** `[Authorize]` y roles correctos; ninguna ruta de datos queda pública.
- [ ] **Idempotencia** en crear/anular venta y `sync/push`: reintento con el mismo id no duplica.
- [ ] Validación de entrada y consultas parametrizadas (sin SQL concatenado).
- [ ] Controladores sin lógica de negocio; excepciones convertidas a errores del contrato.
- [ ] Migración de EF revisada, una por tarea, sin editar migraciones ya mergeadas.
- [ ] N+1, `ToList()` prematuros y consultas sin límite en listados.

## 5. App (`/app`)
- [ ] Offline-first: la UI no depende de la red para vender; la sincronización pasa por la cola local.
- [ ] Operaciones reintentables generan su id en el cliente.
- [ ] Tokens en `flutter_secure_storage`; nada sensible en logs, Drift ni Sentry.
- [ ] Cambios de tablas Drift con `schemaVersion`, migración y `.g.dart` regenerado.
- [ ] Estado con Riverpod, navegación con go_router; sin lógica de negocio dentro de widgets.
- [ ] Dependencias fijadas y compatibles con Android (APK debug compila).

## 6. Seguridad (repo público)
- [ ] Sin secretos, tokens, contraseñas reales ni cadenas de conexión de producción en el diff ni en el historial del PR.
- [ ] Sin endpoints de depuración ni CORS abierto sin motivo.
- [ ] Hash de contraseñas adaptativo; JWT con expiración y secreto externo.
- [ ] Dependencias nuevas con versión fija y de fuente confiable.

## 7. Pruebas y verificación
- [ ] Hay pruebas para la lógica nueva (centavos, tenant, idempotencia, offline).
- [ ] El PR indica los comandos ejecutados **con su resultado**: `flutter analyze`, `flutter test`, `dotnet build`, `dotnet test`.
- [ ] El CI está en verde.

## Formato del reporte
Agrupar por severidad y citar `archivo:línea`:
- **Bloqueante:** corrompe datos, rompe el contrato, filtra información o viola la seguridad.
- **Importante:** bug probable o regla del proyecto incumplida.
- **Sugerencia:** mejora de claridad o mantenimiento.

Terminar con un veredicto: **Aprobar**, **Aprobar con comentarios** o **Pedir cambios**. No reportar estilo trivial ni cosas que un linter ya detecta.
