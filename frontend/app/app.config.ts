/*
  Mapa de colores de Nuxt UI sobre la regla 60-30-10 (las escalas están en main.css):

    neutral   -> bruma   60 %  fondos, tarjetas, bordes, texto
    primary   -> placa   30 %  marca: botones normales, enlaces, foco, menú lateral
    secondary -> acento  10 %  SOLO la acción principal de cada pantalla

  Regla práctica: en cada pantalla hay un solo botón con color="secondary"
  (Guardar, Registrar pago, Facturar...). Todo lo demás usa el color por defecto.
*/
export default defineAppConfig({
  ui: {
    colors: {
      primary: 'placa',
      secondary: 'acento',
      neutral: 'bruma',
    },
  },
})
