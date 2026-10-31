/*
  Filas que se reacomodan con animación cuando cambia la lista (filtrar, buscar, recargar):
  - la fila que sigue en la lista se desliza desde donde estaba hasta su lugar nuevo (si estaba cerca);
  - la que entra aparece (sube 6px mientras aparece), en cascada corta.
  Técnica FLIP: se mide dónde estaba cada fila ANTES de que Vue cambie la tabla, se mide DESPUÉS
  y se anima la diferencia. Cada fila se reconoce por el texto de su primera celda (p. ej. "OS-000042").

    const tabla = ref<HTMLElement | null>(null)
    useReacomodo(tabla, () => visibles.value)
    <div ref="tabla"><UTable :data="visibles" … /></div>

  Con "reducir movimiento" no anima. Solo usa transform y opacity.
*/
export function useReacomodo(
  raiz: Ref<HTMLElement | null>,
  fuente: WatchSource,
  clave: (fila: HTMLTableRowElement) => string = (fila) => fila.cells[0]?.textContent?.trim() ?? '',
) {
  const reducido = useReducedMotion()
  let antes = new Map<string, number>()
  const filas = () => [...(raiz.value?.querySelectorAll<HTMLTableRowElement>('tbody tr') ?? [])]

  // Antes de que Vue actualice la tabla: dónde está cada fila
  watch(fuente, () => {
    antes = reducido.value ? new Map() : new Map(filas().map((f) => [clave(f), f.getBoundingClientRect().top]))
  }, { flush: 'pre' })

  // Después: animar la diferencia
  watch(fuente, () => {
    if (reducido.value || !antes.size) return
    let nuevas = 0
    for (const f of filas()) {
      const k = clave(f)
      const y0 = antes.get(k)
      // Una fila que venía de lejos (más de 240px) no cruza la tabla volando: aparece en su lugar como nueva
      if (y0 === undefined || Math.abs(y0 - f.getBoundingClientRect().top) > 240) {
        f.animate(
          [{ opacity: 0, transform: 'translateY(6px)' }, { opacity: 1, transform: 'none' }],
          { duration: 250, delay: Math.min(nuevas++, 8) * 25, easing: 'cubic-bezier(0.2, 0.8, 0.2, 1)', fill: 'backwards' },
        )
        continue
      }
      const dy = y0 - f.getBoundingClientRect().top
      if (Math.abs(dy) > 1) {
        f.animate([{ transform: `translateY(${dy}px)` }, { transform: 'none' }], { duration: 320, easing: 'cubic-bezier(0.2, 0.8, 0.2, 1)' })
      }
    }
  }, { flush: 'post' })
}
