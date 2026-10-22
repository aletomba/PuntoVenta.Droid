---
name: contrato-openapi
description: 'Cambiar el contrato docs/openapi.yaml y mantener sincronizados el mock (tools/mock-server.mjs), la API y la app. Usar siempre que haya que agregar, modificar o eliminar endpoints, DTOs o códigos de error.'
---

# Cambios al contrato OpenAPI

`docs/openapi.yaml` es la fuente de verdad entre `/api` y `/app`. No se cambia como parte de una tarea de implementación.

## Regla de oro
Un cambio de contrato = **un PR aparte**, con etiqueta `contrato`, que revisan ambos desarrolladores **antes** de implementar. El código que depende del cambio se hace en otros PR, después del merge.

## Pasos
1. **Abrir un issue** con etiqueta `contrato` que explique qué cambia y por qué. Si no queda claro el alcance, preguntar; no inventar comportamiento.
2. **Rama:** `chore/contrato-<descripcion>` o `feature/contrato-<tarea>-<descripcion>`.
3. **Editar `docs/openapi.yaml`** respetando:
   - ids GUID (`type: string, format: uuid`);
   - fechas UTC ISO 8601 (`format: date-time`);
   - dinero como entero en centavos (`type: integer`, descripción “centavos”);
   - errores con el esquema `{ code, message }` y la respuesta `components/responses/Error`;
   - `operationId` único y descriptivo, `tags` y `security` en cada operación;
   - sin romper compatibilidad hacia atrás cuando ya hay clientes; si es inevitable, subir `info.version` y documentarlo.
4. **Actualizar el mock** `tools/mock-server.mjs` para que responda con los mismos DTOs y códigos. Probarlo:
   ```powershell
   npm run mock
   curl http://localhost:4010/<ruta>
   ```
5. **Validar que el YAML es correcto** (por ejemplo con un linter de OpenAPI o cargando el archivo con un parser YAML) y que no quedaron `$ref` rotos.
6. **Abrir el PR** con etiqueta `contrato`, lista de cambios (endpoints/DTOs agregados, modificados y eliminados) y el impacto en `/api` y en `/app`.
7. **Pedir revisión a ambos.** No mergear hasta que apruebe quien consuma el cambio. El dueño puede mergear sus propios PR, pero solo después de que el otro lado lo haya revisado.
8. **Después del merge:** crear o actualizar los issues de implementación (`backend` y `app`) y quitar `bloqueado` de los que esperaban el contrato.

## Qué no hacer
- No editar el contrato desde una rama de implementación.
- No cambiar el mock sin cambiar el contrato, ni al revés.
- No implementar endpoints o clientes sobre un contrato todavía sin aprobar.
