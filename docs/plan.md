# Handoff para implementación: POS Android con cámara (MVP)

> Documento autocontenido para guiar la implementación del MVP POS.

## 0. Puesta en marcha y roles

### Roles (quién es quién)
- **Dueño + su agente de implementación** (el usuario que inicia el proyecto): crea el repo y hace toda la parte `[A]` (backend/infra) y `[A+B]` de la etapa 0. Hasta que entre el Dev B, también puede avanzar tareas `[B]` si el usuario lo pide.
- **Dev B + su agente**: se suma después y hace solo las tareas `[B]` (app Flutter en `/app`). **No toca `/api`** ni cambia `docs/openapi.yaml` sin un PR de contrato.

### 0.1 Lo que hace el agente del dueño ahora (una sola vez)
Antes de empezar, **preguntar al usuario**: nombre del repo, y si va en su cuenta personal o en una organización.
1. Crear repo **privado** con `gh repo create <nombre> --private --clone` y entrar a la carpeta.
2. Crear la estructura monorepo:
   ```
   /api        backend C# (.NET)
   /app        Flutter
   /docs       plan.md, openapi.yaml, diagramas.md
   /.github    plantillas de issue y de PR
   AGENTS.md   reglas para los agentes (ver 0.4)
   README.md   cómo clonar, instalar herramientas y correr cada parte
   .gitignore  (dotnet + flutter)
   ```
3. Copiar este plan a `docs/plan.md` y los diagramas a `docs/diagramas.md`.
4. Crear `AGENTS.md`, `README.md` y las plantillas de `.github/` (0.4 y 0.5).
5. Crear `docs/openapi.yaml` inicial a partir de la sección 8 (un único contrato para toda la API), en una rama y por PR (tarea 0.2).
6. Crear los **labels** `backend`, `app`, `contrato` y `bloqueado` con `gh label create`.
7. Crear los **issues** de la sección 10, uno por tarea, con su etiqueta, dueño, dependencias y criterio de "hecho cuando" (`gh issue create`). Crear además el issue **"Empezar aquí (Dev B)"** descrito en 0.3.
8. Subir el commit inicial a `main` y recién después activar la protección de `main`.
9. Proteger `main`: PR obligatorio, 1 aprobación, sin push directo. (Si el repo es personal y el dueño trabaja solo, permitir que el dueño haga bypass hasta que entre el Dev B; confirmarlo con el usuario.)
10. Dejar listo, además de lo anterior, el esqueleto de `/app` (tarea 0.4) y el mock del API, para que el Dev B no arranque con un repo vacío. El esqueleto de `/api` (tarea 0.3) lo hace el agente del dueño.

### 0.2 Lo que debe estar listo antes de que entre el Dev B
- Repo, estructura, `AGENTS.md`, `README.md`, plantillas, labels e issues creados.
- `docs/openapi.yaml` aprobado y mergeado, con el mock funcionando (Prism).
- Esqueleto de `/app` compilando (0.4).
- Issue "Empezar aquí (Dev B)" creado.

### 0.3 Cómo se suma el Dev B
1. El dueño lo invita al repo (`Settings → Collaborators`, o `gh api` / `gh repo` según corresponda); el Dev B acepta la invitación.
2. Clona el repo, instala Flutter (versión estable) y Android Studio/SDK, y corre `flutter doctor`.
3. Lee `README.md`, `AGENTS.md` y `docs/plan.md` (secciones 1 a 10).
4. Abre el issue **"Empezar aquí (Dev B)"**, que lista sus tareas en orden: 1.3, 1.4, 2.3, 2.4, 2.6, 3.2, 3.3, 4.1, 4.3, y cuáles dependen del backend.
5. Toma una tarea: se asigna el issue, crea su rama y sigue el flujo diario (0.5).
6. Mientras el backend no esté listo, trabaja contra el **mock** y no espera.

### 0.4 `AGENTS.md` (contenido inicial)
- Leer `docs/plan.md` y `docs/openapi.yaml` antes de actuar.
- **Respetar el rol**: el agente del Dev B implementa solo `[B]` en `/app`; el agente del dueño hace `[A]` y `[A+B]` en `/api`, `/docs` y `.github`. Nunca editar la carpeta del otro rol sin que lo pida su dueño.
- `docs/openapi.yaml` es la fuente de verdad. Cambiarlo solo por un PR con etiqueta `contrato`, que revisan ambos.
- Convenciones: ids GUID, fechas UTC ISO 8601, dinero como entero en centavos, errores `{code, message}`.
- Una tarea = una rama = un PR. No mezclar tareas.
- Antes de pedir revisión: la app corre `flutter analyze` y `flutter test`; la API compila y pasa sus tests.
- Consultar Context7 para APIs puntuales y fijar versiones al crear los proyectos (sección 11b).
- Ante dudas de alcance o contrato, abrir un issue con la etiqueta `contrato` o `bloqueado` en vez de inventar.

### 0.5 Flujo diario de cada dev (GitHub)
1. **Elegir tarea**: tomar un issue de su etiqueta (`app` o `backend`) cuyas dependencias estén cerradas, y asignárselo (`gh issue edit <N> --add-assignee @me`).
2. **Actualizar `main`**: `git checkout main && git pull`.
3. **Crear rama**: `git checkout -b feature/<app|api>-<tarea>-<descripcion>` (ej. `feature/app-1.3-escaner`).
4. **Trabajar con commits chicos** con formato `tipo(ámbito): descripción` (ej. `feat(app): escáner con mobile_scanner`). Tipos: `feat`, `fix`, `docs`, `test`, `chore`.
5. **Verificar en local** (analyze/test, o build de la API) antes de subir.
6. **Subir y abrir PR**: `git push -u origin <rama>` y `gh pr create`. El PR incluye `Closes #<issue>`, qué se probó y capturas si cambia la UI.
7. **Revisión cruzada**: el otro dev (o el dueño) revisa y aprueba; los checks de CI deben estar en verde.
8. **Merge** a `main` (squash) y borrar la rama. El issue se cierra solo.
9. **Bloqueos**: si la tarea depende de algo del otro, etiquetar `bloqueado`, comentar qué falta y pasar a otra tarea o al mock.
10. **Cambios al contrato**: PR aparte con etiqueta `contrato`, aprobado por ambos antes de implementar.
11. **Evitar conflictos**: cada uno edita solo su carpeta (`/api` o `/app`); `docs/` solo con PR.

### 0.6 Plantillas en `.github/`
- `ISSUE_TEMPLATE/tarea.md`: dueño, dependencias, descripción, "hecho cuando".
- `pull_request_template.md`: issue (`Closes #`), qué cambia, cómo se probó, capturas, checklist (analyze/test OK, contrato respetado).
- Workflows de CI por carpeta (se completan en las tareas 0.3, 0.4 y 4.x).

## 1. Objetivo
App Android de punto de venta para comercios. La cámara del celular escanea códigos de barras para (a) dar de alta productos y (b) armar la venta. MVP para ofrecer a comercios en piloto.

## 2. Decisiones tomadas
- **App**: Flutter (Dart), solo Android al inicio.
  - Escaneo: `mobile_scanner` (CameraX + ML Kit). Formatos: EAN-13, EAN-8, UPC-A/E, Code128, QR.
  - Estado: Riverpod. Navegación: go_router. HTTP: dio. Sesión: flutter_secure_storage.
  - Datos locales: Drift (SQLite), **offline-first**: la venta nunca depende de internet.
  - Ticket: `pdf` + `share_plus` (impresora Bluetooth ESC/POS opcional, fuera del MVP).
- **Backend**: ASP.NET Core Web API (C#) + PostgreSQL, EF Core, JWT, multi-comercio (`TenantId` en todas las entidades), Result pattern, Docker.
- **Cobro**: solo registrar el medio de pago manualmente (efectivo, tarjeta, transferencia, otro). Sin integraciones.
- **Panel web admin**: fase 2.
- **Usuario (dev)**: experiencia en C#/.NET.

## 3. Alcance MVP
1. Login (JWT) y comercio (tenant)
2. Catálogo: alta/edición escaneando código (nombre, precio, stock)
3. Venta: escanear → carrito → total → medio de pago → confirmar → ticket compartible
4. Stock descontado al vender
5. Historial de ventas y detalle
6. Cierre de caja diario
7. Sync offline → API
8. **Anulación de ventas** (solo Admin): genera una venta/movimiento de anulación y repone stock; no se edita ni borra la venta original
9. **Producto sin código de barras**: venta con "precio libre" (monto + descripción) y productos con búsqueda por nombre
10. **Roles**: Admin (precios, anulaciones, cierre de caja, usuarios) y Cajero (vender y ver sus ventas)
11. **Observabilidad**: logs estructurados y monitoreo de la API (Serilog + health checks + alerta de caída); reporte de errores de la app (Sentry o Firebase Crashlytics)
12. **Seguridad básica**: contraseñas hasheadas (Identity/PBKDF2), bloqueo por intentos fallidos, tokens con expiración corta + refresh, HTTPS obligatorio, tokens en secure storage

**Fase 2 (documentado, no se programa en el MVP)**: descuentos, importación masiva de productos (CSV/Excel), productos por peso, alerta de stock bajo y ajuste manual de stock, apertura de caja y movimientos de caja, cifrado de SQLite (SQLCipher), cierre de sesión remoto, panel web, onboarding automático de comercios.

**Fuera de alcance**: Mercado Pago/QR, factura electrónica (AFIP), IA por foto, multi-sucursal, iOS.

## 4. Arquitectura
Flutter UI → Riverpod/Repositorios → Drift (SQLite) + Cola de sync → (HTTPS + JWT) → ASP.NET Core API → PostgreSQL. Panel web (fase 2) → API.
Backend por capas: Controllers → Services → EF Core.

## 5. Modelo de datos (todas con `TenantId`, ids GUID generados en el cliente)
- TENANT(Id, Name)
- USER(Id, TenantId, Email, PasswordHash, Role: Admin|Cajero)
- PRODUCT(Id, TenantId, Barcode [único por tenant], Name, Price, Stock, UpdatedAt, IsDeleted)
- SALE(Id, TenantId, UserId, Date, Total, PaymentMethod, Status: Active|Voided, VoidedAt, VoidedByUserId, VoidReason, Synced[solo local])
- SALE_ITEM(Id, SaleId, ProductId [nullable si es precio libre], Description, Qty, UnitPrice)
- CASH_CLOSE(Id, TenantId, Day, Total, ByPaymentMethod)

## 6. Flujo de venta
Escanear → buscar en SQLite por Barcode → si no existe, ofrecer crear producto → agregar al carrito → cobrar (medio de pago) → guardar venta + descontar stock en una transacción local → mostrar/compartir ticket → sync en segundo plano.

## 7. Sincronización
- Push: ventas/productos con `Synced=false` en lotes a `POST /sync/push`; el servidor es **idempotente por GUID**.
- Pull: `GET /sync/pull?since=<lastSync>` trae productos cambiados.
- Ventas inmutables (sin conflictos). Productos: gana el mayor `UpdatedAt`.
- Sin internet: se reintenta luego (backoff).
- Stock: ajustar con deltas de ventas en servidor, no sobrescribir.

## 8. API (contrato inicial)
- `POST /auth/login`, `POST /auth/refresh`
- `GET/POST/PUT/DELETE /products`
- `POST /sales`, `GET /sales?from&to`, `POST /sales/{id}/void` (solo Admin, repone stock)
- `GET /cash-close?day`
- `POST /sync/push`, `GET /sync/pull`

## 9. Pantallas
Login → Inicio (Nueva venta / Productos / Historial / Caja). Nueva venta: Escáner+carrito (con búsqueda por nombre y "precio libre") → Cobro → Ticket. Productos: lista, alta con escaneo. Historial → Detalle de venta (con "Anular" para Admin). Cierre de caja.

## 10. Etapas unificadas (única fuente para crear los issues)
Dueños: **[A]** backend/infra (C#), **[B]** app Flutter, **[A+B]** ambos. Cada tarea = 1 issue con la etiqueta `backend`, `app` o `contrato`. Las etapas se avanzan en orden; dentro de cada etapa A y B trabajan en paralelo.

### Etapa 0: Base (hacer primero)
- [A+B] 0.1 Repo, estructura, `AGENTS.md`, plantillas, protección de `main`, labels e issues (sección 0). *Hecho cuando:* el Dev B clona el repo y ve `/api`, `/app`, `/docs`, los issues y el issue "Empezar aquí".
- [A+B] 0.2 Contrato `docs/openapi.yaml` (auth, products, sales, cash-close, sync + DTOs y errores). *Hecho cuando:* ambos aprueban el PR. **Bloquea** el código de endpoints (A) y del cliente HTTP (B).
- [A] 0.3 Esqueleto de API (.NET, EF Core, Postgres local con docker-compose, Swagger, Serilog, health checks). **Antes de codificar, verificar ASP.NET Core/EF Core/Npgsql/Docker con Context7 (sección 11b).** *Hecho cuando:* `GET /health` responde.
- [B] 0.4 Esqueleto Flutter (Riverpod, go_router, Drift, estructura de carpetas, mock del API con Prism, Sentry/Crashlytics). *Hecho cuando:* la app compila y corre en un dispositivo y un error de prueba llega al panel de errores.

### Etapa 1: Auth, productos y escaneo
- [A] 1.1 Auth JWT + tenants + usuarios + roles Admin/Cajero (`/auth/login`, `/auth/refresh`), bloqueo por intentos fallidos. *Hecho cuando:* tests de login y de permisos por rol OK.
- [A] 1.2 CRUD de productos (`/products`), barcode único por tenant. *Hecho cuando:* tests de integración OK.
- [B] 1.3 **Spike de escaneo (hacer primero en la etapa 1)** con `mobile_scanner` (formatos restringidos, linterna, permiso, ingreso manual). Probar en un celular real de gama baja, con poca luz y con productos reales del comercio objetivo (EAN-13, códigos dañados o pequeños). *Hecho cuando:* lee EAN-13 de forma confiable en esas condiciones; si no, se evalúa la alternativa (ajustar resolución/formatos o cambiar de librería) antes de seguir con 1.4.
- [B] 1.4 Catálogo local en Drift: lista y alta/edición escaneando el código. *Hecho cuando:* se crea y edita un producto sin internet.

### Etapa 2: Ventas
- [A] 2.1 `/sales` (crear y listar) y descuento de stock por delta. *Hecho cuando:* una venta repetida (mismo GUID) no se duplica.
- [A] 2.2 `/cash-close` (excluye ventas anuladas). *Hecho cuando:* totales por medio de pago correctos.
- [A] 2.5 `POST /sales/{id}/void` (solo Admin, repone stock, idempotente). *Hecho cuando:* anular dos veces no repone dos veces y un Cajero recibe 403.
- [B] 2.3 Flujo de venta local: escanear, carrito, búsqueda por nombre, precio libre, cobro con medio de pago, transacción Drift (venta + stock). *Hecho cuando:* se completa una venta offline (con y sin código de barras) y baja el stock.
- [B] 2.6 Anulación de venta en la app (solo Admin): repone stock local y se sincroniza. **Depende de 2.3.**
- [B] 2.4 Ticket compartible (PDF + share). *Hecho cuando:* se comparte por WhatsApp.
- **Integración [A+B]:** modelo y DTOs de producto/venta coinciden con el contrato.

### Etapa 3: Sync y login real
- [A] 3.1 `/sync/push` (idempotente por GUID, por lotes) y `/sync/pull?since=`. *Hecho cuando:* tests de idempotencia y de conflicto de productos (gana `UpdatedAt`) pasan.
- [B] 3.2 Login contra la API y almacenamiento seguro del token. **Depende de 1.1.**
- [B] 3.3 Cola de sync en la app (flag `Synced`, reintento con backoff). **Depende de 3.1.** *Hecho cuando:* una venta offline llega al servidor al volver la conexión.
- **Integración [A+B]:** sync end-to-end verificado con un dispositivo real.

### Etapa 4: Cierre y producción
- [B] 4.1 Historial, detalle de venta y pantalla de cierre de caja. **Depende de 2.2.**
- [A] 4.2 Deploy: Dockerfile, docker-compose, VPS, HTTPS (Caddy), migraciones, backups, CI/CD de la API. *Hecho cuando:* la API responde por HTTPS en un dominio.
- [B] 4.3 Distribución del piloto sin Google Play: APK firmado (`flutter build apk --release`) con keystore propio, URL de API por `--dart-define`, `versionCode` incremental, distribución por link o Firebase App Distribution, y CI (`flutter analyze` + `flutter test`). *Hecho cuando:* el APK se instala en un celular real y una versión nueva se instala encima sin perder datos. Guardar el keystore con backup (perderlo impide actualizar). Antes de actualizar, verificar que no haya ventas sin sincronizar.

- [A+B] 4.4 Alta manual de comercios (script o endpoint protegido) y checklist de decisiones previas al piloto (sección 12b). Prueba de **restauración** de backup.

### Etapa 5: Piloto
- [A+B] 5.1 Piloto en un comercio: soporte, corrección de errores y feedback. **Depende de 4.2, 4.3 y 4.4.** Medir los criterios de éxito de la sección 12b.

## 10b. División de tareas (2 programadores)
Se divide por capa; el contrato de API es la interfaz entre ambos.

- **Dev A: Backend + infraestructura (C#/.NET)**: se sugiere a quien tenga experiencia en .NET.
  - API: auth JWT, tenants, productos, ventas, cierre de caja, `/sync/push` y `/sync/pull`.
  - EF Core + PostgreSQL, migraciones, validaciones, tests de la API.
  - Dockerfile, docker-compose, VPS, HTTPS, backups, CI/CD de la API.
- **Dev B: App Flutter**
  - Proyecto, Riverpod, Drift, navegación, pantallas.
  - Escaneo con mobile_scanner, carrito y cobro, ticket.
  - Cola de sync del lado cliente, build de APK firmado y distribución a pilotos.

### Contrato primero (día 0, trabajo conjunto)
1. Acordar el contrato en OpenAPI/Swagger (endpoints, DTOs, errores, formato de fechas y dinero).
2. Dev A lo publica en `docs/openapi.yaml` y lo mantiene versionado.
3. Dev B desarrolla contra un **mock** (Prism o json-server) o contra la API local con datos de prueba, sin esperar al backend.
4. Cualquier cambio del contrato se hace por PR y lo revisan ambos.

### Orden de trabajo
Ver la sección 10 (lista unificada con dueño, dependencias y criterio de terminado).

### Reglas de trabajo
- Monorepo con carpetas `/api`, `/app` y `/docs` (o 2 repos si prefieren).
- Flujo diario de GitHub: ver sección 0.5.
- CI por carpeta: la API compila y testea; la app hace `flutter analyze` y `flutter test`.
- Issues de GitHub por etapa, con etiquetas `backend` / `app` / `contrato`.
- Convenciones comunes: ids GUID, fechas UTC en ISO 8601, dinero como entero en centavos, errores `{code, message}`.
- Daily corto o checkpoint al cerrar cada etapa, para validar el contrato.

### Puntos de integración
Marcados como **Integración [A+B]** al final de las etapas 2 y 3 en la sección 10.

## 11. Producción
- **API**: Docker (VPS, Railway o Azure) con HTTPS, migraciones EF Core y backups. Es lo único que se publica en un servidor.
- **App (MVP y piloto)**: **no se publica en Google Play**. Se instala un APK firmado directo en los celulares (por link o Firebase App Distribution). Para actualizar se instala el APK nuevo encima, con el mismo keystore y un `versionCode` mayor.
- **Reglas del APK directo**: guardar el keystore con backup; definir bien el `applicationId` desde el inicio (si luego se publica en Play, debe ser el mismo); confirmar que no haya ventas pendientes de sync antes de actualizar; avisar al comerciante del aviso de Play Protect y de activar "instalar apps de orígenes desconocidos".
- **Después del piloto (opcional)**: publicar en Google Play con testing cerrado (cuenta developer, 25 USD, AAB firmado) y Shorebird para parches OTA.

## 11b. Verificado con Context7 (docs actuales)
- **mobile_scanner**: `MobileScannerController` admite `formats` (restringir a EAN/UPC/Code128/QR), `detectionSpeed` (usar `noDuplicates`/`normal`), `detectionTimeoutMs`, `torchEnabled`, `autoStart`. Manejo de permiso de cámara vía `errorBuilder` / `MobileScannerErrorCode.permissionDenied`.
- **Drift**: dependencias `drift`, `drift_flutter`, `path_provider` y dev `drift_dev`, `build_runner`; abrir con `driftDatabase(name: ...)`; generar con `dart run build_runner build`; `transaction(() async {...})` con todos los awaits (usar para venta + descuento de stock).
- **Riverpod**: usar `Notifier`/`AsyncNotifier` (con `@riverpod` codegen recomendado); `StateNotifier` está desaconsejado.
- El agente implementador debe revisar las versiones exactas en pub.dev al crear el proyecto y consultar Context7 para API puntual.
- **Backend (ASP.NET Core, EF Core + Npgsql, Docker)**: esqueleto creado con .NET 10 LTS, Npgsql.EntityFrameworkCore.PostgreSQL 10.0.3, Serilog.AspNetCore 10.0.0 y Swashbuckle.AspNetCore 10.3.1. Docker Compose define PostgreSQL 17; la conexión al daemon Docker no se pudo verificar en el entorno local.
- **Mock OpenAPI**: el workspace implementa un mock HTTP mínimo en Node.js, sin dependencias externas, que cubre las rutas principales del contrato. Se evita añadir Prism al esqueleto por las vulnerabilidades detectadas en sus dependencias npm; el contrato sigue en `docs/openapi.yaml`.
- No verificado: precios de hosting (los valores del chat son aproximados).

## 12b. Decisiones previas al piloto (no se programan, hay que definirlas)
- **Modelo de negocio**: suscripción mensual por comercio o por dispositivo, prueba gratuita, cómo se da de alta un comercio (en el MVP: alta manual).
- **Legal**: términos y condiciones y política de privacidad (Google Play la exige; para el APK directo no es obligatoria, pero conviene tenerla en el piloto). Aclarar que el ticket del MVP no reemplaza un comprobante fiscal.
- **Distribución**: sin Google Play en el piloto. No hace falta cuenta de developer hasta decidir publicar.
- **Datos a definir**: `applicationId` de Android y nombre de la app, moneda e impuestos (si los precios incluyen IVA) y lista cerrada de medios de pago (efectivo, débito, crédito, transferencia, otro) para el contrato.
- **Soporte**: canal de atención (ej. WhatsApp), cómo reportan problemas y cómo se actualiza la app en los comercios.
- **Testing**: unitarios, integración de la API y pruebas manuales en dispositivos reales de gama baja y con poca luz.
- **Criterios de éxito del piloto**: cantidad de comercios (ej. 2-3), duración, y métricas: ventas por día, errores/crashes, tiempo por venta, escaneos fallidos, ventas sincronizadas sin pérdida, satisfacción del comerciante.
- **Migración de datos**: si el comercio ya tiene lista de productos, definir cómo cargarla (en MVP: carga escaneando; importación CSV en fase 2).
- **Backups**: diarios, con prueba de restauración antes del piloto.

## 12. Notas / riesgos
- Probar el escaneo en dispositivos reales de gama baja y con poca luz; permitir ingreso manual del código y linterna.
- Redondeo y moneda: usar `decimal` en backend y enteros (centavos) o `Decimal` en Dart.
- Diagramas (arquitectura, pantallas, flujo de venta, sync, modelo de datos) dibujados en Excalidraw en este chat.
