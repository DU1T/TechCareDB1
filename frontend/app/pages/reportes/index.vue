<script setup lang="ts">
import type { Catalogo, FiltroReporte, Reporte } from '~/utils/reportes'

/*
  Pantalla única de reportes: todo sale de REPORTES (app/utils/reportes.ts).
  Cada reporte es un SP en la base; la API lo expone en /api/reportes/{n} y aquí solo
  se eligen filtros y se muestran las tablas. El reporte elegido queda en la URL (?n=5).
*/
definePageMeta({ titulo: 'Reportes', permiso: 'REPORTE_VER' })

const api = useApi()
const route = useRoute()
const router = useRouter()

const TODOS = '*' // el selector no acepta valores vacíos: '*' significa "sin filtro"

const inicial = REPORTES.find((r) => String(r.numero) === String(route.query.n)) ?? REPORTES[0]!
const reporte = ref<Reporte>(inicial)
const valores = ref<Record<string, any>>({})

const grupos = computed(() => {
  const mapa = new Map<string, Reporte[]>()
  for (const r of REPORTES) mapa.set(r.grupo, [...(mapa.get(r.grupo) ?? []), r])
  return [...mapa].map(([nombre, reportes]) => ({ nombre, reportes }))
})
const opcionesReporte = REPORTES.map((r) => ({ label: `${r.numero}. ${r.titulo}`, value: r.numero }))

// ---- Catálogos de los filtros: se piden una sola vez, cuando un reporte los necesita
const catalogos = ref<Partial<Record<Catalogo, { label: string; value: string | number }[]>>>({})
async function cargarCatalogos(r: Reporte) {
  const faltan = [...new Set(r.filtros.map((f) => f.catalogo).filter((c): c is Catalogo => !!c && !catalogos.value[c]))]
  await Promise.all(faltan.map(async (c) => {
    try {
      const filas = await api<any[]>(CATALOGOS[c].ruta)
      catalogos.value[c] = filas.map((f) => ({ label: CATALOGOS[c].etiqueta(f), value: CATALOGOS[c].valor(f) }))
    } catch {
      catalogos.value[c] = [] // useApi ya mostró el aviso
    }
  }))
}
function opcionesDe(f: FiltroReporte) {
  const lista = f.opciones ?? (f.catalogo ? catalogos.value[f.catalogo] ?? [] : [])
  return [{ label: 'Todos', value: TODOS }, ...lista]
}

// ---- Validación: obligatorios, fechas invertidas y la regla propia del reporte
const vacio = (v: unknown) => v == null || v === '' || v === TODOS || v === false
const problema = computed(() => {
  const r = reporte.value
  const v = valores.value
  const falta = r.filtros.find((f) => f.obligatorio && vacio(typeof v[f.nombre] === 'string' ? v[f.nombre].trim() : v[f.nombre]))
  if (falta) return `Indica ${falta.etiqueta.toLowerCase()}.`
  if (v.fechaInicio && v.fechaFin && v.fechaInicio > v.fechaFin) return 'La fecha «Desde» es posterior a «Hasta».'
  return r.validar?.(v) ?? ''
})

// ---- Consulta
const datos = ref<Record<string, any>[][]>([])
const cargando = ref(false)
const consultado = ref(false)
const intentado = ref(false)

async function consultar() {
  intentado.value = true
  if (problema.value) return
  const r = reporte.value
  const query: Record<string, string | number | boolean> = {}
  for (const f of r.filtros) {
    const v = valores.value[f.nombre]
    if (f.tipo === 'casilla') {
      if (v) query[f.nombre] = true
    } else if (!vacio(v)) {
      query[f.nombre] = typeof v === 'string' ? v.trim() : v
    }
  }
  cargando.value = true
  try {
    const resp = await api<any>(r.ruta, { query })
    // Una lista = un resultado; un objeto = un resultado por clave ({ facturas, pagos })
    datos.value = Array.isArray(resp)
      ? [resp]
      : r.resultados.map((res) => (res.clave && Array.isArray(resp?.[res.clave]) ? resp[res.clave] : []))
    consultado.value = true
  } catch {
    /* useApi mostró el mensaje; se conservan los filtros */
  } finally {
    cargando.value = false
  }
}

async function elegir(numero: number) {
  const r = REPORTES.find((x) => x.numero === numero)
  if (!r) return
  reporte.value = r
  valores.value = {}
  datos.value = []
  consultado.value = false
  intentado.value = false
  router.replace({ query: { n: r.numero } })
  await cargarCatalogos(r)
  if (!problema.value) await consultar() // sin filtros obligatorios se muestra de una vez
}

function limpiar() {
  valores.value = {}
  intentado.value = false
}

onMounted(() => elegir(inicial.numero))
</script>

<template>
  <div class="mx-auto max-w-7xl lg:grid lg:grid-cols-[15rem_minmax(0,1fr)] lg:gap-6">
    <!-- Lista de reportes: columna en escritorio, selector en celular -->
    <nav aria-label="Lista de reportes" class="hidden lg:block">
      <div v-for="g in grupos" :key="g.nombre" class="mb-5">
        <p class="mb-1.5 px-2 text-xs font-medium text-bruma-500">{{ g.nombre }}</p>
        <ul class="space-y-0.5">
          <li v-for="r in g.reportes" :key="r.numero">
            <button
              type="button"
              class="flex w-full items-baseline gap-2 rounded-md px-2 py-1.5 text-left text-sm transition-colors motion-reduce:transition-none"
              :class="r.numero === reporte.numero ? 'bg-placa-50 font-medium text-placa-700' : 'text-bruma-700 hover:bg-bruma-200/60'"
              :aria-current="r.numero === reporte.numero ? 'page' : undefined"
              @click="elegir(r.numero)"
            >
              <span class="cifras w-5 shrink-0 text-bruma-500">{{ r.numero }}</span>
              {{ r.titulo }}
            </button>
          </li>
        </ul>
      </div>
    </nav>

    <div class="min-w-0 space-y-5">
      <UFormField label="Reporte" class="lg:hidden">
        <USelect :model-value="reporte.numero" :items="opcionesReporte" class="w-full" @update:model-value="(n: number) => elegir(n)" />
      </UFormField>

      <div>
        <h2 class="text-xl font-semibold tracking-tight">
          <span class="cifras text-bruma-500">{{ reporte.numero }}.</span> {{ reporte.titulo }}
        </h2>
        <p class="mt-0.5 text-sm text-bruma-600">{{ reporte.descripcion }}</p>
      </div>

      <form class="flex flex-wrap items-end gap-3" novalidate @submit.prevent="consultar">
        <UFormField
          v-for="f in reporte.filtros"
          :key="`${reporte.numero}-${f.nombre}`"
          :label="f.tipo === 'casilla' ? undefined : f.etiqueta"
          :required="f.obligatorio"
          :hint="f.ayuda"
          :class="f.tipo === 'fecha' ? 'w-full sm:w-40' : f.tipo === 'casilla' ? '' : 'w-full sm:w-56'"
        >
          <UInput v-if="f.tipo === 'texto'" v-model="valores[f.nombre]" :maxlength="f.nombre === 'nit' ? 15 : 60" class="w-full" />
          <UInput v-else-if="f.tipo === 'numero'" v-model="valores[f.nombre]" type="number" min="1" class="w-full" />
          <UInput v-else-if="f.tipo === 'fecha'" v-model="valores[f.nombre]" type="date" class="w-full" />
          <UCheckbox v-else-if="f.tipo === 'casilla'" v-model="valores[f.nombre]" :label="f.etiqueta" class="py-1.5" />
          <USelectMenu
            v-else
            v-model="valores[f.nombre]"
            :items="opcionesDe(f)"
            value-key="value"
            placeholder="Todos"
            :search-input="opcionesDe(f).length > 10 ? { placeholder: 'Buscar' } : false"
            class="w-full"
          />
        </UFormField>
        <div class="flex gap-2">
          <UButton type="submit" color="secondary" :loading="cargando">Consultar</UButton>
          <UButton v-if="reporte.filtros.length" color="neutral" variant="ghost" @click="limpiar">Quitar filtros</UButton>
        </div>
      </form>

      <div aria-live="polite">
        <UAlert v-if="intentado && problema" color="error" variant="subtle" icon="i-lucide-circle-alert" :description="problema" />
      </div>

      <p v-if="!consultado && !cargando" class="rounded-lg border border-dashed border-bruma-300 p-6 text-center text-sm text-bruma-600">
        Elige los filtros y pulsa Consultar.
      </p>
      <template v-else>
        <ReporteTabla
          v-for="(res, i) in reporte.resultados"
          :key="`${reporte.numero}-${i}`"
          :titulo="reporte.resultados.length > 1 ? res.titulo : undefined"
          :columnas="res.columnas"
          :filas="datos[i] ?? []"
          :cargando="cargando"
        />
      </template>
    </div>
  </div>
</template>
