/*
  ¿Mostrar las cajas grises de carga (esqueleto)? Solo si la carga dura más de `demora` ms.
  Si la API responde rápido, no aparecen: así no parpadean (aparecer y desaparecer en 50 ms se ve peor que nada).
    const cargando = ref(true)
    const esqueleto = useEsqueleto(cargando)
    <div v-if="esqueleto">…cajas grises…</div>
*/
export function useEsqueleto(cargando: Ref<boolean>, demora = 250) {
  const mostrar = ref(false)
  let reloj: ReturnType<typeof setTimeout> | undefined
  watch(
    cargando,
    (c) => {
      clearTimeout(reloj)
      if (c) reloj = setTimeout(() => { mostrar.value = true }, demora)
      else mostrar.value = false
    },
    { immediate: true },
  )
  onBeforeUnmount(() => clearTimeout(reloj))
  return readonly(mostrar)
}
