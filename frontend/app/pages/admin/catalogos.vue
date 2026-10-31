<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'

/*
  Mantenimiento de catálogos (§6.1): repuestos, proveedores, bodegas, categorías, tipos de equipo y marcas.
  No se borra: lo que tiene estado se desactiva. La existencia del inventario nunca se toca desde aquí.
*/
definePageMeta({ titulo: 'Catálogos', permiso: 'CATALOGO_GESTIONAR' })

const api = useApi()
const activo = ref(MANT_CATALOGOS[0]!.clave)
const def = computed(() => MANT_CATALOGOS.find((c) => c.clave === activo.value)!)

const filas = ref<Record<string, any>[]>([])
const cargando = ref(true)
const esqueleto = useEsqueleto(cargando)
const fallo = ref(false)
const texto = ref('')
const modal = ref(false)
const editando = ref<Record<string, any> | null>(null)

// Si se cambia de pestaña antes de que llegue la respuesta anterior, solo vale la última que se pidió
let pedido = 0
async function cargar() {
  const mio = ++pedido
  cargando.value = true
  fallo.value = false
  try {
    const r = await api<Record<string, any>[]>(def.value.ruta)
    if (mio === pedido) filas.value = r
  } catch {
    if (mio !== pedido) return
    filas.value = []
    fallo.value = true
  } finally {
    if (mio === pedido) cargando.value = false
  }
}
onMounted(cargar)
// Al cambiar de pestaña se vacían las filas: si no, las del catálogo anterior se verían un instante bajo las columnas del nuevo
watch(activo, () => { texto.value = ''; filas.value = []; cargar() })

const visibles = computed(() => {
  const t = texto.value.trim().toLowerCase()
  if (!t) return filas.value
  return filas.value.filter((f) => Object.values(f).some((v) => typeof v === 'string' && v.toLowerCase().includes(t)))
})

const columnas = computed<TableColumn<Record<string, any>>[]>(() => {
  const cols: TableColumn<Record<string, any>>[] = def.value.campos
    .filter((c) => c.tipo !== 'area')
    .map((c) => ({
      id: c.clave,
      header: c.etiqueta,
      meta: c.tipo === 'dinero' ? { class: { th: 'text-right', td: 'text-right' } } : undefined,
    }))
  if (def.value.estados) cols.push({ accessorKey: 'estado', header: 'Estado' })
  cols.push({ id: 'acciones', header: '', meta: { class: { th: 'text-right', td: 'text-right' } } })
  return cols
})

const esActivo = (f: Record<string, any>) => !def.value.estados || f.estado === def.value.estados.activo
function valorCelda(f: Record<string, any>, c: { clave: string; tipo: string }) {
  if (c.tipo === 'dinero') return quetzales(f[c.clave])
  if (c.tipo === 'categoria') return f.categoria ?? '—'
  return f[c.clave] || '—'
}

// Al buscar o cambiar de pestaña, las filas se acomodan (composables/useReacomodo.ts)
const tabla = ref<HTMLElement | null>(null)
useReacomodo(tabla, () => visibles.value)

function nuevo() { editando.value = null; modal.value = true }
function editar(f: Record<string, any>) { editando.value = f; modal.value = true }
</script>

<template>
  <div class="mx-auto max-w-6xl space-y-5">
    <!-- La píldora verde claro es UNA sola pieza (layout-id) que se desliza de una pestaña a otra con resorte.
         Es clara y el texto siempre oscuro, y las etiquetas van por encima (z-10): así se lee en todo el recorrido -->
    <div class="entra flex flex-wrap gap-1.5" style="--i: 0" role="tablist" aria-label="Catálogos">
      <button
        v-for="c in MANT_CATALOGOS" :key="c.clave" type="button" role="tab" :aria-selected="activo === c.clave"
        class="relative rounded-md border px-3 py-1.5 text-sm font-medium transition-colors motion-reduce:transition-none"
        :class="activo === c.clave ? 'border-transparent text-placa-900' : 'border-bruma-300 bg-white text-bruma-700 hover:bg-bruma-50'"
        @click="activo = c.clave"
      >
        <Motion v-if="activo === c.clave" layout-id="pestana-catalogo" class="absolute inset-0 z-0 rounded-md border border-placa-300 bg-placa-100" :transition="RESORTE" />
        <span class="relative z-10">{{ c.titulo }}</span>
      </button>
    </div>

    <div class="entra flex flex-wrap items-end justify-between gap-3" style="--i: 1">
      <UFormField label="Buscar" class="w-full sm:w-80">
        <UInput v-model="texto" icon="i-lucide-search" :placeholder="`Buscar en ${def.titulo.toLowerCase()}`" class="w-full" />
      </UFormField>
      <UButton color="secondary" icon="i-lucide-plus" @click="nuevo">Agregar {{ def.singular }}</UButton>
    </div>

    <div ref="tabla" class="entra overflow-hidden rounded-lg border border-bruma-200 bg-white" style="--i: 2">
      <UTable
        :data="visibles" :columns="columnas" :loading="cargando" sticky class="max-h-[70dvh]"
        :empty="fallo ? 'No se pudo cargar la lista. Intenta de nuevo.' : 'No hay registros con esa búsqueda.'"
      >
        <template #loading><TablaEsqueleto :visible="esqueleto" :columnas="Math.min(columnas.length - 1, 5)" /></template>
        <template v-for="c in def.campos.filter((x) => x.tipo !== 'area')" :key="c.clave" #[`${c.clave}-cell`]="{ row }">
          {{ valorCelda(row.original, c) }}
        </template>
        <template #estado-cell="{ row }">
          <UBadge :color="esActivo(row.original) ? 'success' : 'neutral'" variant="subtle">{{ esActivo(row.original) ? 'Activo' : 'Inactivo' }}</UBadge>
        </template>
        <template #acciones-cell="{ row }">
          <UButton size="xs" color="neutral" variant="ghost" icon="i-lucide-pencil" aria-label="Editar" @click="editar(row.original)" />
        </template>
      </UTable>
    </div>
    <div v-if="fallo && !cargando" class="flex justify-center">
      <UButton color="neutral" variant="outline" icon="i-lucide-refresh-cw" @click="cargar">Reintentar</UButton>
    </div>

    <FormCatalogo v-model:open="modal" :def="def" :fila="editando" @guardado="cargar" />
  </div>
</template>
