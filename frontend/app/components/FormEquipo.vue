<script setup lang="ts">
/*
  Alta y edición de un equipo de un cliente (POST /equipos, PUT /equipos/{id}).
  Tipo de equipo y marca salen de catálogos (GET /tipos-equipo y GET /marcas).
*/
export type Equipo = {
  idEquipo: number
  idCliente: number
  idTipoEquipo: number
  idMarca: number
  tipoEquipo: string
  marca: string
  modelo: string
  numeroSerie: string
  descripcion: string | null
  estado: string
}
type Opcion = { label: string; value: number }

const props = defineProps<{ idCliente: number; equipo: Equipo | null }>()
const abierto = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ guardado: [] }>()

const api = useApi()
const toast = useToast()
const { alcance, sacudir } = useSacudida() // sacude el formulario y lleva el foco al primer error
const editando = computed(() => !!props.equipo)

const tipos = ref<Opcion[]>([])
const marcas = ref<Opcion[]>([])
const catalogosCargados = ref(false)
const form = reactive({
  idTipoEquipo: undefined as number | undefined,
  idMarca: undefined as number | undefined,
  modelo: '',
  numeroSerie: '',
  descripcion: '',
  estado: 'ACTIVO',
})
const guardando = ref(false)
const intento = ref(false)

async function cargarCatalogos() {
  if (catalogosCargados.value) return
  try {
    const [t, m] = await Promise.all([
      api<{ idTipoEquipo: number; nombre: string }[]>('/tipos-equipo'),
      api<{ idMarca: number; nombre: string }[]>('/marcas'),
    ])
    tipos.value = t.map((x) => ({ label: x.nombre, value: x.idTipoEquipo }))
    marcas.value = m.map((x) => ({ label: x.nombre, value: x.idMarca }))
    catalogosCargados.value = true
  } catch {
    /* sin catálogos no se puede guardar: useApi ya avisó */
  }
}

watch(abierto, (v) => {
  if (!v) return
  intento.value = false
  const e = props.equipo
  Object.assign(form, {
    idTipoEquipo: e?.idTipoEquipo,
    idMarca: e?.idMarca,
    modelo: e?.modelo ?? '',
    numeroSerie: e?.numeroSerie ?? '',
    descripcion: e?.descripcion ?? '',
    estado: e?.estado ?? 'ACTIVO',
  })
  cargarCatalogos()
})

const errores = computed(() => {
  const e: Record<string, string> = {}
  if (!form.idTipoEquipo) e.tipo = 'Elige el tipo de equipo.'
  if (!form.idMarca) e.marca = 'Elige la marca.'
  if (!form.modelo.trim()) e.modelo = 'Escribe el modelo.'
  else if (form.modelo.length > 80) e.modelo = 'Máximo 80 caracteres.'
  if (!form.numeroSerie.trim()) e.serie = 'Escribe el número de serie.'
  else if (form.numeroSerie.length > 60) e.serie = 'Máximo 60 caracteres.'
  else if (!codigoValido(form.numeroSerie)) e.serie = MENSAJE.codigo
  if (form.descripcion.length > 300) e.descripcion = 'Máximo 300 caracteres.'
  return e
})

async function guardar() {
  intento.value = true
  if (Object.keys(errores.value).length) {
    sacudir()
    return
  }
  guardando.value = true
  try {
    await api(editando.value ? `/equipos/${props.equipo!.idEquipo}` : '/equipos', {
      method: editando.value ? 'PUT' : 'POST',
      body: {
        idCliente: props.idCliente,
        idTipoEquipo: form.idTipoEquipo,
        idMarca: form.idMarca,
        modelo: form.modelo.trim(),
        numeroSerie: form.numeroSerie.trim(),
        descripcion: form.descripcion.trim() || undefined,
        estado: editando.value ? form.estado : undefined,
      },
    })
    toast.add({ title: editando.value ? 'Equipo actualizado' : 'Equipo registrado', description: `${form.modelo.trim()} · ${form.numeroSerie.trim()}`, color: 'success' })
    abierto.value = false
    emit('guardado')
  } catch {
    /* useApi mostró el mensaje (por ejemplo, un número de serie repetido) */
    sacudir(false)
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <UModal v-model:open="abierto" :title="editando ? 'Editar equipo' : 'Nuevo equipo'">
    <template #body>
      <form ref="alcance" class="space-y-4" novalidate @submit.prevent="guardar">
        <div class="grid gap-4 sm:grid-cols-2">
          <UFormField label="Tipo de equipo" required :error="intento ? errores.tipo : undefined">
            <USelect v-model="form.idTipoEquipo" :items="tipos" placeholder="Selecciona" class="w-full" />
          </UFormField>
          <UFormField label="Marca" required :error="intento ? errores.marca : undefined">
            <USelect v-model="form.idMarca" :items="marcas" placeholder="Selecciona" class="w-full" />
          </UFormField>
        </div>
        <div class="grid gap-4 sm:grid-cols-2">
          <UFormField label="Modelo" required :error="mostrar(intento, errores.modelo)" :hint="limite(form.modelo, 80)">
            <UInput v-model="form.modelo" maxlength="80" class="w-full" />
          </UFormField>
          <UFormField label="Número de serie" required :error="mostrar(intento, errores.serie, form.numeroSerie, INVALIDO.codigo)" :hint="limite(form.numeroSerie, 60, 'Sin espacios')">
            <UInput v-model="form.numeroSerie" maxlength="60" class="w-full" />
          </UFormField>
        </div>
        <UFormField label="Descripción" :error="intento ? errores.descripcion : undefined" :hint="`Opcional · ${contador(form.descripcion, 300)}`">
          <UTextarea v-model="form.descripcion" :rows="2" maxlength="300" class="w-full" />
        </UFormField>
        <UFormField v-if="editando" label="Estado">
          <USelect
            v-model="form.estado"
            :items="[{ label: 'Activo', value: 'ACTIVO' }, { label: 'Inactivo', value: 'INACTIVO' }, { label: 'Baja', value: 'BAJA' }]"
            class="w-full"
          />
        </UFormField>
        <button type="submit" class="hidden" tabindex="-1" aria-hidden="true" />
      </form>
    </template>
    <template #footer="{ close }">
      <div class="flex w-full justify-end gap-2">
        <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
        <UButton color="secondary" :loading="guardando" @click="guardar">{{ editando ? 'Guardar cambios' : 'Registrar equipo' }}</UButton>
      </div>
    </template>
  </UModal>
</template>
