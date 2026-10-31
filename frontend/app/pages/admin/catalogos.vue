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
const fallo = ref(false)
const texto = ref('')
const modal = ref(false)
const editando = ref<Record<string, any> | null>(null)

async function cargar() {
  cargando.value = true
  fallo.value = false
  try {
    filas.value = await api<Record<string, any>[]>(def.value.ruta)
  } catch {
    filas.value = []
    fallo.value = true
  } finally {
    cargando.value = false
  }
}
onMounted(cargar)
watch(activo, () => { texto.value = ''; cargar() })

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

function nuevo() { editando.value = null; modal.value = true }
function editar(f: Record<string, any>) { editando.value = f; modal.value = true }
</script>

<template>
  <div class="mx-auto max-w-6xl space-y-5">
    <div class="flex flex-wrap gap-2" role="tablist" aria-label="Catálogos">
      <UButton
        v-for="c in MANT_CATALOGOS" :key="c.clave" role="tab" :aria-selected="activo === c.clave" size="sm"
        :color="activo === c.clave ? 'primary' : 'neutral'" :variant="activo === c.clave ? 'solid' : 'outline'"
        @click="activo = c.clave"
      >{{ c.titulo }}</UButton>
    </div>

    <div class="flex flex-wrap items-end justify-between gap-3">
      <UFormField label="Buscar" class="w-full sm:w-80">
        <UInput v-model="texto" icon="i-lucide-search" :placeholder="`Buscar en ${def.titulo.toLowerCase()}`" class="w-full" />
      </UFormField>
      <UButton color="secondary" icon="i-lucide-plus" @click="nuevo">Agregar {{ def.singular }}</UButton>
    </div>

    <div class="overflow-hidden rounded-lg border border-bruma-200 bg-white">
      <UTable
        :data="visibles" :columns="columnas" :loading="cargando" sticky class="max-h-[70dvh]"
        :empty="fallo ? 'No se pudo cargar la lista. Intenta de nuevo.' : 'No hay registros con esa búsqueda.'"
      >
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
