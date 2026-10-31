<script setup lang="ts">
/*
  Recorrido de la orden: el historial de estados (HistorialEstadoOrden) como línea de tiempo.
  - El eje se dibuja de arriba hacia abajo y cada cambio aparece cuando el eje llega a él.
  - Cada cambio dice a qué estado pasó, cuándo, quién lo hizo, su observación y cuánto tardó desde el anterior.
  - Arriba: cuánto duró todo (o cuánto lleva abierta, si todavía no termina).
  - Si la orden sigue abierta, el último punto late: "aquí va ahora".
  Cuando una acción del taller agrega un cambio, solo el nuevo hace su entrada (los demás ya están).
*/
type Cambio = { fechaCambio: string; estadoAnterior: string | null; estadoNuevo: string; usuario: string; observacion: string | null }
const props = defineProps<{ historial: Cambio[]; estadoActual: string }>()

const terminada = computed(() => ['ENTREGADO', 'CANCELADO'].includes(props.estadoActual))
const cambios = computed(() =>
  [...props.historial]
    .sort((a, b) => +new Date(a.fechaCambio) - +new Date(b.fechaCambio))
    .map((c, i, todos) => ({
      ...c,
      clave: `${c.fechaCambio}-${c.estadoNuevo}`,
      texto: ESTADO_ORDEN[c.estadoNuevo]?.texto ?? c.estadoNuevo,
      color: COLOR_ESTADO_ORDEN[c.estadoNuevo] ?? 'bg-bruma-300',
      espera: i > 0 ? duracion(+new Date(c.fechaCambio) - +new Date(todos[i - 1]!.fechaCambio)) : '',
    })),
)
const total = computed(() => {
  const c = cambios.value
  if (!c.length) return ''
  const inicio = +new Date(c[0]!.fechaCambio)
  return terminada.value
    ? `${duracion(+new Date(c[c.length - 1]!.fechaCambio) - inicio)} de principio a fin`
    : `abierta hace ${duracion(Date.now() - inicio)}`
})

// El eje tarda en dibujarse según cuántos cambios hay; cada cambio aparece cuando el eje pasa por él
const PASO = 140 // ms entre un cambio y el siguiente

// Terminada la entrada inicial, un cambio nuevo (por una acción del taller) aparece enseguida, sin esperar turno
const montada = ref(false)
let reloj: ReturnType<typeof setTimeout> | undefined
onMounted(() => { reloj = setTimeout(() => { montada.value = true }, 200 + cambios.value.length * PASO + 600) })
onBeforeUnmount(() => clearTimeout(reloj))
</script>

<template>
  <section class="rounded-xl border border-bruma-200 bg-white p-5" aria-labelledby="titulo-recorrido">
    <div class="flex items-baseline justify-between gap-3">
      <h3 id="titulo-recorrido" class="font-semibold">Recorrido</h3>
      <p class="text-sm text-bruma-600">{{ total }}</p>
    </div>

    <p v-if="!cambios.length" class="mt-3 text-sm text-bruma-500">Sin cambios de estado.</p>

    <ol v-else class="relative mt-4" :class="{ 'ya-montada': montada }" :style="{ '--n': cambios.length, '--paso': `${PASO}ms` }">
      <!-- Eje: de la mitad del primer punto a la mitad del último -->
      <span class="eje absolute bottom-3 left-[7px] top-3 w-0.5 rounded bg-bruma-200" aria-hidden="true" />

      <li
        v-for="(c, i) in cambios"
        :key="c.clave"
        class="hito relative grid grid-cols-[1rem_minmax(0,1fr)] gap-3 pb-5 last:pb-0"
        :style="{ '--i': i }"
      >
        <span
          class="relative z-10 mt-1 size-4 rounded-full ring-4 ring-white"
          :class="[c.color, !terminada && i === cambios.length - 1 ? 'punto-actual' : '']"
          aria-hidden="true"
        />
        <div class="min-w-0">
          <div class="flex flex-wrap items-baseline gap-x-2">
            <span class="font-medium">{{ c.texto }}</span>
            <span v-if="c.espera" class="cifras rounded bg-bruma-100 px-1.5 text-xs text-bruma-600">+{{ c.espera }}</span>
          </div>
          <p class="cifras text-sm text-bruma-600">{{ fechaYHora(c.fechaCambio) }} · {{ c.usuario }}</p>
          <p v-if="c.observacion" class="mt-0.5 text-sm text-bruma-700">{{ c.observacion }}</p>
        </div>
      </li>
    </ol>
  </section>
</template>

<style scoped>
/* El eje crece hacia abajo en el mismo tiempo que tardan en aparecer todos los cambios */
.eje {
  transform-origin: top;
  animation: eje-crece calc(var(--n) * var(--paso)) linear both;
  animation-delay: 200ms;
}
@keyframes eje-crece {
  from {
    transform: scaleY(0);
  }
}

/* Cada cambio aparece (y se desliza 8px desde la izquierda) cuando el eje llega a su altura */
.hito {
  animation: hito-entra var(--dur-lenta) var(--ease-llega) both;
  animation-delay: calc(200ms + var(--i) * var(--paso));
}
@keyframes hito-entra {
  from {
    opacity: 0;
    transform: translateX(-8px);
  }
}
.ya-montada .hito {
  animation-delay: 0ms;
}

/* La orden sigue abierta: el último punto late */
.punto-actual::after {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: 9999px;
  background: inherit;
  animation: latido 2000ms var(--ease-llega) infinite;
}
@keyframes latido {
  from {
    opacity: 0.7;
    transform: scale(1);
  }
  to {
    opacity: 0;
    transform: scale(2.4);
  }
}
@media (prefers-reduced-motion: reduce) {
  .punto-actual::after {
    display: none;
  }
}
</style>
