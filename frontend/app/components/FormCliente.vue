<script setup lang="ts">
/*
  Alta y edición de un cliente (POST /clientes, PUT /clientes/{id}). Las reglas de la API se repiten aquí
  solo para avisar antes: tipo, NIT y nombre obligatorios, empresa con NIT distinto de CF, y teléfono o correo.
*/
export type Cliente = {
  idCliente: number
  tipoCliente: string
  nit: string
  nombre: string
  telefono: string | null
  email: string | null
  direccion: string | null
  estado: string
}

const props = defineProps<{ cliente: Cliente | null }>()
const abierto = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ guardado: [c: { idCliente: number; nombre: string }] }>()

const api = useApi()
const toast = useToast()
const { alcance, sacudir } = useSacudida() // sacude el formulario y lleva el foco al primer error
const editando = computed(() => !!props.cliente)

const form = reactive({ tipoCliente: 'INDIVIDUAL', nit: '', nombre: '', telefono: '', email: '', direccion: '', estado: 'ACTIVO' })
const guardando = ref(false)
const intento = ref(false)

watch(abierto, (v) => {
  if (!v) return
  intento.value = false
  const c = props.cliente
  Object.assign(form, {
    tipoCliente: c?.tipoCliente ?? 'INDIVIDUAL',
    nit: c?.nit ?? '',
    nombre: c?.nombre ?? '',
    telefono: c?.telefono ?? '',
    email: c?.email ?? '',
    direccion: c?.direccion ?? '',
    estado: c?.estado ?? 'ACTIVO',
  })
})

const errores = computed(() => {
  const e: Record<string, string> = {}
  const nit = form.nit.trim()
  if (!nit) e.nit = 'Escribe el NIT (o CF).'
  else if (nit.length > 15) e.nit = 'Máximo 15 caracteres.'
  else if (!nitValido(nit)) e.nit = MENSAJE.nit
  else if (form.tipoCliente === 'EMPRESA' && nit.toUpperCase() === 'CF') e.nit = 'Una empresa debe tener un NIT distinto de CF.'
  if (!form.nombre.trim()) e.nombre = 'Escribe el nombre.'
  else if (form.nombre.length > 150) e.nombre = 'Máximo 150 caracteres.'
  if (!form.telefono.trim() && !form.email.trim()) e.contacto = 'Indica un teléfono o un correo.'
  if (form.telefono.length > 20) e.telefono = 'Máximo 20 caracteres.'
  else if (!telefonoValido(form.telefono)) e.telefono = MENSAJE.telefono
  if (form.email.length > 120) e.email = 'Máximo 120 caracteres.'
  if (form.email.trim() && !/^\S+@\S+\.\S+$/.test(form.email.trim())) e.email = 'El correo no parece válido.'
  if (form.direccion.length > 250) e.direccion = 'Máximo 250 caracteres.'
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
    const r = await api<{ idCliente: number; nombre: string }>(editando.value ? `/clientes/${props.cliente!.idCliente}` : '/clientes', {
      method: editando.value ? 'PUT' : 'POST',
      body: {
        tipoCliente: form.tipoCliente,
        nit: form.nit.trim(),
        nombre: form.nombre.trim(),
        telefono: form.telefono.trim() || undefined,
        email: form.email.trim() || undefined,
        direccion: form.direccion.trim() || undefined,
        estado: editando.value ? form.estado : undefined,
      },
    })
    toast.add({ title: editando.value ? 'Cliente actualizado' : 'Cliente registrado', description: r.nombre, color: 'success' })
    abierto.value = false
    emit('guardado', r)
  } catch {
    /* useApi mostró el mensaje (por ejemplo, un NIT que ya existe) */
    sacudir(false)
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <UModal v-model:open="abierto" :title="editando ? 'Editar cliente' : 'Nuevo cliente'">
    <template #body>
      <form ref="alcance" class="space-y-4" novalidate @submit.prevent="guardar">
        <div class="grid gap-4 sm:grid-cols-2">
          <UFormField label="Tipo de cliente" required>
            <USelect
              v-model="form.tipoCliente"
              :items="[{ label: 'Individual', value: 'INDIVIDUAL' }, { label: 'Empresa', value: 'EMPRESA' }]"
              class="w-full"
            />
          </UFormField>
          <UFormField label="NIT" required :error="intento ? errores.nit : undefined" hint="CF si no tiene">
            <UInput v-model="form.nit" maxlength="15" class="w-full" />
          </UFormField>
        </div>
        <UFormField label="Nombre" required :error="intento ? errores.nombre : undefined">
          <UInput v-model="form.nombre" maxlength="150" class="w-full" />
        </UFormField>
        <div class="grid gap-4 sm:grid-cols-2">
          <UFormField label="Teléfono" :error="intento ? (errores.telefono ?? errores.contacto) : undefined">
            <UInput v-model="form.telefono" maxlength="20" inputmode="tel" class="w-full" />
          </UFormField>
          <UFormField label="Correo" :error="intento ? errores.email : undefined" hint="Teléfono o correo">
            <UInput v-model="form.email" type="email" maxlength="120" class="w-full" />
          </UFormField>
        </div>
        <UFormField label="Dirección" :error="intento ? errores.direccion : undefined">
          <UInput v-model="form.direccion" maxlength="250" class="w-full" />
        </UFormField>
        <UFormField v-if="editando" label="Estado">
          <USelect v-model="form.estado" :items="[{ label: 'Activo', value: 'ACTIVO' }, { label: 'Inactivo', value: 'INACTIVO' }]" class="w-full" />
        </UFormField>
        <button type="submit" class="hidden" tabindex="-1" aria-hidden="true" />
      </form>
    </template>
    <template #footer="{ close }">
      <div class="flex w-full justify-end gap-2">
        <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
        <UButton color="secondary" :loading="guardando" @click="guardar">{{ editando ? 'Guardar cambios' : 'Registrar cliente' }}</UButton>
      </div>
    </template>
  </UModal>
</template>
