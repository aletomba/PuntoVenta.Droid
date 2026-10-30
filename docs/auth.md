# Autenticación (API)

Implementa `POST /auth/login` y `POST /auth/refresh` según `docs/openapi.yaml`.

## Configuración

| Clave | Variable de entorno | Descripción |
|---|---|---|
| `Jwt:SigningKey` | `Jwt__SigningKey` | **Obligatoria**, mínimo 32 bytes. La API no arranca sin ella. `appsettings.Development.json` trae una clave marcada `DEV-ONLY`; en producción definirla por variable de entorno. |
| `Jwt:Issuer` / `Jwt:Audience` | `Jwt__Issuer` / `Jwt__Audience` | Valores por defecto en `appsettings.json`. |
| `Jwt:AccessTokenMinutes` | | Vida del access token (15). |
| `Jwt:RefreshTokenDays` | | Vida del refresh token (30). |
| `Lockout:MaxFailedAttempts` / `Lockout:LockoutMinutes` | | Bloqueo tras 5 intentos fallidos por 15 minutos. |

## Comportamiento

- Roles: `Admin` y `Cajero`. Políticas `AdminOnly` y `AdminOrCajero` en `AuthPolicies`.
- El JWT lleva `sub`, `email`, `tenant_id` y `role`. El tenant de cada operación se toma siempre del claim `tenant_id` (`ClaimsPrincipal.GetTenantId()`).
- El email es único globalmente (el login no recibe tenant).
- Contraseñas con PBKDF2-HMAC-SHA256 (600 000 iteraciones, sal aleatoria).
- Refresh tokens: aleatorios de 48 bytes, se guardan solo como SHA-256 y se rotan en cada uso. Reutilizar un token ya rotado revoca todas las sesiones del usuario.
- Errores `{ "code", "message" }`: `invalid_credentials`, `account_locked`, `invalid_refresh_token`, `invalid_request` (400), `unauthorized` (401), `forbidden` (403).
- Los usuarios y comercios se dan de alta por fuera de la API (tarea 4.4); no hay endpoint de registro.

## Base de datos

Migración `InitialAuth`: `dotnet ef database update --project api/PuntoVenta.Api` con PostgreSQL en el puerto 5433 (`docker compose up -d postgres`).
