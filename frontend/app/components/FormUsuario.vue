<script setup lang="ts">
/*
  Alta y edición de un usuario (POST /usuarios, PUT /usuarios/{id}). Los roles salen de GET /roles.
  En la edición la contraseña es opcional: si se deja vacía, no cambia.
*/
export type Usuario = {
  idUsuario: number
  username: string
  nombreCompleto: string
  email: string | null
  telefono: string | null
  estado: string
  fechaCreacion: string
  roles: { idRol: number; nombre: string }[]
}

const props = defineProps<{ usuario: Usuario | null }>()
const abierto = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ guardado: [] }>()

const api = useApi()
const auth = useAuthStore()
const toast = useToast()
const { alcance, sacudir } = useSacudida() // sacude el formulario y lleva el foco al primer error
const editando = computed(() => !!props.usuario)
const esYo = computed(() => props.usuario?.idUsuario === auth.usuario?.idUsuario)

const roles = ref<{ idRol: number; nombre: string; descripcion: string }[]>([])
const form = reactive({ username: '', password: '', nombreCompleto: '', email: '', telefono: '', estado: 'ACTIVO', idRoles: [] as number[] })
const guardando = ref(false)
const intento = ref(false)

async function cargarRoles() {
  if (roles.value.length) return
  try {
    roles.value = await api('/roles')
  } catch {
    /* useApi ya avisó */
  }
}

watch(abierto, (v) => {
  if (!v) return
  intento.value = false
  const u = props.usuario
  Object.assign(form, {
    username: u?.username ?? '',
    password: '',
    nombreCompleto: u?.nombreCompleto ?? '',
    email: u?.email ?? '',
    telefono: u?.telefono ?? '',
    estado: u?.estado ?? 'ACTIVO',
    idRoles: u ? u.roles.map((r) => r.idRol) : [],
  })
  cargarRoles()
})

function alternarRol(id: number) {
  form.idRoles = form.idRoles.includes(id) ? form.idRoles.filter((x) => x !== id) : [...form.idRoles, id]
}

const errores = computed(() => {
  const e: Record<string, string> = {}
  const eu = errorUsuario(form.username)
  if (eu) e.username = eu
  const en = errorNombre(form.nombreCompleto, 120)
  if (en) e.nombre = en === 'Escribe el nombre.' ? 'Escribe el nombre completo.' : en
  // En la edición, vacía = no cambia; si se escribe algo, cumple las mismas reglas
  const ep = !editando.value || form.password ? errorPassword(form.password) : ''
  if (ep) e.password = editando.value ? `${ep} (o déjala vacía para no cambiarla)` : ep
  if (form.email.length > 120) e.email = 'Máximo 120 caracteres.'
  if (!emailValido(form.email)) e.email = MENSAJE.email
  if (form.telefono.length > 20) e.telefono = 'Máximo 20 caracteres.'
  else if (!telefonoValido(form.telefono)) e.telefono = MENSAJE.telefono
  if (!form.idRoles.length) e.roles = 'Asigna al menos un rol.'
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
    await api(editando.value ? `/usuarios/${props.usuario!.idUsuario}` : '/usuarios', {
      method: editando.value ? 'PUT' : 'POST',
      body: {
        username: form.username.trim(),
        password: form.password || undefined,
        nombreCompleto: form.nombreCompleto.trim(),
        email: form.email.trim() || undefined,
        telefono: form.telefono.trim() || undefined,
        estado: editando.value ? form.estado : undefined,
        idRoles: form.idRoles,
      },
    })
    toast.add({ title: editando.value ? 'Usuario actualizado' : 'Usuario creado', description: form.username.trim(), color: 'success' })
    abierto.value = false
    emit('guardado')
  } catch {
    /* useApi mostró el mensaje de la API */
    sacudir(false)
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <UModal v-model:open="abierto" :title="editando ? 'Editar usuario' : 'Nuevo usuario'">
    <template #body>
      <form ref="alcance" class="space-y-4" novalidate autocomplete="off" @submit.prevent="guardar">
        <div class="grid gap-4 sm:grid-cols-2">
          <UFormField label="Usuario" required :error="mostrar(intento, errores.username, form.username, /\s|[^A-Za-z0-9._-]/)" :hint="limite(form.username, LIMITE.usuario, 'Sin espacios ni tildes')">
            <UInput v-model="form.username" :maxlength="LIMITE.usuario" autocomplete="off" class="w-full" />
          </UFormField>
          <UFormField
            :label="editando ? 'Nueva contraseña' : 'Contraseña'" :required="!editando"
            :error="mostrar(intento, errores.password)" :hint="editando ? 'Vacía = no cambia' : (intento && errores.password ? undefined : '8+, letra y número')"
          >
            <UInput v-model="form.password" type="password" :maxlength="LIMITE.passwordMax" autocomplete="new-password" class="w-full" />
          </UFormField>
        </div>
        <UFormField label="Nombre completo" required :error="mostrar(intento, errores.nombre, form.nombreCompleto, INVALIDO.nombre)" :hint="limite(form.nombreCompleto, 120)">
          <UInput v-model="form.nombreCompleto" maxlength="120" class="w-full" />
        </UFormField>
        <div class="grid gap-4 sm:grid-cols-2">
          <UFormField label="Correo" :error="mostrar(intento, errores.email, form.email, /\s/)" :hint="limite(form.email, 120, 'Opcional')">
            <UInput v-model="form.email" type="email" maxlength="120" class="w-full" />
          </UFormField>
          <UFormField label="Teléfono" :error="mostrar(intento, errores.telefono, form.telefono, INVALIDO.telefono)" hint="Opcional · ej. 5555-0101">
            <UInput v-model="form.telefono" maxlength="20" inputmode="tel" class="w-full" />
          </UFormField>
        </div>

        <fieldset>
          <legend class="mb-1.5 text-sm font-medium text-highlighted">Roles <span class="text-error">*</span></legend>
          <div class="grid gap-2 sm:grid-cols-2">
            <label
              v-for="r in roles" :key="r.idRol"
              class="flex cursor-pointer items-start gap-2 rounded-md border border-bruma-200 p-2 text-sm hover:bg-bruma-50"
            >
              <UCheckbox :model-value="form.idRoles.includes(r.idRol)" @update:model-value="alternarRol(r.idRol)" />
              <span><span class="block font-medium">{{ r.nombre }}</span><span class="block text-xs text-bruma-500">{{ r.descripcion }}</span></span>
            </label>
          </div>
          <p v-if="intento && errores.roles" class="mt-1 text-xs text-error">{{ errores.roles }}</p>
        </fieldset>

        <UFormField v-if="editando" label="Estado" :hint="esYo ? 'No puedes desactivar tu propio usuario' : undefined">
          <USelect
            v-model="form.estado" :disabled="esYo" class="w-full"
            :items="[{ label: 'Activo', value: 'ACTIVO' }, { label: 'Inactivo', value: 'INACTIVO' }]"
          />
        </UFormField>
        <button type="submit" class="hidden" tabindex="-1" aria-hidden="true" />
      </form>
    </template>
    <template #footer="{ close }">
      <div class="flex w-full justify-end gap-2">
        <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
        <UButton color="secondary" :loading="guardando" @click="guardar">{{ editando ? 'Guardar cambios' : 'Crear usuario' }}</UButton>
      </div>
    </template>
  </UModal>
</template>
