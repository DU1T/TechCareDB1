<script setup lang="ts">
/*
  Acciones del taller sobre una orden (C). Va en /ordenes/[id]/trazabilidad, encima de las de caja.
  Cada botón aparece solo si el estado de la orden lo permite y el rol tiene el permiso; aun así,
  la regla de verdad la aplica el procedimiento (si algo no se cumple, useApi muestra su mensaje).
    Registrar diagnóstico  POST /ordenes/{id}/diagnostico      sp_RegistrarDiagnostico        DIAGNOSTICO_REGISTRAR
    Respuesta del cliente  POST /ordenes/{id}/autorizacion     sp_RegistrarAutorizacionCliente ORDEN_CAMBIAR_ESTADO
    Iniciar reparación     POST /ordenes/{id}/reparacion       sp_IniciarReparacion           REPARACION_GESTIONAR
    Agregar actividad      POST /reparaciones/{id}/actividades sp_RegistrarActividad          REPARACION_GESTIONAR
    Usar repuesto          POST /reparaciones/{id}/repuestos   sp_UtilizarRepuesto            REPUESTO_CONSUMIR
    Finalizar reparación   POST /reparaciones/{id}/finalizar   sp_FinalizarReparacion         REPARACION_GESTIONAR
  Los identificadores (diagnóstico, reparación) salen de GET /ordenes/{id}.
*/
type Orden = {
  idOrden: number
  numeroOrden: string
  estado: string
  idDiagnostico: number | null
  diagnostico: string | null
  costoManoObraEstimado: number | null
  autorizado: boolean | null
  idReparacion: number | null
  estadoReparacion: string | null
}
type Existencia = {
  idBodega: number
  codigoBodega: string
  idRepuesto: number
  codigo: string
  repuesto: string
  existencia: number
  precioVenta: number
}

// estado: el de la página; si cambia (la página recargó), se vuelve a pedir el detalle
const props = defineProps<{ idOrden: number; estado?: string }>()
const emit = defineEmits<{ hecho: [] }>()

const api = useApi()
const auth = useAuthStore()
const toast = useToast()

const orden = ref<Orden | null>(null)
async function cargar() {
  try {
    const r = await api<{ orden: Orden }>(`/ordenes/${props.idOrden}`)
    orden.value = r.orden
  } catch {
    orden.value = null
  }
}
onMounted(cargar)
watch(() => props.estado, cargar)

const o = computed(() => orden.value)
const enProceso = computed(() => o.value?.estado === 'REPARACION' && o.value.estadoReparacion === 'EN_PROCESO' && !!o.value.idReparacion)
const puedeDiagnosticar = computed(
  () => !!o.value && !o.value.idDiagnostico && ['RECIBIDO', 'DIAGNOSTICO'].includes(o.value.estado) && auth.puede('DIAGNOSTICO_REGISTRAR'),
)
const puedeResponder = computed(
  () => o.value?.estado === 'ESPERANDO_AUTORIZACION' && !!o.value.idDiagnostico && o.value.autorizado == null && auth.puede('ORDEN_CAMBIAR_ESTADO'),
)
const puedeIniciar = computed(
  () => o.value?.estado === 'ESPERANDO_AUTORIZACION' && o.value.autorizado === true && !o.value.idReparacion && auth.puede('REPARACION_GESTIONAR'),
)
const puedeGestionar = computed(() => enProceso.value && auth.puede('REPARACION_GESTIONAR'))
const puedeRepuesto = computed(() => enProceso.value && auth.puede('REPUESTO_CONSUMIR'))
const hayAcciones = computed(
  () => puedeDiagnosticar.value || puedeResponder.value || puedeIniciar.value || puedeGestionar.value || puedeRepuesto.value,
)

const abierto = reactive({ diagnostico: false, respuesta: false, actividad: false, repuesto: false, finalizar: false })
const guardando = ref(false)
const intento = ref(false)

// Ejecuta una acción: si sale bien avisa, cierra el formulario y recarga; si falla, useApi ya mostró el motivo
async function ejecutar(ruta: string, body: Record<string, unknown> | undefined, aviso: string, cerrar?: keyof typeof abierto) {
  guardando.value = true
  try {
    await api(ruta, { method: 'POST', body: body ?? {} })
    toast.add({ title: aviso, description: o.value?.numeroOrden, color: 'success' })
    if (cerrar) abierto[cerrar] = false
    await cargar()
    emit('hecho')
  } catch {
    /* mensaje del procedimiento ya mostrado */
  } finally {
    guardando.value = false
  }
}

// ---- Diagnóstico
const diag = reactive({ descripcion: '', costo: 0 as number | undefined })
const errDiag = computed(() => ({
  descripcion: !diag.descripcion.trim() ? 'Describe el diagnóstico.' : diag.descripcion.length > 1000 ? 'Máximo 1000 caracteres.' : '',
  costo: diag.costo == null || diag.costo < 0 || diag.costo > LIMITE.montoMax ? MENSAJE.monto : '',
}))
function abrirDiagnostico() {
  Object.assign(diag, { descripcion: '', costo: 0 })
  intento.value = false
  abierto.diagnostico = true
}
function guardarDiagnostico() {
  intento.value = true
  if (Object.values(errDiag.value).some(Boolean)) return
  ejecutar(`/ordenes/${props.idOrden}/diagnostico`, { descripcion: diag.descripcion.trim(), costoManoObraEstimado: diag.costo }, 'Diagnóstico registrado', 'diagnostico')
}

// ---- Respuesta del cliente
function responder(autorizado: boolean) {
  ejecutar(`/ordenes/${props.idOrden}/autorizacion`, { autorizado }, autorizado ? 'El cliente autorizó la reparación' : 'El cliente rechazó la reparación', 'respuesta')
}

// ---- Iniciar reparación
function iniciar() {
  ejecutar(`/ordenes/${props.idOrden}/reparacion`, undefined, 'Reparación iniciada')
}

// ---- Actividad
const act = reactive({ descripcion: '', horas: 1 as number | undefined })
const errAct = computed(() => ({
  descripcion: !act.descripcion.trim() ? 'Describe la actividad.' : act.descripcion.length > 300 ? 'Máximo 300 caracteres.' : '',
  horas: act.horas == null || act.horas <= 0 || act.horas > 24 ? 'Entre 0.25 y 24 horas.' : '',
}))
function abrirActividad() {
  Object.assign(act, { descripcion: '', horas: 1 })
  intento.value = false
  abierto.actividad = true
}
function guardarActividad() {
  intento.value = true
  if (Object.values(errAct.value).some(Boolean)) return
  ejecutar(`/reparaciones/${o.value!.idReparacion}/actividades`, { descripcion: act.descripcion.trim(), horas: act.horas }, 'Actividad registrada', 'actividad')
}

// ---- Repuesto: solo se ofrecen existencias mayores que cero; la API vuelve a validar el stock (R06/R10)
const existencias = ref<Existencia[]>([])
const rep = reactive({ clave: undefined as string | undefined, cantidad: 1 as number | undefined })
const opcionesRepuesto = computed(() =>
  existencias.value
    .filter((x) => x.existencia > 0)
    .map((x) => ({
      value: `${x.idBodega}-${x.idRepuesto}`,
      label: `${x.codigo} · ${x.repuesto} · ${x.codigoBodega} (hay ${x.existencia})`,
    })),
)
const elegido = computed(() => existencias.value.find((x) => `${x.idBodega}-${x.idRepuesto}` === rep.clave))
const errRep = computed(() => ({
  repuesto: !elegido.value ? 'Elige el repuesto y la bodega.' : '',
  cantidad:
    rep.cantidad == null || rep.cantidad < 1 ? 'La cantidad debe ser mayor que cero.'
    : rep.cantidad > LIMITE.cantidadMax ? MENSAJE.cantidad
    : elegido.value && rep.cantidad > elegido.value.existencia ? `Solo hay ${elegido.value.existencia} en esa bodega.` : '',
}))
async function abrirRepuesto() {
  Object.assign(rep, { clave: undefined, cantidad: 1 })
  intento.value = false
  abierto.repuesto = true
  try {
    existencias.value = await api<Existencia[]>('/inventario')
  } catch {
    existencias.value = []
  }
}
function guardarRepuesto() {
  intento.value = true
  if (Object.values(errRep.value).some(Boolean) || !elegido.value) return
  ejecutar(
    `/reparaciones/${o.value!.idReparacion}/repuestos`,
    { idBodega: elegido.value.idBodega, idRepuesto: elegido.value.idRepuesto, cantidad: rep.cantidad },
    `Se usaron ${rep.cantidad} × ${elegido.value.codigo}`,
    'repuesto',
  )
}

// ---- Finalizar
const fin = reactive({ descripcion: '', costo: 0 as number | undefined })
const errFin = computed(() => ({
  descripcion: !fin.descripcion.trim() ? 'Describe el trabajo realizado.' : fin.descripcion.length > 1000 ? 'Máximo 1000 caracteres.' : '',
  costo: fin.costo == null || fin.costo < 0 || fin.costo > LIMITE.montoMax ? MENSAJE.monto : '',
}))
function abrirFinalizar() {
  Object.assign(fin, { descripcion: '', costo: Number(o.value?.costoManoObraEstimado ?? 0) })
  intento.value = false
  abierto.finalizar = true
}
function guardarFinalizar() {
  intento.value = true
  if (Object.values(errFin.value).some(Boolean)) return
  ejecutar(`/reparaciones/${o.value!.idReparacion}/finalizar`, { descripcionTrabajo: fin.descripcion.trim(), costoManoObra: fin.costo }, 'Reparación finalizada: la orden queda lista', 'finalizar')
}

const err = (msg: string) => (intento.value && msg ? msg : undefined)
</script>

<template>
  <section
    v-if="hayAcciones"
    class="no-imprimir flex flex-wrap items-center gap-2 rounded-lg border border-bruma-200 bg-white p-3"
    aria-label="Acciones del taller"
  >
    <span class="mr-1 text-sm font-medium text-bruma-600">Taller</span>
    <UButton v-if="puedeDiagnosticar" color="secondary" icon="i-lucide-stethoscope" @click="abrirDiagnostico">Registrar diagnóstico</UButton>
    <UButton v-if="puedeResponder" color="secondary" icon="i-lucide-message-circle-question" @click="abierto.respuesta = true">Respuesta del cliente</UButton>
    <UButton v-if="puedeIniciar" color="secondary" icon="i-lucide-wrench" :loading="guardando" @click="iniciar">Iniciar reparación</UButton>
    <UButton v-if="puedeRepuesto" color="secondary" icon="i-lucide-package-minus" @click="abrirRepuesto">Usar repuesto</UButton>
    <UButton v-if="puedeGestionar" color="neutral" variant="outline" icon="i-lucide-list-plus" @click="abrirActividad">Agregar actividad</UButton>
    <UButton v-if="puedeGestionar" color="neutral" variant="outline" icon="i-lucide-circle-check" @click="abrirFinalizar">Finalizar reparación</UButton>
  </section>

  <!-- Diagnóstico -->
  <UModal v-model:open="abierto.diagnostico" title="Registrar diagnóstico">
    <template #body>
      <form class="space-y-4" novalidate @submit.prevent="guardarDiagnostico">
        <p class="text-sm text-bruma-600">La orden pasa a <strong>Esperando autorización</strong> del cliente.</p>
        <UFormField label="Diagnóstico" required :error="err(errDiag.descripcion)" :hint="contador(diag.descripcion, 1000)">
          <UTextarea v-model="diag.descripcion" :rows="4" maxlength="1000" class="w-full" />
        </UFormField>
        <UFormField label="Mano de obra estimada (Q)" required :error="err(errDiag.costo)">
          <UInputNumber v-model="diag.costo" :min="0" :max="LIMITE.montoMax" :step="0.01" :format-options="{ minimumFractionDigits: 2 }" class="w-full" />
        </UFormField>
        <button type="submit" class="hidden" tabindex="-1" aria-hidden="true" />
      </form>
    </template>
    <template #footer="{ close }">
      <div class="flex w-full justify-end gap-2">
        <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
        <UButton color="secondary" icon="i-lucide-stethoscope" :loading="guardando" @click="guardarDiagnostico">Guardar diagnóstico</UButton>
      </div>
    </template>
  </UModal>

  <!-- Respuesta del cliente -->
  <UModal v-model:open="abierto.respuesta" title="Respuesta del cliente">
    <template #body>
      <div v-if="o" class="space-y-3 text-sm">
        <p class="text-bruma-600">{{ o.diagnostico }}</p>
        <p>Mano de obra estimada: <strong class="text-highlighted">{{ quetzales(o.costoManoObraEstimado) }}</strong></p>
        <p class="text-bruma-600">Si autoriza, el técnico puede iniciar la reparación. Si rechaza, la orden queda lista para devolver el equipo.</p>
      </div>
    </template>
    <template #footer="{ close }">
      <div class="flex w-full justify-end gap-2">
        <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
        <UButton color="error" variant="outline" icon="i-lucide-x" :loading="guardando" @click="responder(false)">Rechaza</UButton>
        <UButton color="secondary" icon="i-lucide-check" :loading="guardando" @click="responder(true)">Autoriza</UButton>
      </div>
    </template>
  </UModal>

  <!-- Actividad -->
  <UModal v-model:open="abierto.actividad" title="Agregar actividad">
    <template #body>
      <form class="space-y-4" novalidate @submit.prevent="guardarActividad">
        <UFormField label="Actividad realizada" required :error="err(errAct.descripcion)" :hint="contador(act.descripcion, 300)">
          <UTextarea v-model="act.descripcion" :rows="3" maxlength="300" class="w-full" />
        </UFormField>
        <UFormField label="Horas" required :error="err(errAct.horas)">
          <UInputNumber v-model="act.horas" :min="0.25" :max="24" :step="0.25" class="w-full" />
        </UFormField>
        <button type="submit" class="hidden" tabindex="-1" aria-hidden="true" />
      </form>
    </template>
    <template #footer="{ close }">
      <div class="flex w-full justify-end gap-2">
        <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
        <UButton color="secondary" icon="i-lucide-list-plus" :loading="guardando" @click="guardarActividad">Agregar</UButton>
      </div>
    </template>
  </UModal>

  <!-- Repuesto -->
  <UModal v-model:open="abierto.repuesto" title="Usar repuesto">
    <template #body>
      <form class="space-y-4" novalidate @submit.prevent="guardarRepuesto">
        <p class="text-sm text-bruma-600">Se descuenta de la bodega elegida y queda en el kárdex con el precio de hoy.</p>
        <UFormField label="Repuesto y bodega" required :error="err(errRep.repuesto)">
          <USelectMenu
            v-model="rep.clave"
            :items="opcionesRepuesto"
            value-key="value"
            placeholder="Buscar repuesto"
            :search-input="{ placeholder: 'Código, nombre o bodega' }"
            class="w-full"
          />
        </UFormField>
        <p v-if="elegido" class="text-sm text-bruma-600">
          Precio de venta: <strong class="text-highlighted">{{ quetzales(elegido.precioVenta) }}</strong> · disponible: {{ elegido.existencia }}
        </p>
        <UFormField label="Cantidad" required :error="err(errRep.cantidad)">
          <UInputNumber v-model="rep.cantidad" :min="1" :max="LIMITE.cantidadMax" class="w-full" />
        </UFormField>
        <button type="submit" class="hidden" tabindex="-1" aria-hidden="true" />
      </form>
    </template>
    <template #footer="{ close }">
      <div class="flex w-full justify-end gap-2">
        <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
        <UButton color="secondary" icon="i-lucide-package-minus" :loading="guardando" @click="guardarRepuesto">Usar repuesto</UButton>
      </div>
    </template>
  </UModal>

  <!-- Finalizar -->
  <UModal v-model:open="abierto.finalizar" title="Finalizar reparación">
    <template #body>
      <form class="space-y-4" novalidate @submit.prevent="guardarFinalizar">
        <p class="text-sm text-bruma-600">La orden queda <strong>Lista para entregar</strong> y se puede facturar.</p>
        <UFormField label="Trabajo realizado" required :error="err(errFin.descripcion)" :hint="contador(fin.descripcion, 1000)">
          <UTextarea v-model="fin.descripcion" :rows="4" maxlength="1000" class="w-full" />
        </UFormField>
        <UFormField label="Mano de obra (Q)" required :error="err(errFin.costo)">
          <UInputNumber v-model="fin.costo" :min="0" :max="LIMITE.montoMax" :step="0.01" :format-options="{ minimumFractionDigits: 2 }" class="w-full" />
        </UFormField>
        <button type="submit" class="hidden" tabindex="-1" aria-hidden="true" />
      </form>
    </template>
    <template #footer="{ close }">
      <div class="flex w-full justify-end gap-2">
        <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
        <UButton color="secondary" icon="i-lucide-circle-check" :loading="guardando" @click="guardarFinalizar">Finalizar</UButton>
      </div>
    </template>
  </UModal>
</template>
