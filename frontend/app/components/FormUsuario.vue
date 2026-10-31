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
  if (!form.username.trim()) e.username = 'Escribe el nombre de usuario.'
  else if (form.username.trim().length > 50) e.username = 'Máximo 50 caracteres.'
  if (!form.nombreCompleto.trim()) e.nombre = 'Escribe el nombre completo.'
  else if (form.nombreCompleto.trim().length > 120) e.nombre = 'Máximo 120 caracteres.'
  if (!editando.value && form.password.length < 8) e.password = 'Mínimo 8 caracteres.'
  if (editando.value && form.password && form.password.length < 8) e.password = 'Mínimo 8 caracteres (o déjala vacía para no cambiarla).'
  if (form.email.length > 120) e.email = 'Máximo 120 caracteres.'
  if (form.email.trim() && !/^\S+@\S+\.\S+$/.test(form.email.trim())) e.email = 'El correo no parece válido.'
  if (form.telefono.length > 20) e.telefono = 'Máximo 20 caracteres.'
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
          <UFormField label="Usuario" required :error="intento ? errores.username : undefined">
            <UInput v-model="form.username" maxlength="50" autocomplete="off" class="w-full" />
          </UFormField>
          <UFormField
            :label="editando ? 'Nueva contraseña' : 'Contraseña'" :required="!editando"
            :error="intento ? errores.password : undefined" :hint="editando ? 'Vacía = no cambia' : (intento && errores.password ? undefined : 'Mínimo 8')"
          >
            <UInput v-model="form.password" type="password" autocomplete="new-password" class="w-full" />
          </UFormField>
        </div>
        <UFormField label="Nombre completo" required :error="intento ? errores.nombre : undefined">
          <UInput v-model="form.nombreCompleto" maxlength="120" class="w-full" />
        </UFormField>
        <div class="grid gap-4 sm:grid-cols-2">
          <UFormField label="Correo" :error="intento ? errores.email : undefined" hint="Opcional">
            <UInput v-model="form.email" type="email" maxlength="120" class="w-full" />
          </UFormField>
          <UFormField label="Teléfono" :error="intento ? errores.telefono : undefined" hint="Opcional">
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
