<script setup lang="ts">
/*
  Panel de marca del login: una escena corta que cuenta qué hace el sistema.
  - Las pistas de circuito se dibujan solas y por algunas corre "corriente" (amarilla).
  - La etiqueta de servicio cuelga de un hilo, se balancea y recorre los estados de una orden.
  - fase 'leyendo': un escáner pasa por el código de barras (mientras la API responde).
  - fase 'listo': la etiqueta recibe el sello "Autorizado" y los contactos del circuito se encienden.
  Es decorativo (aria-hidden): toda la información útil está en el formulario.
*/
const props = defineProps<{ fase: 'espera' | 'leyendo' | 'listo' }>()

const reducido = useReducedMotion()

// La etiqueta recorre los estados de una orden y se queda en el último
const ESTADOS = ['Recibido', 'En diagnóstico', 'En reparación', 'Listo para entregar']
const paso = ref(0)
let espera: ReturnType<typeof setTimeout> | undefined
let reloj: ReturnType<typeof setInterval> | undefined
onMounted(() => {
  if (reducido.value) {
    paso.value = ESTADOS.length - 1
    return
  }
  espera = setTimeout(() => {
    reloj = setInterval(() => {
      paso.value++
      if (paso.value >= ESTADOS.length - 1) clearInterval(reloj)
    }, 900)
  }, 1200)
})
onBeforeUnmount(() => {
  clearTimeout(espera)
  clearInterval(reloj)
})
watch(() => props.fase, (f) => { if (f === 'listo') paso.value = ESTADOS.length - 1 })

// La etiqueta se inclina un poco hacia el puntero (con resorte, para que no tiemble)
const giroX = useSpring(0, { stiffness: 120, damping: 18 })
const giroY = useSpring(0, { stiffness: 120, damping: 18 })
function alMover(e: PointerEvent) {
  if (reducido.value) return
  const r = (e.currentTarget as HTMLElement).getBoundingClientRect()
  giroY.set(((e.clientX - r.left) / r.width - 0.5) * 12)
  giroX.set(-((e.clientY - r.top) / r.height - 0.5) * 10)
}
function alSalir() {
  giroX.set(0)
  giroY.set(0)
}

// Pistas en un lienzo de 800 × 900 (se recorta para llenar el panel). Codos a 45°, como en una placa real.
// contacto: el punto donde termina la pista dentro del panel; pulso: si por ella corre "corriente".
// La franja de abajo a la izquierda queda libre: ahí va el texto del panel.
const PISTAS = [
  { d: 'M0 140 H220 L270 190 H420', contacto: [420, 190], pulso: true },
  { d: 'M800 90 H640 L590 140 V230', contacto: [590, 230], pulso: false },
  { d: 'M0 330 H110 L160 380 V560 L210 610 H260', contacto: [260, 610], pulso: true },
  { d: 'M800 360 H690 L640 410 V520', contacto: [640, 520], pulso: true },
  { d: 'M800 680 H620 L570 730 V900', contacto: null, pulso: false },
  { d: 'M360 0 V50 L400 90 H560', contacto: [560, 90], pulso: true },
  { d: 'M0 600 H70 L120 650 V740', contacto: [120, 740], pulso: false },
  { d: 'M800 790 H700 L660 750 H600', contacto: [600, 750], pulso: true },
]
</script>

<template>
  <section
    class="relative hidden overflow-hidden bg-placa-900 p-12 text-placa-50 lg:flex lg:flex-col lg:justify-between"
    aria-hidden="true"
    @pointermove="alMover"
    @pointerleave="alSalir"
  >
    <svg
      class="circuito pointer-events-none absolute inset-0 size-full"
      :class="{ 'circuito-listo': fase === 'listo' }"
      viewBox="0 0 800 900"
      preserveAspectRatio="xMidYMid slice"
    >
      <g v-for="(p, i) in PISTAS" :key="i" :style="{ '--i': i }">
        <path class="pista" :d="p.d" pathLength="1" />
        <path v-if="p.pulso" class="pulso" :d="p.d" pathLength="1" />
        <circle v-if="p.contacto" class="contacto" :cx="p.contacto[0]" :cy="p.contacto[1]" r="7" />
      </g>
    </svg>

    <div class="relative flex items-center gap-2.5">
      <span class="grid size-8 place-items-center rounded-md bg-acento-500 font-bold text-bruma-950">T</span>
      <span class="text-xl font-semibold tracking-tight text-white">TechCare</span>
    </div>

    <!-- La etiqueta gira desde su ojal (50% horizontal, 1rem desde arriba), como si colgara de un gancho.
         :initial="false" con reducir movimiento: aparece ya en su lugar (motion-v conservaba la demora) -->
    <div class="relative mx-auto w-full max-w-sm">
      <Motion
        :style="{ transformOrigin: '50% 1rem' }"
        :initial="reducido ? false : { opacity: 0, y: -70, rotate: -16 }"
        :animate="{ opacity: 1, y: 0, rotate: -2 }"
        :transition="{ ...RESORTE_SUAVE, delay: 0.35, opacity: { duration: DURACION.rapida, delay: 0.35 } }"
      >
        <span class="absolute bottom-[calc(100%-1rem)] left-1/2 h-[60vh] w-px -translate-x-1/2 bg-linear-to-t from-placa-200/70 to-transparent" />

        <Motion
          :style="{ rotateX: giroX, rotateY: giroY, transformPerspective: 900 }"
          class="relative overflow-hidden rounded-xl bg-bruma-50 text-bruma-900 shadow-2xl shadow-placa-950/50"
        >
          <div class="relative bg-acento-500 px-6 pb-4 pt-7 text-bruma-950">
            <span class="absolute left-1/2 top-2.5 size-3 -translate-x-1/2 rounded-full bg-placa-900" />
            <p class="text-sm font-medium">Orden de servicio</p>
            <p class="cifras mt-0.5 text-3xl font-bold tracking-tight">OS-000142</p>
          </div>

          <div class="space-y-3 px-6 py-5">
            <div>
              <p class="text-xs text-bruma-500">Equipo</p>
              <p class="font-medium">Laptop 15 pulgadas, no enciende</p>
            </div>
            <div>
              <p class="text-xs text-bruma-500">Estado</p>
              <div class="relative h-6 overflow-hidden">
                <Transition name="estado">
                  <p :key="paso" class="absolute inset-x-0 font-medium">{{ ESTADOS[paso] }}</p>
                </Transition>
              </div>
              <div class="mt-2 grid grid-cols-4 gap-1">
                <span v-for="(e, i) in ESTADOS" :key="e" class="h-1 overflow-hidden rounded-full bg-bruma-200">
                  <span
                    class="block h-full origin-left bg-placa-500 transition-transform duration-500 ease-llega"
                    :class="i <= paso ? 'scale-x-100' : 'scale-x-0'"
                  />
                </span>
              </div>
            </div>
          </div>

          <div class="mx-4 border-t-2 border-dashed border-bruma-300" />
          <div class="relative mx-6 my-5 h-10 overflow-hidden">
            <div class="codigo-barras h-full opacity-90" />
            <span v-if="fase === 'leyendo'" class="escaner" />
          </div>

          <AnimatePresence>
            <Motion
              v-if="fase === 'listo'"
              class="absolute bottom-5 right-6 rounded-md border-[3px] border-placa-600 bg-bruma-50/85 px-3 py-1 text-lg font-bold uppercase tracking-widest text-placa-700"
              :initial="reducido ? false : { opacity: 0, scale: 1.9, rotate: -22 }"
              :animate="{ opacity: 1, scale: 1, rotate: -10 }"
              :transition="{ type: 'spring', stiffness: 520, damping: 24 }"
            >
              Autorizado
            </Motion>
          </AnimatePresence>
        </Motion>
      </Motion>
    </div>

    <p class="entra relative max-w-sm text-placa-200" style="--i: 12">
      Recepción, taller, bodega y caja trabajan sobre la misma orden.
    </p>
  </section>
</template>

<style scoped>
/* Pistas: se dibujan de punta a punta (pathLength=1 hace que todas midan "1", larguen o no) */
.pista {
  fill: none;
  stroke: var(--color-placa-700);
  stroke-width: 3;
  stroke-linecap: round;
  stroke-linejoin: round;
  stroke-dasharray: 1;
  stroke-dashoffset: 1;
  animation: trazar 1100ms var(--ease-llega) both;
  animation-delay: calc(var(--i) * 80ms);
}
@keyframes trazar {
  to {
    stroke-dashoffset: 0;
  }
}

/* Corriente: un trazo corto que recorre la pista a velocidad constante (lineal), sin fin.
   El hueco (1) mide lo mismo que la pista: así el trazo nunca se repite en la otra punta */
.pulso {
  fill: none;
  stroke: var(--color-acento-500);
  stroke-width: 3;
  stroke-linecap: round;
  stroke-dasharray: 0.05 1;
  opacity: 0.55;
  animation: recorrer 3200ms linear infinite both;
  animation-delay: calc(1400ms + var(--i) * 450ms);
  transition: opacity var(--dur-lenta);
}
@keyframes recorrer {
  from {
    stroke-dashoffset: 0.05;
  }
  to {
    stroke-dashoffset: -1;
  }
}

/* Contactos: aparecen cuando la pista llega a ellos */
.contacto {
  fill: var(--color-placa-900);
  stroke: var(--color-placa-600);
  stroke-width: 3;
  transform-box: fill-box;
  transform-origin: center;
  animation: contacto-aparece 300ms var(--ease-resorte) both;
  animation-delay: calc(var(--i) * 80ms + 1000ms);
  transition:
    fill var(--dur-lenta),
    stroke var(--dur-lenta);
}
@keyframes contacto-aparece {
  from {
    opacity: 0;
    transform: scale(0);
  }
}

/* Sesión iniciada: el circuito "enciende" */
.circuito-listo .contacto {
  fill: var(--color-acento-500);
  stroke: var(--color-acento-300);
}
.circuito-listo .pulso {
  opacity: 1;
}

/* Escáner: una línea roja que barre el código de barras de ida y vuelta.
   El span ocupa todo el ancho y la línea es su borde izquierdo: moverlo 100% la lleva al otro extremo */
.escaner {
  position: absolute;
  inset: 0;
  animation: escanear 800ms ease-in-out infinite alternate;
}
.escaner::before {
  content: '';
  position: absolute;
  inset-block: -4px;
  left: 0;
  width: 2px;
  background: #ef4444;
  box-shadow: 0 0 10px 2px rgb(239 68 68 / 0.7);
}
@keyframes escanear {
  to {
    transform: translateX(calc(100% - 2px));
  }
}

/* Cambio de estado en la etiqueta: el viejo sube y se va, el nuevo sube desde abajo */
.estado-enter-active,
.estado-leave-active {
  transition:
    opacity var(--dur-media) var(--ease-llega),
    transform var(--dur-media) var(--ease-llega);
}
.estado-enter-from {
  opacity: 0;
  transform: translateY(100%);
}
.estado-leave-to {
  opacity: 0;
  transform: translateY(-100%);
}

@media (prefers-reduced-motion: reduce) {
  .pulso {
    display: none;
  }
}
</style>
