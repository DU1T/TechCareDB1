<script setup lang="ts">
/*
  Dónde va la orden: Recepción → Diagnóstico → Reparación → Factura → Entrega.
  - hecha: ya ocurrió (círculo verde con ✓).
  - actual: la siguiente por hacer (anillo amarillo que late) y, debajo, el estado de la orden.
  - no aplica: se saltó porque una etapa posterior ya ocurrió (por ejemplo, el cliente rechazó la
    reparación y el equipo se entregó sin repararlo), o la orden se canceló. Se dice, en vez de "pendiente".
  - pendiente: todavía no llega.
  La barra se llena hasta la última etapa hecha; si la orden avanza (una acción del taller), sigue llenándose.
*/
const props = defineProps<{
  encabezado: Record<string, any>
  estadoTexto: string
}>()

const reducido = useReducedMotion()

const etapas = computed(() => {
  const x = props.encabezado
  const cancelada = x.estado === 'CANCELADO'
  const hechas = [true, !!x.fechaDiagnostico, !!x.finReparacion, !!x.numeroFactura, !!x.fechaEntrega]
  const ultimaHecha = hechas.lastIndexOf(true)
  const nombres = ['Recepción', 'Diagnóstico', 'Reparación', 'Factura', 'Entrega']
  return nombres.map((nombre, i) => {
    let tipo: 'hecha' | 'actual' | 'omitida' | 'pendiente' = 'pendiente'
    if (hechas[i]) tipo = 'hecha'
    else if (i < ultimaHecha || cancelada) tipo = 'omitida' // saltada, o ya no va a ocurrir porque se canceló
    else if (i === ultimaHecha + 1) tipo = 'actual'
    return { nombre, tipo }
  })
})
const avance = computed(() => etapas.value.map((e) => e.tipo).lastIndexOf('hecha') / (etapas.value.length - 1))
</script>

<template>
  <ol class="relative grid grid-cols-5" aria-label="Etapas de la orden">
    <!-- Riel y relleno: van detrás de los círculos, de centro a centro (10% a 90% del ancho) -->
    <span class="absolute left-[10%] right-[10%] top-4 h-0.5 -translate-y-1/2 rounded bg-bruma-200" aria-hidden="true" />
    <Motion
      class="absolute left-[10%] right-[10%] top-4 h-0.5 origin-left -translate-y-1/2 rounded bg-placa-600"
      aria-hidden="true"
      :initial="reducido ? false : { scaleX: 0 }"
      :animate="{ scaleX: avance }"
      :transition="{ duration: DURACION.escena, ease: CURVA.llega, delay: 0.15 }"
    />

    <li v-for="(et, i) in etapas" :key="et.nombre" class="relative flex flex-col items-center text-center">
      <Motion
        class="relative grid size-8 place-items-center rounded-full border-2 text-sm"
        :class="{
          'border-placa-600 bg-placa-600 text-white': et.tipo === 'hecha',
          'border-acento-500 bg-white text-bruma-900 anillo-actual': et.tipo === 'actual',
          'border-dashed border-bruma-300 bg-bruma-50 text-bruma-400': et.tipo === 'omitida',
          'border-bruma-300 bg-white text-bruma-400': et.tipo === 'pendiente',
        }"
        :initial="reducido ? false : { scale: 0.6, opacity: 0 }"
        :animate="{ scale: 1, opacity: 1 }"
        :transition="{ ...RESORTE, delay: 0.15 + i * (DURACION.escena / 5) }"
      >
        <UIcon v-if="et.tipo === 'hecha'" name="i-lucide-check" class="size-4" />
        <span v-else-if="et.tipo === 'omitida'" aria-hidden="true">–</span>
        <span v-else class="cifras">{{ i + 1 }}</span>
      </Motion>
      <span class="mt-2 text-xs font-medium sm:text-sm" :class="et.tipo === 'hecha' || et.tipo === 'actual' ? 'text-bruma-900' : 'text-bruma-500'">
        {{ et.nombre }}
      </span>
      <span v-if="et.tipo === 'actual'" class="mt-0.5 text-xs text-bruma-600">{{ estadoTexto }}</span>
      <span v-else-if="et.tipo === 'omitida'" class="mt-0.5 text-xs text-bruma-500">No aplica</span>
      <span class="sr-only">
        {{ et.tipo === 'hecha' ? 'hecha' : et.tipo === 'actual' ? 'en curso' : et.tipo === 'omitida' ? 'no aplica' : 'pendiente' }}
      </span>
    </li>
  </ol>
</template>

<style scoped>
/* La etapa en curso "late": un anillo amarillo que se expande y se desvanece, cada 2 segundos */
.anillo-actual::after {
  content: '';
  position: absolute;
  inset: -2px;
  border-radius: 9999px;
  border: 2px solid var(--color-acento-500);
  animation: latido 2000ms var(--ease-llega) infinite;
}
@keyframes latido {
  from {
    opacity: 0.8;
    transform: scale(1);
  }
  to {
    opacity: 0;
    transform: scale(1.7);
  }
}
@media (prefers-reduced-motion: reduce) {
  .anillo-actual::after {
    display: none;
  }
}
</style>
