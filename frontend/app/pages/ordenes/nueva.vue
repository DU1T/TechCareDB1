<script setup lang="ts">
import type { Cliente } from '~/components/FormCliente.vue'
import type { Equipo } from '~/components/FormEquipo.vue'

/*
  Nueva orden de servicio: se elige el cliente, luego uno de sus equipos activos, y se describe el problema.
  POST /ordenes devuelve {idOrden, numeroOrden}; al terminar se abre la trazabilidad de la orden nueva.
  Se puede llegar con ?cliente= y ?equipo= desde la ficha del cliente.
*/
definePageMeta({ titulo: 'Nueva orden', permiso: 'ORDEN_CREAR' })

const api = useApi()
const auth = useAuthStore()
const toast = useToast()
const route = useRoute()
const { alcance, sacudir } = useSacudida() // si el formulario no pasa o la API rechaza: se sacude y el foco va al primer error

const buscar = ref('')
const resultados = ref<Cliente[]>([])
const buscando = ref(false)
const esqueletoBusqueda = useEsqueleto(buscando)
const lista = ref<HTMLElement | null>(null)
useReacomodo(lista, () => resultados.value, { selector: 'li' }) // los resultados se acomodan al buscar
const cliente = ref<Cliente | null>(null)
const equipos = ref<Equipo[]>([])
const modalCliente = ref(false)
const modalEquipo = ref(false)

const form = reactive({
  idEquipo: undefined as number | undefined,
  problemaReportado: '',
  prioridad: 'MEDIA',
  fechaEstimada: '',
  observaciones: '',
})
const intento = ref(false)
const guardando = ref(false)
const hoy = new Date().toISOString().slice(0, 10)

const prioridades = [
  { label: 'Baja', value: 'BAJA' },
  { label: 'Media', value: 'MEDIA' },
  { label: 'Alta', value: 'ALTA' },
  { label: 'Urgente', value: 'URGENTE' },
]
const equiposActivos = computed(() =>
  equipos.value.filter((e) => e.estado === 'ACTIVO').map((e) => ({ label: `${e.tipoEquipo} · ${e.marca} ${e.modelo} (${e.numeroSerie})`, value: e.idEquipo })),
)

// Si dos búsquedas se cruzan (escribes "a" y luego "ab"), solo vale la última que se pidió
let pedido = 0
async function buscarClientes() {
  const mio = ++pedido
  buscando.value = true
  try {
    const r = (await api<Cliente[]>('/clientes', { query: { buscar: buscar.value.trim() || undefined } })).filter((c) => c.estado === 'ACTIVO')
    if (mio === pedido) resultados.value = r
  } catch {
    if (mio === pedido) resultados.value = []
  } finally {
    if (mio === pedido) buscando.value = false
  }
}
let espera: ReturnType<typeof setTimeout> | undefined
watch(buscar, () => {
  clearTimeout(espera)
  espera = setTimeout(buscarClientes, 300)
})
onBeforeUnmount(() => clearTimeout(espera))

async function elegirCliente(c: Cliente, idEquipo?: number) {
  cliente.value = c
  form.idEquipo = undefined
  try {
    equipos.value = await api<Equipo[]>(`/clientes/${c.idCliente}/equipos`)
  } catch {
    equipos.value = []
  }
  if (idEquipo && equipos.value.some((e) => e.idEquipo === idEquipo && e.estado === 'ACTIVO')) form.idEquipo = idEquipo
}
function cambiarCliente() {
  cliente.value = null
  equipos.value = []
  form.idEquipo = undefined
  buscarClientes()
}

onMounted(async () => {
  const idCliente = Number(route.query.cliente)
  if (idCliente) {
    try {
      await elegirCliente(await api<Cliente>(`/clientes/${idCliente}`), Number(route.query.equipo) || undefined)
      return
    } catch { /* si no se encuentra, se muestra la búsqueda */ }
  }
  buscarClientes()
})

async function clienteNuevo(c: { idCliente: number }) {
  try {
    await elegirCliente(await api<Cliente>(`/clientes/${c.idCliente}`))
  } catch { /* useApi avisó */ }
}

const errores = computed(() => {
  const e: Record<string, string> = {}
  if (!form.idEquipo) e.equipo = 'Elige el equipo que ingresa.'
  if (!form.problemaReportado.trim()) e.problema = 'Describe el problema reportado.'
  else if (form.problemaReportado.length > 500) e.problema = 'Máximo 500 caracteres.'
  if (form.fechaEstimada && form.fechaEstimada < hoy) e.fecha = 'La fecha estimada no puede ser anterior a hoy.'
  if (form.observaciones.length > 500) e.observaciones = 'Máximo 500 caracteres.'
  return e
})

async function crear() {
  intento.value = true
  if (Object.keys(errores.value).length) {
    sacudir()
    return
  }
  guardando.value = true
  try {
    const r = await api<{ idOrden: number; numeroOrden: string }>('/ordenes', {
      method: 'POST',
      body: {
        idEquipo: form.idEquipo,
        problemaReportado: form.problemaReportado.trim(),
        prioridad: form.prioridad,
        fechaEstimada: form.fechaEstimada || undefined,
        observaciones: form.observaciones.trim() || undefined,
      },
    })
    toast.add({ title: 'Orden creada', description: `Se abrió la orden ${r.numeroOrden}.`, color: 'success' })
    await navigateTo(`/ordenes/${r.idOrden}/trazabilidad`)
  } catch {
    /* useApi mostró el mensaje de la API */
    sacudir(false)
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-3xl space-y-5">
    <section class="entra rounded-lg border border-bruma-200 bg-white p-5" style="--i: 0">
      <h2 class="mb-3 flex items-center gap-2.5 font-semibold text-highlighted">
        <!-- El círculo del paso pasa a ✓ (con un pequeño rebote) cuando ya hay cliente -->
        <Motion
          :key="cliente ? 'hecho' : 'pendiente'"
          class="grid size-6 place-items-center rounded-full text-xs"
          :class="cliente ? 'bg-placa-600 text-white' : 'border-2 border-placa-600 text-placa-700'"
          :initial="{ scale: 0.6 }"
          :animate="{ scale: 1 }"
          :transition="RESORTE"
        >
          <UIcon v-if="cliente" name="i-lucide-check" class="size-3.5" />
          <span v-else class="cifras" aria-hidden="true">1</span>
        </Motion>
        <span class="sr-only">Paso 1:</span>Cliente
      </h2>

      <Transition name="aparece" mode="out-in">
      <div v-if="cliente" key="elegido" class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <p class="font-medium text-highlighted">{{ cliente.nombre }}</p>
          <p class="text-sm text-bruma-500">NIT {{ cliente.nit }} · {{ cliente.telefono ?? cliente.email ?? 'sin contacto' }}</p>
        </div>
        <UButton size="sm" color="neutral" variant="outline" @click="cambiarCliente">Cambiar cliente</UButton>
      </div>

      <div v-else key="buscar" class="space-y-3">
        <div class="flex flex-wrap items-end gap-3">
          <UFormField label="Buscar cliente" class="w-full sm:w-80">
            <UInput v-model="buscar" icon="i-lucide-search" placeholder="Nombre o NIT" class="w-full" />
          </UFormField>
          <UButton v-if="auth.puede('CLIENTE_GESTIONAR')" color="neutral" variant="outline" icon="i-lucide-plus" @click="modalCliente = true">Cliente nuevo</UButton>
        </div>
        <!-- Buscando sin resultados todavía: en blanco un instante y cajas grises solo si tarda -->
        <div v-if="buscando && !resultados.length" class="space-y-2 transition-opacity duration-300" :class="esqueletoBusqueda ? 'opacity-100' : 'opacity-0'" aria-hidden="true">
          <USkeleton v-for="i in 3" :key="i" class="h-10" />
        </div>
        <p v-else-if="!resultados.length" class="text-sm text-bruma-500">No hay clientes activos con esa búsqueda.</p>
        <!-- Mientras se busca de nuevo, los resultados anteriores quedan atenuados (no desaparecen y reaparecen) -->
        <ul v-else ref="lista" class="divide-y divide-bruma-100 rounded-lg border border-bruma-200 transition-opacity duration-200" :class="buscando ? 'opacity-60' : ''">
          <li v-for="c in resultados" :key="c.idCliente">
            <button type="button" class="flex w-full items-center justify-between px-3 py-2 text-left transition-colors hover:bg-bruma-50 motion-reduce:transition-none" @click="elegirCliente(c)">
              <span class="font-medium text-highlighted">{{ c.nombre }}</span>
              <span class="text-sm text-bruma-500">NIT {{ c.nit }}</span>
            </button>
          </li>
        </ul>
        <span class="sr-only" role="status">{{ buscando ? 'Buscando…' : '' }}</span>
      </div>
      </Transition>
    </section>

    <Transition name="paso">
    <form v-if="cliente" ref="alcance" class="space-y-4 rounded-lg border border-bruma-200 bg-white p-5" novalidate @submit.prevent="crear">
      <h2 class="flex items-center gap-2.5 font-semibold text-highlighted">
        <span class="grid size-6 place-items-center rounded-full border-2 border-placa-600 text-xs text-placa-700" aria-hidden="true"><span class="cifras">2</span></span>
        <span class="sr-only">Paso 2:</span>Equipo y problema
      </h2>

      <div class="flex flex-wrap items-end gap-3">
        <UFormField label="Equipo" required :error="intento ? errores.equipo : undefined" class="w-full sm:flex-1">
          <USelect v-model="form.idEquipo" :items="equiposActivos" placeholder="Selecciona un equipo" class="w-full" />
        </UFormField>
        <UButton color="neutral" variant="outline" icon="i-lucide-plus" @click="modalEquipo = true">Equipo nuevo</UButton>
      </div>
      <p v-if="!equiposActivos.length" class="text-sm text-bruma-500">Este cliente no tiene equipos activos. Registra uno con «Equipo nuevo».</p>

      <UFormField label="Problema reportado" required :error="intento ? errores.problema : undefined">
        <UTextarea v-model="form.problemaReportado" :rows="3" maxlength="500" class="w-full" />
      </UFormField>

      <div class="grid gap-4 sm:grid-cols-2">
        <UFormField label="Prioridad" required>
          <USelect v-model="form.prioridad" :items="prioridades" class="w-full" />
        </UFormField>
        <UFormField label="Fecha estimada de entrega" :error="intento ? errores.fecha : undefined" hint="Opcional">
          <UInput v-model="form.fechaEstimada" type="date" :min="hoy" class="w-full" />
        </UFormField>
      </div>

      <UFormField label="Observaciones" :error="intento ? errores.observaciones : undefined" hint="Estado físico, accesorios que deja, etc.">
        <UTextarea v-model="form.observaciones" :rows="2" maxlength="500" class="w-full" />
      </UFormField>

      <div class="flex justify-end">
        <UButton type="submit" color="secondary" icon="i-lucide-clipboard-plus" :loading="guardando">Abrir orden</UButton>
      </div>
    </form>
    </Transition>

    <FormCliente v-model:open="modalCliente" :cliente="null" @guardado="clienteNuevo" />
    <FormEquipo v-if="cliente" v-model:open="modalEquipo" :id-cliente="cliente.idCliente" :equipo="null" @guardado="elegirCliente(cliente!)" />
  </div>
</template>
