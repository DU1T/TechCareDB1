<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'
import type { ColumnaReporte } from '~/utils/reportes'

/*
  Trazabilidad de una orden (reporte 12, GET /reportes/12?idOrden=).
  La API devuelve CINCO resultados por separado: una orden tiene varios repuestos y varios pagos, y
  unidos en una sola consulta cada repuesto se repetiría por cada pago. Aquí cada uno tiene su sección.
*/
definePageMeta({ titulo: 'Trazabilidad de la orden', permiso: 'REPORTE_VER' })

type Fila = Record<string, any>
type Trazabilidad = {
  encabezado: Fila | null
  repuestos: Fila[]
  movimientos: Fila[]
  pagos: Fila[]
  historial: Fila[]
}

const route = useRoute()
const api = useApi()
const auth = useAuthStore()
const id = Number(route.params.id)

const datos = ref<Trazabilidad | null>(null)
const cargando = ref(true)
const noExiste = ref(false)

async function cargar(silencioso = false) {
  if (!Number.isSafeInteger(id) || id <= 0) {
    noExiste.value = true
    cargando.value = false
    return
  }
  if (!silencioso) cargando.value = true
  try {
    datos.value = await api<Trazabilidad>('/reportes/12', { query: { idOrden: id } })
    noExiste.value = false
  } catch {
    noExiste.value = true // useApi mostró el motivo (404: la orden no existe)
  } finally {
    cargando.value = false
  }
}
onMounted(() => cargar())

const e = computed<Fila>(() => datos.value?.encabezado ?? {})
const estado = computed(() => ESTADO_ORDEN[e.value.estado] ?? { texto: e.value.estado ?? '', color: 'neutral' as const })

// Cada etapa se muestra aunque todavía no haya ocurrido: es parte de la trazabilidad
type Dato = [etiqueta: string, valor: string]
const etapas = computed<{ titulo: string; hecha: boolean; vacio: string; datos: Dato[] }[]>(() => {
  const x = e.value
  const equipo = [x.tipoEquipo, x.marca, x.modelo].filter(Boolean).join(' · ')
  return [
    {
      titulo: 'Recepción', hecha: true, vacio: '',
      datos: [
        ['Cliente', `${x.cliente ?? '—'} (NIT ${x.nitCliente ?? '—'})`],
        ['Equipo', `${equipo || '—'}${x.numeroSerie ? ` · Serie ${x.numeroSerie}` : ''}`],
        ['Problema reportado', x.problemaReportado ?? '—'],
        ['Recibió', `${x.recepcionista ?? '—'} el ${fechaYHora(x.fechaIngreso)}`],
      ],
    },
    {
      titulo: 'Diagnóstico', hecha: !!x.fechaDiagnostico, vacio: 'Todavía no tiene diagnóstico.',
      datos: [
        ['Técnico', x.tecnicoDiagnostico ?? '—'],
        ['Fecha', fechaYHora(x.fechaDiagnostico)],
        ['Diagnóstico', x.diagnostico ?? '—'],
        ['Mano de obra estimada', quetzales(x.costoManoObraEstimado)],
        ['Respuesta del cliente', legibleRespuesta(x.respuestaCliente)],
      ],
    },
    {
      titulo: 'Reparación', hecha: !!x.inicioReparacion, vacio: 'La reparación todavía no empieza.',
      datos: [
        ['Técnico', x.tecnicoReparacion ?? '—'],
        ['Inicio', fechaYHora(x.inicioReparacion)],
        ['Fin', fechaYHora(x.finReparacion)],
        ['Trabajo realizado', x.descripcionTrabajo ?? '—'],
        ['Mano de obra', quetzales(x.costoManoObra)],
      ],
    },
    {
      titulo: 'Factura y pagos', hecha: !!x.numeroFactura, vacio: 'La orden todavía no tiene factura.',
      datos: [
        ['Factura', `${x.numeroFactura ?? '—'} · ${fecha(x.fechaEmision)}`],
        ['Subtotal', quetzales(x.subtotal)],
        ['Impuesto', quetzales(x.impuesto)],
        ['Total', quetzales(x.total)],
        ['Pagado', quetzales(x.totalPagado)],
        ['Saldo', quetzales(x.saldo)],
      ],
    },
    {
      titulo: 'Entrega', hecha: !!x.fechaEntrega, vacio: 'El equipo todavía no se entrega.',
      datos: [
        ['Fecha', fechaYHora(x.fechaEntrega)],
        ['Recibió', x.nombreRecibe ?? '—'],
        ['Entregó', x.entregadoPor ?? '—'],
      ],
    },
  ]
})


// ---- Acciones sobre la orden. Los botones solo aparecen cuando el estado las permite y el rol tiene el permiso;
// aun así, la regla de verdad la aplican los procedimientos almacenados (si algo no se cumple, se ve su mensaje).
const tieneFactura = computed(() => !!e.value.idFactura)
const saldo = computed(() => Number(e.value.saldo ?? 0))
const esListo = computed(() => e.value.estado === 'LISTO')
const puedeFacturar = computed(() => esListo.value && !tieneFactura.value && auth.puede('FACTURA_EMITIR'))
const puedeCobrar = computed(() => tieneFactura.value && saldo.value > 0 && e.value.estado !== 'CANCELADO' && auth.puede('PAGO_REGISTRAR'))
const puedeEntregar = computed(() => esListo.value && auth.puede('ENTREGA_REGISTRAR'))
const entregaBloqueada = computed(() => tieneFactura.value && saldo.value > 0)
const puedeAnular = computed(() => e.value.estado !== 'ENTREGADO' && auth.puede('PAGO_REGISTRAR'))
const hayAcciones = computed(() => puedeFacturar.value || puedeCobrar.value || puedeEntregar.value)

const modal = reactive({
  facturar: false,
  pagar: false,
  entregar: false,
  anular: false,
  pago: null as { idPago: number; monto: number; metodoPago: string } | null,
})
const ordenAccion = computed(() => ({
  idOrden: id,
  numeroOrden: String(e.value.numeroOrden ?? ''),
  cliente: String(e.value.cliente ?? ''),
  nitCliente: String(e.value.nitCliente ?? ''),
}))
const facturaPago = computed(() => ({
  idFactura: Number(e.value.idFactura),
  numeroFactura: String(e.value.numeroFactura ?? ''),
  cliente: String(e.value.cliente ?? ''),
  saldo: saldo.value,
}))
function pedirAnulacion(p: Fila) {
  modal.pago = { idPago: p.idPago, monto: p.monto, metodoPago: p.metodoPago }
  modal.anular = true
}

const columnasPagos = computed<TableColumn<Fila>[]>(() => {
  const base: TableColumn<Fila>[] = [
    { accessorKey: 'fechaPago', header: 'Fecha' },
    { accessorKey: 'metodoPago', header: 'Método' },
    { accessorKey: 'monto', header: 'Monto', meta: { class: { th: 'text-right', td: 'text-right cifras' } } },
    { accessorKey: 'referencia', header: 'Referencia' },
    { accessorKey: 'estado', header: 'Estado' },
    { accessorKey: 'cajero', header: 'Cajero' },
    { accessorKey: 'motivoAnulacion', header: 'Motivo de anulación' },
  ]
  if (puedeAnular.value) base.push({ id: 'acciones', header: '', meta: { class: { th: 'no-imprimir', td: 'no-imprimir text-right' } } })
  return base
})

const imprimir = () => window.print()

function legibleRespuesta(v: string | null | undefined) {
  return v ? v[0] + v.slice(1).toLowerCase() : '—'
}

const colRepuestos: ColumnaReporte[] = [
  { clave: 'bodega', etiqueta: 'Bodega' },
  { clave: 'codigo', etiqueta: 'Código' },
  { clave: 'repuesto', etiqueta: 'Repuesto' },
  { clave: 'cantidad', etiqueta: 'Cantidad', formato: 'numero' },
  { clave: 'precioUnitario', etiqueta: 'Precio (histórico)', formato: 'moneda' },
  { clave: 'subtotal', etiqueta: 'Subtotal', formato: 'moneda' },
  { clave: 'estado', etiqueta: 'Estado', formato: 'estado' },
  { clave: 'fechaRegistro', etiqueta: 'Registrado', formato: 'fechaHora' },
  { clave: 'registradoPor', etiqueta: 'Por' },
]
const colMovimientos: ColumnaReporte[] = [
  { clave: 'fechaMovimiento', etiqueta: 'Fecha', formato: 'fechaHora' },
  { clave: 'tipo', etiqueta: 'Tipo', formato: 'estado' },
  { clave: 'origen', etiqueta: 'Origen' },
  { clave: 'bodega', etiqueta: 'Bodega' },
  { clave: 'repuesto', etiqueta: 'Repuesto' },
  { clave: 'cantidad', etiqueta: 'Cantidad', formato: 'numero' },
  { clave: 'existenciaAnterior', etiqueta: 'Antes', formato: 'numero' },
  { clave: 'existenciaResultante', etiqueta: 'Después', formato: 'numero' },
  { clave: 'usuario', etiqueta: 'Usuario' },
]
const colHistorial: ColumnaReporte[] = [
  { clave: 'fechaCambio', etiqueta: 'Fecha', formato: 'fechaHora' },
  { clave: 'estadoAnterior', etiqueta: 'De', formato: 'estado' },
  { clave: 'estadoNuevo', etiqueta: 'A', formato: 'estado' },
  { clave: 'usuario', etiqueta: 'Usuario' },
  { clave: 'observacion', etiqueta: 'Observación' },
]
</script>

<template>
  <div class="mx-auto max-w-6xl space-y-6">
    <div class="no-imprimir flex flex-wrap items-center gap-3">
      <UButton to="/ordenes" color="neutral" variant="ghost" icon="i-lucide-arrow-left">Órdenes</UButton>
      <UButton v-if="datos?.encabezado" color="secondary" icon="i-lucide-printer" class="ml-auto" @click="imprimir">
        Imprimir
      </UButton>
    </div>

    <p v-if="cargando" class="text-bruma-600" aria-live="polite">Cargando la trazabilidad…</p>

    <div v-else-if="noExiste || !datos?.encabezado" class="rounded-lg border border-bruma-200 bg-white p-6">
      <p class="font-medium">No se encontró la orden.</p>
      <p class="mt-1 text-sm text-bruma-600">Revisa el número e inténtalo de nuevo desde la lista de órdenes.</p>
    </div>

    <template v-else>
      <header class="flex flex-wrap items-center gap-3">
        <h2 class="text-2xl font-semibold tracking-tight">{{ e.numeroOrden }}</h2>
        <UBadge :color="estado.color" variant="subtle" size="lg">{{ estado.texto }}</UBadge>
        <span class="text-sm text-bruma-600">Prioridad {{ String(e.prioridad ?? '').toLowerCase() }}</span>
      </header>


      <section v-if="hayAcciones" class="no-imprimir flex flex-wrap items-center gap-2 rounded-lg border border-bruma-200 bg-white p-3" aria-label="Acciones de la orden">
        <span class="mr-1 text-sm font-medium text-bruma-600">Acciones</span>
        <UButton v-if="puedeFacturar" color="secondary" icon="i-lucide-receipt" @click="modal.facturar = true">Emitir factura</UButton>
        <UButton v-if="puedeCobrar" :color="puedeFacturar ? 'neutral' : 'secondary'" :variant="puedeFacturar ? 'outline' : 'solid'" icon="i-lucide-banknote" @click="modal.pagar = true">
          Registrar pago
        </UButton>
        <UButton
          v-if="puedeEntregar"
          color="neutral"
          variant="outline"
          icon="i-lucide-package-check"
          :disabled="entregaBloqueada"
          @click="modal.entregar = true"
        >
          Entregar equipo
        </UButton>
        <span v-if="puedeEntregar && entregaBloqueada" class="text-sm text-bruma-600">
          Para entregar falta cobrar {{ quetzales(saldo) }}.
        </span>
      </section>

      <div class="grid gap-4 md:grid-cols-2">
        <section
          v-for="et in etapas"
          :key="et.titulo"
          class="break-inside-avoid rounded-lg border bg-white p-4"
          :class="et.hecha ? 'border-bruma-200' : 'border-dashed border-bruma-300'"
        >
          <h3 class="flex items-center gap-2 font-semibold" :class="et.hecha ? '' : 'text-bruma-500'">
            {{ et.titulo }}
            <UBadge v-if="!et.hecha" color="neutral" variant="outline" size="sm">Pendiente</UBadge>
          </h3>
          <p v-if="!et.hecha" class="mt-2 text-sm text-bruma-500">{{ et.vacio }}</p>
          <dl v-else class="mt-2 space-y-1.5 text-sm">
            <div v-for="[k, v] in et.datos" :key="k" class="grid grid-cols-[9rem_minmax(0,1fr)] gap-2">
              <dt class="text-bruma-600">{{ k }}</dt>
              <dd class="cifras break-words">{{ v }}</dd>
            </div>
          </dl>
        </section>
      </div>

      <ReporteTabla titulo="Repuestos usados" :columnas="colRepuestos" :filas="datos.repuestos" vacio="No se usaron repuestos en esta orden." />
      <ReporteTabla titulo="Movimientos de inventario" :columnas="colMovimientos" :filas="datos.movimientos" vacio="Sin movimientos de inventario." />
      <section class="space-y-2">
        <h3 class="font-semibold">Pagos</h3>
        <div class="overflow-hidden rounded-lg border border-bruma-200 bg-white">
          <UTable :data="datos.pagos" :columns="columnasPagos" empty="Sin pagos registrados.">
            <template #fechaPago-cell="{ row }">{{ fechaYHora(row.original.fechaPago) }}</template>
            <template #monto-cell="{ row }">{{ quetzales(row.original.monto) }}</template>
            <template #referencia-cell="{ row }">{{ row.original.referencia ?? '—' }}</template>
            <template #estado-cell="{ row }">
              <UBadge :color="ESTADO_REGISTRO_PAGO[row.original.estado]?.color ?? 'neutral'" variant="subtle">
                {{ ESTADO_REGISTRO_PAGO[row.original.estado]?.texto ?? row.original.estado }}
              </UBadge>
            </template>
            <template #motivoAnulacion-cell="{ row }">{{ row.original.motivoAnulacion ?? '—' }}</template>
            <template #acciones-cell="{ row }">
              <UButton v-if="row.original.estado === 'APLICADO'" size="xs" color="neutral" variant="outline" icon="i-lucide-undo-2" @click="pedirAnulacion(row.original)">
                Anular
              </UButton>
            </template>
          </UTable>
        </div>
        <p class="text-sm text-bruma-600">{{ numero(datos.pagos.length) }} {{ datos.pagos.length === 1 ? 'fila' : 'filas' }}</p>
      </section>
      <ReporteTabla titulo="Historial de estados" :columnas="colHistorial" :filas="datos.historial" vacio="Sin cambios de estado." />

      <FormFacturar v-if="puedeFacturar" v-model:open="modal.facturar" :orden="ordenAccion" @hecho="cargar(true)" />
      <FormPago v-if="puedeCobrar" v-model:open="modal.pagar" :factura="facturaPago" @pagado="cargar(true)" />
      <FormEntrega v-if="puedeEntregar" v-model:open="modal.entregar" :orden="ordenAccion" @hecho="cargar(true)" />
      <FormAnularPago v-if="puedeAnular" v-model:open="modal.anular" :pago="modal.pago" @hecho="cargar(true)" />
    </template>
  </div>
</template>

<style>
/* Al imprimir solo sale el contenido: sin menú lateral, barra superior ni botones */
@media print {
  aside,
  header.sticky,
  .no-imprimir {
    display: none !important;
  }
  .min-h-dvh {
    display: block !important;
  }
  main {
    padding: 0 !important;
  }
  body {
    background: white !important;
  }
  table {
    font-size: 11px;
  }
  th,
  td {
    padding: 0.25rem 0.4rem !important;
  }
  .max-h-\[65dvh\] {
    max-height: none !important;
  }
}
</style>
