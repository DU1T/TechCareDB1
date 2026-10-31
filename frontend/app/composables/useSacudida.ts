/*
  Formulario que "dice no": se sacude un instante y, si hay un campo con error, el foco va al primero.
    const { alcance, sacudir } = useSacudida()
    <form ref="alcance" …>
    if (hayErrores) { sacudir(); return }          // validación previa: sacude y lleva el foco al campo
    catch { sacudir(false) }                         // la API rechazó: sacude, sin mover el foco
  Sin foco al campo, un lector de pantalla no se entera de que algo falló; sin la sacudida, quien mira no lo nota.
  Con "reducir movimiento" no se sacude (el foco sí se mueve). Solo usa transform.
  Usa una referencia normal de Vue y la animación del navegador (element.animate), sin depender de motion-v.
*/
export function useSacudida() {
  const reducido = useReducedMotion()
  const alcance = ref<HTMLElement | null>(null)

  async function sacudir(irAlError = true) {
    await nextTick() // para que el error ya esté dibujado (aria-invalid) antes de buscarlo
    const el = alcance.value
    if (!el) return
    if (irAlError) el.querySelector<HTMLElement>('[aria-invalid="true"]')?.focus()
    if (reducido.value) return
    el.animate(
      [0, -8, 7, -5, 3, 0].map((x) => ({ transform: `translateX(${x}px)` })),
      { duration: 380, easing: 'ease-out' },
    )
  }

  return { alcance, sacudir }
}
