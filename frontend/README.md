# TechCare · Frontend (Nuxt 4)

Aplicación web de TechCare. Nunca habla con SQL Server: todo pasa por la API de B.

## Cómo correrlo

```powershell
cd C:\src\techcare\frontend
npm install
copy .env.example .env
npm run dev          # http://localhost:3000
```

Requiere Node 22.22.3 o superior (o 24.15+).

## Modo simulado y API real

Con `NUXT_PUBLIC_API_BASE=/api` (valor por defecto) la app usa la API falsa de `server/api`, que tiene la misma forma que la real. Verás la etiqueta **API simulada** arriba a la derecha.

Cuando B publique la suya, cambia en `.env`:

```text
NUXT_PUBLIC_API_BASE=http://localhost:5080/api
```

y reinicia `npm run dev`. No hay que tocar código.

Usuarios de prueba (modo simulado), contraseña `Demo2026!`: `recepcion1`, `tecnico1`, `bodega1`, `caja1`, `administrador1`.

## Contrato de login que espera la app

```text
POST /auth/login   { "username": "...", "password": "..." }
200 -> { "token": "...", "usuario": { "idUsuario": 4, "nombreCompleto": "...", "roles": ["CAJA"], "permisos": ["PAGO_REGISTRAR", "..."] } }
401 -> { "error": "mensaje legible" }
```

Los errores de negocio (409/422) deben venir como `{ "error": "mensaje del THROW" }`: la app lo muestra tal cual.

## Estructura

```text
app/
  app.vue                  UApp + layout + página
  app.config.ts            colores de Nuxt UI (primary, secondary, neutral)
  assets/css/main.css      paleta 60-30-10 y estilos globales
  layouts/default.vue      menú lateral + barra superior (sesión iniciada)
  layouts/blank.vue        sin menú (login)
  middleware/auth.global.ts  exige sesión y revisa el permiso de cada página
  stores/auth.ts           token, usuario y auth.puede('PERMISO')
  composables/useApi.ts    todas las llamadas a la API pasan por aquí
  utils/menu.ts            lista de módulos: menú e inicio salen de aquí
  utils/roles.ts           nombres legibles de los roles
  pages/                   una carpeta/archivo por ruta
server/api/                API simulada (solo desarrollo)
```

## Cómo agregar una pantalla

1. Crea `app/pages/clientes/index.vue` y declara su permiso y título:
   ```vue
   <script setup lang="ts">
   definePageMeta({ titulo: 'Clientes', permiso: 'CLIENTE_GESTIONAR' })
   </script>
   ```
2. En `app/utils/menu.ts`, cambia `listo: false` por `listo: true` en su ítem.
3. Para llamar a la API usa siempre `const api = useApi()`.

## Regla 60-30-10

| Parte | Escala | Dónde se usa |
| --- | --- | --- |
| 60 % | `bruma` (neutro) | fondo de página, tarjetas blancas, bordes, texto |
| 30 % | `placa` (verde de placa electrónica) | menú lateral, panel del login, botones normales, enlaces, foco |
| 10 % | `acento` (amarillo de multímetro) | la acción principal de cada pantalla y el ítem activo del menú |

- En cada pantalla hay **un solo** botón `color="secondary"` (Guardar, Registrar pago, Facturar). Todo lo demás usa el color por defecto.
- El amarillo se usa solo como relleno, nunca como texto sobre fondo claro (no se lee).
- Para cambiar la identidad de todo el sistema, edita las tres escalas en `app/assets/css/main.css`.
- Los íconos van empaquetados (sin internet). Si usas uno nuevo y no aparece, agrégalo a la lista `icon.clientBundle.icons` de `nuxt.config.ts`.
