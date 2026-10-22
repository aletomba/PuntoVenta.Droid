---
name: git-flow
description: 'Flujo de GitHub de PuntoVenta.Droid: elegir issue, crear rama, commits, PR con la plantilla del repo, CI y merge. Usar al empezar o terminar cualquier tarea, al abrir un PR o al mergear.'
---

# Git flow de PuntoVenta.Droid

Repo: `aletomba/PuntoVenta.Droid`. `main` exige PR. Una tarea = un issue = una rama = un PR.

## Empezar una tarea
1. Elegir un issue de la etiqueta propia (`app` o `backend`) cuyas dependencias estén cerradas. Asignarlo: `gh issue edit <N> --add-assignee @me`.
2. Actualizar `main` y crear la rama:
   ```powershell
   git checkout main; git pull
   git checkout -b feature/<app|api>-<tarea>-<descripcion>
   ```
   Ejemplos: `feature/app-1.3-escaner`, `feature/api-1.2-crud-productos`. Correcciones: `fix/<ambito>-<descripcion>`. Mantenimiento: `chore/<descripcion>`.
3. Si la tarea depende de algo del otro rol, poner la etiqueta `bloqueado`, comentar qué falta y pasar a otra tarea o al mock. No inventar comportamiento.

## Durante la tarea
- Commits chicos con formato `tipo(ámbito): descripción`. Tipos: `feat`, `fix`, `docs`, `test`, `chore`.
- Si el commit lo crea un agente, agregar al final del mensaje el trailer `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.
- Editar solo la carpeta del propio rol (ver `AGENTS.md`).
- Verificar en local antes de subir:
  - `/app`: `flutter analyze` y `flutter test`.
  - `/api`: `dotnet build PuntoVenta.slnx` y `dotnet test` si hay tests.

## Abrir el PR
1. Leer `.github/pull_request_template.md` y respetar sus encabezados y checklist.
2. Poner `Closes #<issue>`, qué cambia y cómo se probó, con el comando exacto y su resultado. Capturas si cambia la UI.
3. Crear el PR hacia `main`:
   ```powershell
   git push -u origin <rama>
   gh pr create --base main --title "<tipo(ámbito): descripción>" --body-file <archivo>
   ```
4. Cambios en `docs/openapi.yaml`: PR aparte con etiqueta `contrato` (usar la skill `contrato-openapi`).
5. Esperar el CI: `gh pr checks <N> --watch`. Debe estar en verde.

## Revisión y merge
- Revisión cruzada: la aprueba el otro dev o el dueño.
- `aletomba` (dueño) puede mergear sus propios PR porque `enforce_admins` está desactivado. Cualquier otra cuenta necesita 1 aprobación.
- Mergear siempre por REST con squash. No usar `gh pr merge` (puede fallar por timeouts de GraphQL):
  ```powershell
  gh api repos/aletomba/PuntoVenta.Droid/pulls/<N>/merge --method PUT --field merge_method=squash --field commit_title="<título> (#<N>)"
  ```
- Después: `git checkout main; git pull`, borrar la rama remota (`git push origin --delete <rama>`) y la local (`git branch -D <rama>`; tras un squash `-d` falla, es normal).
- El issue se cierra solo por `Closes #N`. Quitar `bloqueado` si lo tenía.

## Reglas
- Nunca `git push --force` ni `git reset --hard`.
- No subir secretos. El repo es público.
- Si hay cambios sin commitear al cambiar de rama, avisar antes de continuar.
- Terminar siempre con el repo en `main` y sin ramas huérfanas.
