<script setup lang="ts">
import type { ResumenTaller } from '~/components/tablero/LineaTaller.vue'

// Inicio es para cualquier usuario con sesión: es el destino al que el middleware manda
// a quien no tiene permiso, así que NO debe pedir uno (si no, se forma un bucle).
// El tablero (GET /dashboard) solo se pide y se muestra si el rol tiene REPORTE_VER.
definePageMeta({ titulo: 'Inicio' })

type Resumen = ResumenTaller & {
  ordenesAbiertas: number
  facturasConSaldo: number
  saldoPorCobrar: number
  repuestosBajoMinimo: number
}

const auth = useAuthStore()
const api = useApi()

const primerNombre = computed(() => auth.usuario?.nombreCompleto.split(' ')[0] ?? '')
const hoy = new Intl.DateTimeFormat('es-GT', { weekday: 'long', day: 'numeric', month: 'long' }).format(new Date())
const accesos = computed(() =>
  MENU.filter((i) => i.ruta !== '/' && (!i.permiso || auth.puede(i.permiso))),
)

const veTablero = computed(() => auth.puede('REPORTE_VER'))
// "Por cobrar" es enlace a Caja solo para quien puede cobrar; para los demás es una tarjeta sin enlace
const puedeCobrar = computed(() => auth.puede('PAGO_REGISTRAR'))
const NuxtLink = resolveComponent('NuxtLink')
const resumen = ref<Resumen | null>(null)
const cargando = ref(veTablero.value) // desde el primer instante: así no hay un cuadro vacío antes de pedir los datos
const esqueleto = useEsqueleto(cargando)
const fallo = ref(false)

async function cargar() {
  if (!veTablero.value) return
  cargando.value = true
  fallo.value = false
  try {
    resumen.value = await api<Resumen>('/dashboard')
  } catch {
    fallo.value = true
  } finally {
    cargando.value = false
  }
}
onMounted(cargar)

// La frase de arriba dice lo más urgente con los mismos números del tablero
const frase = computed(() => {
  const r = resumen.value
  if (!r) return ''
  const partes = []
  if (r.listasParaEntregar) partes.push(`${numero(r.listasParaEntregar)} ${r.listasParaEntregar === 1 ? 'equipo listo espera' : 'equipos listos esperan'} a su dueño`)
  if (r.esperandoAutorizacion) partes.push(`${numero(r.esperandoAutorizacion)} ${r.esperandoAutorizacion === 1 ? 'espera' : 'esperan'} la respuesta del cliente`)
  return partes.join(' · ')
})
</script>

<template>
  <div class="mx-auto max-w-6xl">
    <div class="entra" style="--i: 0">
      <p class="text-sm text-bruma-600 first-letter:uppercase">{{ hoy }}</p>
      <h2 class="text-2xl font-semibold tracking-tight">Hola, {{ primerNombre }}</h2>
    </div>

    <!-- Tablero: solo con REPORTE_VER -->
    <section v-if="veTablero" class="mt-6" aria-labelledby="titulo-taller">
      <!-- Cargando: cajas grises con la misma forma del tablero (no salta nada al llegar los datos) -->
      <div v-if="esqueleto && !resumen" class="grid gap-4 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]" aria-busy="true">
        <div class="rounded-xl border border-bruma-200 bg-white p-6">
          <USkeleton class="h-4 w-32" />
          <USkeleton class="mt-3 h-14 w-24" />
          <USkeleton class="mt-6 h-11 w-full" />
          <div class="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-5">
            <USkeleton v-for="i in 5" :key="i" class="h-12" />
          </div>
        </div>
        <div class="grid gap-4">
          <div v-for="i in 2" :key="i" class="rounded-xl border border-bruma-200 bg-white p-6">
            <USkeleton class="h-4 w-24" />
            <USkeleton class="mt-3 h-8 w-36" />
            <USkeleton class="mt-3 h-4 w-40" />
          </div>
        </div>
        <span class="sr-only">Cargando el resumen del taller…</span>
      </div>

      <UAlert
        v-else-if="fallo"
        color="error"
        variant="subtle"
        icon="i-lucide-circle-alert"
        title="No se pudo cargar el resumen del taller"
        :actions="[{ label: 'Reintentar', color: 'neutral', variant: 'outline', icon: 'i-lucide-refresh-cw', onClick: cargar }]"
      />

      <div v-else-if="resumen" class="grid gap-4 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
        <div class="entra rounded-xl border border-bruma-200 bg-white p-6" style="--i: 1">
          <h3 id="titulo-taller" class="text-sm font-medium text-bruma-600">El taller ahora</h3>
          <p class="mt-1 flex items-baseline gap-3">
            <span class="text-6xl font-semibold tracking-tight text-bruma-950">
              <ContadorAnimado :valor="resumen.ordenesAbiertas" :retraso="200" />
            </span>
            <span class="text-lg text-bruma-700">órdenes abiertas</span>
          </p>
          <p v-if="frase" class="mt-1 text-sm text-bruma-600">{{ frase }}</p>

          <TableroLineaTaller :datos="resumen" class="mt-6" />
        </div>

        <div class="grid gap-4">
          <component
            :is="puedeCobrar ? NuxtLink : 'div'"
            v-bind="puedeCobrar ? { to: '/caja' } : {}"
            class="entra group block rounded-xl border border-bruma-200 bg-white p-6 transition-colors"
            :class="puedeCobrar ? 'hover:border-placa-300' : ''"
            style="--i: 2"
          >
            <span class="flex items-center justify-between text-sm font-medium text-bruma-600">
              Por cobrar
              <UIcon v-if="puedeCobrar" name="i-lucide-arrow-right" class="size-4 -translate-x-1 opacity-0 transition duration-200 group-hover:translate-x-0 group-hover:opacity-100" />
            </span>
            <span class="mt-1 block text-3xl font-semibold tracking-tight">
              <ContadorAnimado :valor="resumen.saldoPorCobrar" :formato="quetzales" :retraso="350" />
            </span>
            <span class="mt-1 block text-sm text-bruma-600">
              en {{ numero(resumen.facturasConSaldo) }} {{ resumen.facturasConSaldo === 1 ? 'factura' : 'facturas' }} con saldo
            </span>
          </component>

          <NuxtLink
            to="/inventario"
            class="entra group block rounded-xl border border-bruma-200 bg-white p-6 transition-colors hover:border-placa-300"
            style="--i: 3"
          >
            <span class="flex items-center justify-between text-sm font-medium text-bruma-600">
              Repuestos por reponer
              <UIcon name="i-lucide-arrow-right" class="size-4 -translate-x-1 opacity-0 transition duration-200 group-hover:translate-x-0 group-hover:opacity-100" />
            </span>
            <span class="mt-1 block text-3xl font-semibold tracking-tight" :class="resumen.repuestosBajoMinimo ? 'text-acento-800' : ''">
              <ContadorAnimado :valor="resumen.repuestosBajoMinimo" :retraso="450" />
            </span>
            <span class="mt-1 block text-sm text-bruma-600">bajo el mínimo o sin existencia</span>
          </NuxtLink>
        </div>
      </div>
    </section>

    <h3 class="entra mt-10 text-sm font-medium text-bruma-600" style="--i: 4">
      {{ veTablero ? 'Módulos' : 'Estos son los módulos que tu rol puede usar.' }}
    </h3>
    <ul class="entra mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3" style="--i: 5">
      <li v-for="a in accesos" :key="a.ruta">
        <NuxtLink
          v-if="a.listo"
          :to="a.ruta"
          class="group flex h-full gap-3 rounded-lg border border-bruma-200 bg-white p-4 transition-colors hover:border-placa-300 motion-reduce:transition-none"
        >
          <span class="grid size-9 shrink-0 place-items-center rounded-md bg-placa-50 text-placa-600">
            <UIcon :name="a.icono" class="size-5" />
          </span>
          <span class="min-w-0 flex-1">
            <span class="flex items-center justify-between font-medium">
              {{ a.etiqueta }}
              <UIcon name="i-lucide-arrow-right" class="size-4 -translate-x-1 text-placa-600 opacity-0 transition duration-200 group-hover:translate-x-0 group-hover:opacity-100" />
            </span>
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
