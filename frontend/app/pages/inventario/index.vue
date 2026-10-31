<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'

/*
  Existencias por bodega (vw_InventarioActual a través de GET /inventario).
  El ajuste NO toca la tabla: llama a sp_AjusteInventario, que deja el movimiento en el kárdex
  con el motivo. Si el ajuste dejaría el stock en negativo, el SP lo rechaza (R10) y se ve el mensaje.
*/
definePageMeta({ titulo: 'Inventario', permiso: 'REPORTE_VER' })

type Fila = {
  idBodega: number
  bodega: string
  idRepuesto: number
  codigo: string
  repuesto: string
  categoria: string
  existencia: number
  stockMinimo: number
  valorInventario: number
  estadoStock: string
  fechaUltimoMovimiento: string | null
}
type Opcion<T> = { label: string; value: T }

const api = useApi()
const auth = useAuthStore()
const toast = useToast()
const puedeAjustar = computed(() => auth.puede('CATALOGO_GESTIONAR'))

// ---- Filtros: 0 / 'TODOS' significa "sin filtro" (el selector no acepta valores vacíos)
const filtro = reactive({ idBodega: 0, idCategoria: 0, estadoStock: 'TODOS', texto: '' })
const bodegas = ref<Opcion<number>[]>([{ label: 'Todas las bodegas', value: 0 }])
const categorias = ref<Opcion<number>[]>([{ label: 'Todas las categorías', value: 0 }])
const estados: Opcion<string>[] = [
  { label: 'Todos los estados', value: 'TODOS' },
  ...Object.entries(ESTADO_STOCK).map(([value, e]) => ({ label: e.texto, value })),
]

const filas = ref<Fila[]>([])
const cargando = ref(true)

async function cargar() {
  cargando.value = true
  try {
    filas.value = await api<Fila[]>('/inventario', {
      query: {
        idBodega: filtro.idBodega || undefined,
        idCategoria: filtro.idCategoria || undefined,
        estadoStock: filtro.estadoStock === 'TODOS' ? undefined : filtro.estadoStock,
      },
    })
  } catch {
    filas.value = [] // useApi ya mostró el aviso
  } finally {
    cargando.value = false
  }
}

onMounted(async () => {
  try {
    const [b, c] = await Promise.all([
      api<{ idBodega: number; nombre: string }[]>('/bodegas'),
      api<{ idCategoria: number; nombre: string }[]>('/categorias'),
    ])
    bodegas.value.push(...b.map((x) => ({ label: x.nombre, value: x.idBodega })))
    categorias.value.push(...c.map((x) => ({ label: x.nombre, value: x.idCategoria })))
  } catch {
    /* sin catálogos los filtros quedan en "Todas" */
  }
  await cargar()
})
watch(() => [filtro.idBodega, filtro.idCategoria, filtro.estadoStock], cargar)

// La búsqueda por código o nombre se hace aquí, sin volver a llamar a la API
const visibles = computed(() => {
  const t = filtro.texto.trim().toLowerCase()
  if (!t) return filas.value
  return filas.value.filter((f) => f.codigo.toLowerCase().includes(t) || f.repuesto.toLowerCase().includes(t))
})

const resumen = computed(() => ({
  lineas: visibles.value.length,
  bajoMinimo: visibles.value.filter((f) => f.estadoStock === 'BAJO_MINIMO').length,
  sinStock: visibles.value.filter((f) => f.estadoStock === 'SIN_STOCK').length,
  valor: visibles.value.reduce((s, f) => s + f.valorInventario, 0),
}))

const derecha = { class: { th: 'text-right', td: 'text-right' } }
const columnas: TableColumn<Fila>[] = [
  { accessorKey: 'repuesto', header: 'Repuesto' },
  { accessorKey: 'bodega', header: 'Bodega' },
  { accessorKey: 'existencia', header: 'Existencia', meta: derecha },
  { accessorKey: 'stockMinimo', header: 'Mínimo', meta: derecha },
  { accessorKey: 'estadoStock', header: 'Estado' },
  { accessorKey: 'valorInventario', header: 'Valor', meta: derecha },
  { accessorKey: 'fechaUltimoMovimiento', header: 'Último movimiento' },
  { id: 'acciones', header: '', meta: derecha },
]

// ---- Ajuste manual (conteo físico, merma, daño...)
const ajuste = reactive({
  abierto: false,
  fila: null as Fila | null,
  tipo: 'SALIDA' as 'ENTRADA' | 'SALIDA',
  cantidad: 1,
  motivo: '',
  guardando: false,
})
const tiposAjuste = [
  { label: 'Restar (salida)', value: 'SALIDA' },
  { label: 'Sumar (entrada)', value: 'ENTRADA' },
]

function abrirAjuste(f: Fila) {
  Object.assign(ajuste, { abierto: true, fila: f, tipo: 'SALIDA', cantidad: 1, motivo: '' })
}

const quedaria = computed(() => {
  if (!ajuste.fila) return 0
  const c = ajuste.cantidad || 0
  return ajuste.fila.existencia + (ajuste.tipo === 'ENTRADA' ? c : -c)
})
const ajusteValido = computed(
  () => ajuste.cantidad > 0 && ajuste.cantidad <= LIMITE.cantidadMax && quedaria.value >= 0 && ajuste.motivo.trim().length > 0 && ajuste.motivo.length <= 250,
)

async function guardarAjuste() {
  if (!ajuste.fila || !ajusteValido.value) return
  ajuste.guardando = true
  try {
    const r = await api<{ existenciaResultante: number }>('/inventario/ajuste', {
      method: 'POST',
      body: {
        idBodega: ajuste.fila.idBodega,
        idRepuesto: ajuste.fila.idRepuesto,
        cantidad: ajuste.tipo === 'ENTRADA' ? ajuste.cantidad : -ajuste.cantidad,
        motivo: ajuste.motivo.trim(),
      },
    })
    toast.add({
      title: 'Ajuste registrado',
      description: `${ajuste.fila.codigo}: la existencia quedó en ${r.existenciaResultante}.`,
      color: 'success',
    })
    ajuste.abierto = false
    await cargar()
  } catch {
    /* el modal sigue abierto con lo escrito; useApi mostró el mensaje del SP */
  } finally {
    ajuste.guardando = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-7xl space-y-5">
    <div class="flex flex-wrap items-end gap-3">
      <UFormField label="Buscar" class="w-full sm:w-64">
        <UInput v-model="filtro.texto" icon="i-lucide-search" placeholder="Código o nombre" :maxlength="LIMITE.busqueda" class="w-full" />
      </UFormField>
      <UFormField label="Bodega" class="w-full sm:w-52">
        <USelect v-model="filtro.idBodega" :items="bodegas" class="w-full" />
      </UFormField>
      <UFormField label="Categoría" class="w-full sm:w-52">
        <USelect v-model="filtro.idCategoria" :items="categorias" class="w-full" />
      </UFormField>
      <UFormField label="Estado" class="w-full sm:w-44">
        <USelect v-model="filtro.estadoStock" :items="estados" class="w-full" />
      </UFormField>
    </div>

    <dl class="grid grid-cols-2 gap-3 lg:grid-cols-4">
      <div class="rounded-lg border border-bruma-200 bg-white p-4">
        <dt class="text-sm text-bruma-600">Líneas en pantalla</dt>
        <dd class="cifras mt-1 text-2xl font-semibold">{{ numero(resumen.lineas) }}</dd>
      </div>
      <div class="rounded-lg border border-bruma-200 bg-white p-4">
        <dt class="text-sm text-bruma-600">Bajo mínimo</dt>
        <dd class="cifras mt-1 text-2xl font-semibold text-amber-700">{{ numero(resumen.bajoMinimo) }}</dd>
      </div>
      <div class="rounded-lg border border-bruma-200 bg-white p-4">
        <dt class="text-sm text-bruma-600">Sin stock</dt>
        <dd class="cifras mt-1 text-2xl font-semibold text-red-700">{{ numero(resumen.sinStock) }}</dd>
      </div>
      <div class="rounded-lg border border-bruma-200 bg-white p-4">
        <dt class="text-sm text-bruma-600">Valor a costo</dt>
        <dd class="cifras mt-1 text-2xl font-semibold">{{ quetzales(resumen.valor) }}</dd>
      </div>
    </dl>

    <div class="overflow-hidden rounded-lg border border-bruma-200 bg-white">
      <UTable :data="visibles" :columns="columnas" :loading="cargando" empty="No hay repuestos con esos filtros." sticky class="max-h-[65dvh]">
        <template #repuesto-cell="{ row }">
          <span class="block font-medium text-highlighted">{{ row.original.repuesto }}</span>
          <span class="block text-xs text-bruma-500">{{ row.original.codigo }} · {{ row.original.categoria }}</span>
        </template>
        <template #existencia-cell="{ row }">
          <span class="cifras font-medium text-highlighted">{{ numero(row.original.existencia) }}</span>
        </template>
        <template #estadoStock-cell="{ row }">
          <UBadge
            :color="ESTADO_STOCK[row.original.estadoStock]?.color ?? 'neutral'"
            variant="subtle"
          >
            {{ ESTADO_STOCK[row.original.estadoStock]?.texto ?? row.original.estadoStock }}
          </UBadge>
        </template>
        <template #valorInventario-cell="{ row }">{{ quetzales(row.original.valorInventario) }}</template>
        <template #fechaUltimoMovimiento-cell="{ row }">{{ fecha(row.original.fechaUltimoMovimiento) }}</template>
        <template #acciones-cell="{ row }">
          <div class="flex justify-end gap-1">
            <UButton
              size="xs"
              color="neutral"
              variant="ghost"
              icon="i-lucide-history"
              :to="{ path: '/inventario/kardex', query: { idBodega: row.original.idBodega, idRepuesto: row.original.idRepuesto } }"
              :aria-label="`Kárdex de ${row.original.codigo}`"
            />
            <UButton
              v-if="puedeAjustar"
              size="xs"
              color="neutral"
              variant="outline"
              icon="i-lucide-sliders-horizontal"
              @click="abrirAjuste(row.original)"
            >
              Ajustar
            </UButton>
          </div>
        </template>
      </UTable>
    </div>

    <UModal
      v-model:open="ajuste.abierto"
      title="Ajuste de inventario"
      :description="ajuste.fila ? `${ajuste.fila.codigo} · ${ajuste.fila.repuesto} — ${ajuste.fila.bodega}` : ''"
    >
      <template #body>
        <form id="form-ajuste" class="space-y-4" @submit.prevent="guardarAjuste">
          <p class="text-sm">
            Existencia actual: <strong class="cifras">{{ ajuste.fila?.existencia }}</strong>
          </p>
          <UFormField label="Tipo de ajuste">
            <URadioGroup v-model="ajuste.tipo" :items="tiposAjuste" orientation="horizontal" />
          </UFormField>
          <UFormField label="Cantidad">
            <UInputNumber v-model="ajuste.cantidad" :min="1" :max="LIMITE.cantidadMax" class="w-40" />
          </UFormField>
          <UFormField label="Motivo" :hint="`Queda en el kárdex · ${contador(ajuste.motivo, 250)}`" :error="ajuste.motivo.length > 250 ? 'Máximo 250 caracteres' : undefined">
            <UTextarea v-model="ajuste.motivo" :rows="2" maxlength="250" class="w-full" placeholder="Conteo físico, producto dañado..." />
          </UFormField>
          <p class="text-sm" :class="quedaria < 0 ? 'text-red-700' : 'text-bruma-600'" aria-live="polite">
            Quedará en <strong class="cifras">{{ quedaria }}</strong>
            <template v-if="quedaria < 0"> — el inventario no puede quedar negativo.</template>
          </p>
        </form>
      </template>
      <template #footer="{ close }">
        <div class="flex w-full justify-end gap-2">
          <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
          <UButton type="submit" form="form-ajuste" color="secondary" :loading="ajuste.guardando" :disabled="!ajusteValido">
            Registrar ajuste
          </UButton>
        </div>
      </template>
    </UModal>
  </div>
</template>
