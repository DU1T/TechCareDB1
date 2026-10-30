<script setup lang="ts">
/*
  Línea del taller: las órdenes abiertas repartidas por estado, en el orden en que avanza una orden.
  - La barra se llena de izquierda a derecha al aparecer; cada tramo mide lo que pesa ese estado.
  - Pasar el puntero (o el foco del teclado) por un tramo o por su leyenda resalta los dos.
  - Cada leyenda lleva a /ordenes ya filtrada por ese estado.
  Colores: un solo verde que se oscurece mientras la orden avanza; el amarillo marca la única
  etapa que no depende del taller (espera la respuesta del cliente).
*/
export type ResumenTaller = {
  recibidas: number
  enDiagnostico: number
  esperandoAutorizacion: number
  enReparacion: number
  listasParaEntregar: number
}
const props = defineProps<{ datos: ResumenTaller }>()

const TRAMOS: { clave: keyof ResumenTaller; estado: string; color: string }[] = [
  { clave: 'recibidas', estado: 'RECIBIDO', color: 'bg-placa-200' },
  { clave: 'enDiagnostico', estado: 'DIAGNOSTICO', color: 'bg-placa-300' },
  { clave: 'esperandoAutorizacion', estado: 'ESPERANDO_AUTORIZACION', color: 'bg-acento-400' },
  { clave: 'enReparacion', estado: 'REPARACION', color: 'bg-placa-500' },
  { clave: 'listasParaEntregar', estado: 'LISTO', color: 'bg-placa-700' },
]
const tramos = computed(() =>
  TRAMOS.map((t) => ({ ...t, n: props.datos[t.clave], texto: ESTADO_ORDEN[t.estado]?.texto ?? t.estado })),
)

const activo = ref<string | null>(null)
</script>

<template>
  <div>
    <!-- La barra es un atajo para el mouse; para teclado y lectores están los enlaces de la leyenda -->
    <div class="barrido flex h-11 gap-1 overflow-hidden rounded-lg" aria-hidden="true">
      <template v-for="t in tramos" :key="t.estado">
        <NuxtLink
          v-if="t.n > 0"
          :to="`/ordenes?estado=${t.estado}`"
          tabindex="-1"
          class="min-w-2 basis-0 transition-opacity duration-200"
          :class="[t.color, activo && activo !== t.estado ? 'opacity-35' : '']"
          :style="{ flexGrow: t.n }"
          @pointerenter="activo = t.estado"
          @pointerleave="activo = null"
        />
      </template>
    </div>

    <ul class="mt-4 grid grid-cols-2 gap-1 sm:grid-cols-5">
      <li v-for="(t, i) in tramos" :key="t.estado">
        <NuxtLink
          :to="`/ordenes?estado=${t.estado}`"
          class="flex h-full flex-col-reverse justify-end rounded-md px-2 py-2 transition-colors duration-200"
          :class="activo === t.estado ? 'bg-bruma-100' : 'hover:bg-bruma-100'"
          @pointerenter="activo = t.estado"
          @pointerleave="activo = null"
          @focus="activo = t.estado"
          @blur="activo = null"
        >
          <!-- En el código va primero el texto (así lo lee un lector de pantalla); en pantalla, el número
               arriba (flex-col-reverse), para que todas las cifras queden en la misma línea aunque el texto ocupe dos -->
          <span class="mt-1 flex items-start gap-1.5 text-sm leading-tight text-bruma-600">
            <span class="mt-0.5 size-2.5 shrink-0 rounded-sm" :class="t.color" />
            {{ t.texto }}
          </span>
          <span class="block text-2xl font-semibold tracking-tight">
            <ContadorAnimado :valor="t.n" :retraso="300 + i * 80" />
          </span>
        </NuxtLink>
      </li>
    </ul>
  </div>
</template>

<style scoped>
/* La barra se descubre de izquierda a derecha, como una barra de progreso que se llena */
.barrido {
  animation: barrido var(--dur-escena) var(--ease-llega) both;
  animation-delay: 350ms;
}
@keyframes barrido {
  from {
    clip-path: inset(0 100% 0 0 round 0.5rem);
  }
  to {
    clip-path: inset(0 0 0 0 round 0.5rem);
  }
}
</style>
