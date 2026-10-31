<script setup lang="ts">
// Inicio es para cualquier usuario con sesión: es el destino al que el middleware manda
// a quien no tiene permiso, así que NO debe pedir uno (si no, se forma un bucle).
definePageMeta({ titulo: 'Inicio' })

/*
  Resumen del taller (GET /dashboard, que sale de vw_DashboardResumen). Los números los calcula la vista;
  aquí solo se muestran y cada uno lleva a la pantalla donde se atiende.
*/
type Resumen = {
  ordenesAbiertas: number
  recibidas: number
  enDiagnostico: number
  esperandoAutorizacion: number
  enReparacion: number
  listasParaEntregar: number
  facturasConSaldo: number
  saldoPorCobrar: number
  repuestosBajoMinimo: number
}

const auth = useAuthStore()
const api = useApi()

const primerNombre = computed(() => auth.usuario?.nombreCompleto.split(' ')[0] ?? '')
const accesos = computed(() =>
  MENU.filter((i) => i.ruta !== '/' && (!i.permiso || auth.puede(i.permiso))),
)

const verResumen = computed(() => auth.puede('REPORTE_VER'))
const resumen = ref<Resumen | null>(null)
const cargandoResumen = ref(false)
const falloResumen = ref(false)

async function cargarResumen() {
  if (!verResumen.value) return
  cargandoResumen.value = true
  falloResumen.value = false
  try {
    resumen.value = await api<Resumen>('/dashboard')
  } catch {
    falloResumen.value = true
  } finally {
    cargandoResumen.value = false
  }
}
onMounted(cargarResumen)

// Cada etapa de la reparación lleva a la lista de órdenes ya filtrada por ese estado
const etapas = computed(() => {
  const r = resumen.value
  if (!r) return []
  return [
    { estado: 'RECIBIDO', cantidad: r.recibidas },
    { estado: 'DIAGNOSTICO', cantidad: r.enDiagnostico },
    { estado: 'ESPERANDO_AUTORIZACION', cantidad: r.esperandoAutorizacion },
    { estado: 'REPARACION', cantidad: r.enReparacion },
    { estado: 'LISTO', cantidad: r.listasParaEntregar },
  ]
})
const puedeCaja = computed(() => auth.puede('PAGO_REGISTRAR'))
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <h2 class="text-2xl font-semibold tracking-tight">Hola, {{ primerNombre }}</h2>
    <p class="mt-1 text-bruma-600">Así va el taller hoy y los módulos que tu rol puede usar.</p>

    <section v-if="verResumen" class="mt-6 space-y-3" aria-label="Resumen del taller">
      <p v-if="cargandoResumen && !resumen" class="text-sm text-bruma-600" aria-live="polite">Cargando el resumen…</p>

      <div v-else-if="falloResumen" class="flex flex-wrap items-center gap-3 rounded-lg border border-bruma-200 bg-white p-4">
        <p class="text-sm text-bruma-600">No se pudo cargar el resumen del taller.</p>
        <UButton size="xs" color="neutral" variant="outline" icon="i-lucide-refresh-cw" @click="cargarResumen">Reintentar</UButton>
      </div>

      <template v-else-if="resumen">
        <div class="rounded-lg border border-bruma-200 bg-white p-4">
          <div class="flex flex-wrap items-baseline justify-between gap-2">
            <h3 class="font-semibold">Órdenes abiertas</h3>
            <NuxtLink to="/ordenes" class="text-sm text-placa-700 underline-offset-2 hover:underline">Ver todas</NuxtLink>
          </div>
          <p class="cifras mt-1 text-4xl font-semibold tracking-tight">{{ numero(resumen.ordenesAbiertas) }}</p>
          <ul class="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-5">
            <li v-for="e in etapas" :key="e.estado">
              <NuxtLink
                :to="{ path: '/ordenes', query: { estado: e.estado } }"
                class="block rounded-md border border-bruma-200 px-3 py-2 transition-colors hover:border-placa-300 hover:bg-placa-50 motion-reduce:transition-none"
              >
                <span class="cifras block text-xl font-semibold">{{ numero(e.cantidad) }}</span>
                <span class="block text-xs text-bruma-600">{{ ESTADO_ORDEN[e.estado]?.texto }}</span>
              </NuxtLink>
            </li>
          </ul>
        </div>

        <div class="grid gap-3 sm:grid-cols-2">
          <component
            :is="puedeCaja ? 'NuxtLink' : 'div'"
            :to="puedeCaja ? '/caja' : undefined"
            class="rounded-lg border border-bruma-200 bg-white p-4"
            :class="puedeCaja ? 'transition-colors hover:border-placa-300 motion-reduce:transition-none' : ''"
          >
            <h3 class="font-semibold">Por cobrar</h3>
            <p class="cifras mt-1 text-3xl font-semibold tracking-tight">{{ quetzales(resumen.saldoPorCobrar) }}</p>
            <p class="mt-1 text-sm text-bruma-600">
              en {{ numero(resumen.facturasConSaldo) }} {{ resumen.facturasConSaldo === 1 ? 'factura' : 'facturas' }} con saldo
            </p>
          </component>
          <NuxtLink
            to="/inventario"
            class="rounded-lg border border-bruma-200 bg-white p-4 transition-colors hover:border-placa-300 motion-reduce:transition-none"
          >
            <h3 class="font-semibold">Repuestos por reponer</h3>
            <p class="cifras mt-1 text-3xl font-semibold tracking-tight">{{ numero(resumen.repuestosBajoMinimo) }}</p>
            <p class="mt-1 text-sm text-bruma-600">bajo el mínimo o sin stock</p>
          </NuxtLink>
        </div>
      </template>
    </section>

    <h3 class="mt-8 text-sm font-medium text-bruma-600">Módulos</h3>
    <ul class="mt-2 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <li v-for="a in accesos" :key="a.ruta">
        <NuxtLink
          v-if="a.listo"
          :to="a.ruta"
          class="flex h-full gap-3 rounded-lg border border-bruma-200 bg-white p-4 transition-colors hover:border-placa-300 motion-reduce:transition-none"
        >
          <span class="grid size-9 shrink-0 place-items-center rounded-md bg-placa-50 text-placa-600">
            <UIcon :name="a.icono" class="size-5" />
          </span>
          <span>
            <span class="block font-medium">{{ a.etiqueta }}</span>
            <span class="mt-0.5 block text-sm text-bruma-600">{{ a.descripcion }}</span>
          </span>
        </NuxtLink>

        <div v-else class="flex h-full gap-3 rounded-lg border border-dashed border-bruma-300 p-4" aria-disabled="true">
          <span class="grid size-9 shrink-0 place-items-center rounded-md bg-bruma-200 text-bruma-500">
            <UIcon :name="a.icono" class="size-5" />
          </span>
          <span>
            <span class="block font-medium text-bruma-600">{{ a.etiqueta }}</span>
            <span class="mt-0.5 block text-sm text-bruma-500">{{ a.descripcion }}</span>
            <span class="mt-1.5 block text-xs text-bruma-500">Disponible pronto</span>
          </span>
        </div>
      </li>
    </ul>
  </div>
</template>
