---
name: dotnet-api-endpoint
description: 'Implementar o modificar endpoints de la API ASP.NET Core en /api a partir de docs/openapi.yaml (EF Core, PostgreSQL, JWT, multi-tenant, errores {code,message}). Usar para tareas [A]: auth, productos, ventas, cierre de caja y sincronización.'
---

# Endpoint de la API en /api

Solo se edita `/api` (y `docs/` y `.github/` por PR). Nunca `/app`.

## Antes de empezar
1. Leer el issue, `docs/plan.md` y la operación en `docs/openapi.yaml` (ruta, DTOs, códigos de respuesta). El contrato manda: si hay que cambiarlo, parar y usar la skill `contrato-openapi`.
2. Consultar la documentación vigente de ASP.NET Core, EF Core y Npgsql (Context7) para APIs puntuales. Fijar versiones al agregar paquetes.
3. Para criterios generales de HTTP y OpenAPI se puede apoyar en la skill `dotnet-webapi`.

## Convenciones del contrato
- Ids GUID; fechas UTC ISO 8601 (`DateTime` con `Kind=Utc`, columnas `timestamptz`).
- **Dinero como enteros en centavos** (`long`); nunca `decimal` ni `double` en DTOs.
- Errores siempre `{ "code": "...", "message": "..." }` con el código HTTP del contrato. Un `code` estable en mayúsculas con guion bajo (`INVALID_CREDENTIALS`, `PRODUCT_NOT_FOUND`). Nunca exponer excepciones ni trazas.
- Nombres y forma de los DTOs idénticos a `docs/openapi.yaml`.

## Estructura actual
```
api/PuntoVenta.Api/
  Program.cs          servicios, Swagger, Serilog, health checks
  Data/AppDbContext.cs
  Health/PostgresHealthCheck.cs
```
Agregar por funcionalidad: `Controllers/`, `Contracts/` (DTOs), `Domain/` (entidades), `Services/`. Los controladores solo traducen HTTP; la lógica va en servicios; el acceso a datos en `AppDbContext`.

## Reglas de negocio que no se negocian
- **Multi-tenant:** cada entidad de negocio lleva `TenantId`. Toda consulta filtra por el tenant del token (filtro global en EF o filtro explícito). Un usuario jamás ve datos de otro comercio. El tenant sale del JWT, nunca del cuerpo ni de la URL.
- **Roles:** autorizar con `[Authorize(Roles = ...)]` según el plan.
- **Idempotencia:** crear venta, anular venta y `sync/push` reciben un id del cliente. Reintentar con el mismo id devuelve el mismo resultado y no duplica.
- **Ventas:** guardar precio y total en centavos al momento de la venta; no recalcular desde el catálogo. Anular no borra: cambia estado y registra fecha y usuario.
- **Validación:** validar todo dato de entrada (rangos, longitudes, importes ≥ 0). Consultas siempre parametrizadas por EF; nada de SQL concatenado.
- **Seguridad:** JWT con secreto desde configuración o variable de entorno, no en el repositorio (el repo es público). Hash de contraseñas con un algoritmo adaptativo. No registrar contraseñas ni tokens en Serilog.

## Cambios de esquema
```powershell
dotnet ef migrations add <Nombre> --project api/PuntoVenta.Api
```
Revisar el SQL generado. Una migración por tarea. Migraciones que ya llegaron a `main` no se editan: se agrega otra.

## Verificación
```powershell
dotnet build PuntoVenta.slnx
dotnet test PuntoVenta.slnx      # si hay proyecto de pruebas
docker compose up -d postgres    # PostgreSQL en el puerto 5433 del host
dotnet run --project api/PuntoVenta.Api/PuntoVenta.Api.csproj
```
- `GET /health` y `GET /health/ready` deben responder `Healthy`.
- Probar el endpoint nuevo con el archivo `.http` o Swagger, tanto el camino feliz como los errores del contrato (400, 401, 403, 404, 409).
- Agregar pruebas de integración para reglas de tenant e idempotencia.
- Detener el contenedor al terminar (`docker compose down`).

## Cierre
Reportar en el PR cada comando con su resultado. Si algo no se pudo ejecutar, decirlo explícitamente.
