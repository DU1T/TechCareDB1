<script setup lang="ts">
/*
  Actividad reciente del Inicio: los últimos movimientos de inventario (GET /inventario/kardex, permiso REPORTE_VER).

  Cuatro cosas que no son obvias de la API:
  - Los movimientos NO vienen en orden de fecha: el procedimiento los ordena por bodega, repuesto y fecha (es un kárdex por
    artículo). Aquí se ordenan por fecha, del más nuevo al más viejo, y se toman los primeros. Tomar "el final de la lista"
    daría el último repuesto por orden alfabético, no lo más reciente.
  - Se pide una ventana que termina MAÑANA: la base guarda la hora del servidor (UTC) y de noche en Guatemala el "hoy" de la
    base ya es mañana; con fechaFin = hoy se perderían justo los movimientos más nuevos. (fechaFin incluye el día entero.)
  - La ventana se adapta: primero el último mes; si hay menos de MOSTRAR movimientos, el último año. Con los datos de ejemplo,
    que terminan en agosto, una ventana fija de unos días dejaría el cuadro vacío; así siempre se ve lo último que haya.
  - Las horas se muestran como las guarda la base, igual que en el resto del sistema. No se calcula "hace 2 h": ese desfase
    daría tiempos negativos.
*/
type Movimiento = {
  fechaMovimiento: string
  bodega: string
  codigo: string
  repuesto: string
  tipo: 'ENTRADA' | 'SALIDA'
  origen: string
  documentoOrigen: string
  cantidad: number
  existenciaAnterior: number
  existenciaResultante: number
  usuario: string
}

const VENTANAS = [30, 365] // días hacia atrás: primero el último mes y, si hay pocos movimientos, el último año
const MOSTRAR = 8

const api = useApi()
const movimientos = ref<Movimiento[]>([])
const cargando = ref(true)
const esqueleto = useEsqueleto(cargando)
const fallo = ref(false)

const pedirVentana = (dias: number) =>
  api<Movimiento[]>('/inventario/kardex', { query: { fechaInicio: diaISO(-dias), fechaFin: diaISO(1) } })

// Si dos cargas se cruzan (por ejemplo, un "Reintentar" rápido), solo vale la última que se pidió
let pedido = 0
async function cargar() {
  const mio = ++pedido
  cargando.value = true
  fallo.value = false
  try {
    let r = await pedirVentana(VENTANAS[0]!)
    if (r.length < MOSTRAR && mio === pedido) r = await pedirVentana(VENTANAS[1]!)
    if (mio === pedido) movimientos.value = r
  } catch {
    if (mio !== pedido) return
    movimientos.value = []
    fallo.value = true
  } finally {
    if (mio === pedido) cargando.value = false
  }
}
onMounted(cargar)

// Más nuevo primero; si dos movimientos tienen la misma hora, el que venía después en la lista (se registró después) va antes
const recientes = computed(() =>
  movimientos.value
    .map((m, i) => ({ m, i, t: +new Date(m.fechaMovimiento) }))
    .sort((a, b) => b.t - a.t || b.i - a.i)
    .slice(0, MOSTRAR)
    .map((x) => x.m),
)

// "Orden OS-000042" o "Devolución de la orden OS-000042": el número de orden va en el texto, y de ahí sale el enlace
function idOrdenDe(m: Movimiento) {
  if (m.origen !== 'REPARACION' && m.origen !== 'DEVOLUCION') return 0
  const numero = m.documentoOrigen.match(/OS-\d+/)?.[0]
  return numero ? idDeOrden(numero) : 0
}
const esEntrada = (m: Movimiento) => m.tipo === 'ENTRADA'
</script>

<template>
  <section class="rounded-xl border border-bruma-200 bg-white" aria-labelledby="titulo-actividad">
    <div class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 px-5 pt-5">
      <div>
        <h3 id="titulo-actividad" class="font-semibold">Actividad reciente</h3>
        <p class="text-sm text-bruma-600">Últimos movimientos de inventario</p>
      </div>
      <NuxtLink to="/inventario/kardex" class="group inline-flex items-center gap-1 text-sm text-placa-700 hover:underline">
        Ver kárdex
        <UIcon name="i-lucide-arrow-right" class="size-4 opacity-60 transition duration-200 group-hover:translate-x-0.5 group-hover:opacity-100 group-focus-visible:translate-x-0.5 group-focus-visible:opacity-100 motion-reduce:transition-none" />
      </NuxtLink>
    </div>

    <div class="mt-2 pb-2">
      <!-- Cargando: el alto ya está reservado; las cajas grises solo se ven si la carga se alarga -->
      <TablaEsqueleto v-if="cargando && !movimientos.length" :visible="esqueleto" :filas="5" :columnas="3" />

      <div v-else-if="fallo" class="flex flex-wrap items-center gap-3 px-5 py-4">
        <p class="text-sm text-bruma-600">No se pudo cargar la actividad reciente.</p>
        <UButton size="xs" color="neutral" variant="outline" icon="i-lucide-refresh-cw" @click="cargar">Reintentar</UButton>
      </div>

      <p v-else-if="!recientes.length" class="px-5 py-4 text-sm text-bruma-600">
        No hubo movimientos de inventario en el último año.
      </p>

      <ol v-else class="divide-y divide-bruma-100">
        <li
          v-for="(m, i) in recientes"
          :key="`${m.fechaMovimiento}-${m.codigo}-${m.bodega}-${m.tipo}-${m.existenciaResultante}`"
          class="entra grid grid-cols-[4.5rem_minmax(0,1fr)_auto] items-start gap-3 px-5 py-3"
          :style="{ '--i': i }"
        >
          <div>
            <p class="cifras text-sm font-medium">{{ diaCorto(m.fechaMovimiento) }}</p>
            <p class="cifras text-xs text-bruma-500">{{ horaCorta(m.fechaMovimiento) }}</p>
          </div>

          <div class="min-w-0">
            <p class="truncate font-medium" :title="m.repuesto">{{ m.repuesto }}</p>
            <p class="truncate text-sm text-bruma-600">{{ m.codigo }} · {{ m.bodega }}</p>
            <p class="truncate text-sm text-bruma-600" :title="m.documentoOrigen">
              <NuxtLink v-if="idOrdenDe(m)" :to="`/ordenes/${idOrdenDe(m)}/trazabilidad`" class="text-placa-700 underline-offset-2 hover:underline">{{ m.documentoOrigen }}</NuxtLink>
              <template v-else>{{ m.documentoOrigen }}</template>
            </p>
          </div>

          <div class="text-right">
            <p class="cifras text-lg font-semibold" :class="esEntrada(m) ? 'text-green-700' : 'text-red-700'">
              <span class="sr-only">{{ esEntrada(m) ? 'Entrada de' : 'Salida de' }}</span>{{ esEntrada(m) ? '+' : '−' }}{{ numero(m.cantidad) }}
            </p>
            <p class="cifras text-xs text-bruma-500">
              <span class="sr-only">existencia de</span>{{ numero(m.existenciaAnterior) }} → {{ numero(m.existenciaResultante) }}
            </p>
          </div>
        </li>
      </ol>
    </div>
  </section>
</template>
