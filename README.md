# PuntoVenta.Droid

Monorepo para el MVP Android de punto de venta. La aplicación Flutter es offline-first; la API ASP.NET Core usa PostgreSQL. El contrato compartido está en [`docs/openapi.yaml`](docs/openapi.yaml) y el plan funcional en [`docs/plan.md`](docs/plan.md).

## Requisitos locales

- Flutter stable y Android SDK (aceptar licencias con `flutter doctor --android-licenses`).
- .NET SDK 10 LTS.
- Docker Desktop con Docker Compose para PostgreSQL.
- Node.js compatible con la versión instalada localmente.

## Ejecutar la app

```powershell
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4010
```

`10.0.2.2` apunta al host desde el emulador Android. Para un dispositivo físico, reemplazarlo por la dirección accesible del equipo que sirve el mock o la API.

Para habilitar el reporte a Sentry, configurar el DSN fuera del código:

```powershell
flutter run --dart-define=SENTRY_DSN=<DSN>
```

Sin `SENTRY_DSN`, el reporte remoto queda deshabilitado; no se envían eventos a un destino ficticio.

## Ejecutar API y PostgreSQL

Desde la raíz:

```powershell
docker compose up -d postgres
dotnet run --project api/PuntoVenta.Api
```

- Health check de proceso: `GET http://localhost:5039/health`.
- Readiness de PostgreSQL: `GET http://localhost:5039/health/ready`.
- Swagger UI: `/swagger` en entorno Development.

La cadena local de conexión de PostgreSQL se puede reemplazar mediante `ConnectionStrings__Default`. El contenedor expone PostgreSQL en el puerto `5433` del host para no chocar con una instalación local en `5432`. Las credenciales del `docker-compose.yml` son solo para desarrollo local.

## Mock del contrato

Desde la raíz del repositorio:

```powershell
npm install
npm run mock
```

El mock local sirve las rutas principales del contrato en `http://localhost:4010`. Por defecto solo escucha en `127.0.0.1`; el emulador Android accede al host con `10.0.2.2`. Para probar desde un teléfono, configurar `MOCK_HOST=0.0.0.0` y usarlo solo en una red de confianza.

## Validaciones

```powershell
cd app
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test

cd ..
dotnet build PuntoVenta.slnx
```

## Reglas de colaboración

Consultar [`AGENTS.md`](AGENTS.md) y seguir el flujo de issues y PRs descrito en [`docs/plan.md`](docs/plan.md).
