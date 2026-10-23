<script setup lang="ts">
import { z } from 'zod'

definePageMeta({ layout: 'blank' })
useHead({ title: 'Iniciar sesión · TechCare' })

const auth = useAuthStore()
const config = useRuntimeConfig()
const modoSimulado = computed(() => String(config.public.apiBase).startsWith('/'))

const schema = z.object({
  username: z.string().trim().min(1, 'Escribe tu usuario'),
  password: z.string().min(1, 'Escribe tu contraseña'),
})

const state = reactive({ username: '', password: '' })
const verClave = ref(false)
const cargando = ref(false)
const error = ref('')

// Solo en modo simulado: atajos para probar cada rol
const PRUEBA = [
  { rol: 'Recepción', usuario: 'recepcion1' },
  { rol: 'Técnico', usuario: 'tecnico1' },
  { rol: 'Bodega', usuario: 'bodega1' },
  { rol: 'Caja', usuario: 'caja1' },
  { rol: 'Administrador', usuario: 'administrador1' },
]
function rellenar(usuario: string) {
  state.username = usuario
  state.password = 'Demo2026!'
  error.value = ''
}

async function entrar() {
  error.value = ''
  cargando.value = true
  try {
    await auth.login(state.username.trim(), state.password)
    await navigateTo('/')
  } catch (e: any) {
    error.value = e?.response
      ? (e.data?.error ?? 'No se pudo iniciar sesión.')
      : 'No hay conexión con el servidor. Revisa que la API esté encendida.'
  } finally {
    cargando.value = false
  }
}
</script>

<template>
  <div class="grid min-h-dvh lg:grid-cols-[minmax(0,5fr)_minmax(0,4fr)]">
    <!-- 30 %: panel de marca con la etiqueta de servicio -->
    <section
      class="relative hidden overflow-hidden bg-placa-900 p-12 text-placa-50 lg:flex lg:flex-col lg:justify-between"
      aria-hidden="true"
    >
      <div class="flex items-center gap-2.5">
        <span class="grid size-8 place-items-center rounded-md bg-acento-500 font-bold text-bruma-950">T</span>
        <span class="text-xl font-semibold tracking-tight text-white">TechCare</span>
      </div>

      <div class="etiqueta-servicio mx-auto w-full max-w-sm overflow-hidden rounded-xl bg-bruma-50 text-bruma-900 shadow-2xl shadow-placa-950/50">
        <div class="relative bg-acento-500 px-6 pb-4 pt-7 text-bruma-950">
          <span class="absolute left-1/2 top-2.5 size-3 -translate-x-1/2 rounded-full bg-placa-900" />
          <p class="text-sm font-medium">Orden de servicio</p>
          <p class="cifras mt-0.5 text-3xl font-bold tracking-tight">OS-000142</p>
        </div>
        <div class="space-y-3 px-6 py-5">
          <div>
            <p class="text-xs text-bruma-500">Equipo</p>
            <p class="font-medium">Laptop 15 pulgadas, no enciende</p>
          </div>
          <div>
            <p class="text-xs text-bruma-500">Estado</p>
            <p class="font-medium">Listo para entregar</p>
          </div>
        </div>
        <div class="mx-4 border-t-2 border-dashed border-bruma-300" />
        <div class="codigo-barras mx-6 my-5 h-10 opacity-90" />
      </div>

      <p class="max-w-sm text-placa-200">
        Recepción, taller, bodega y caja trabajan sobre la misma orden.
      </p>
    </section>

    <!-- 60 %: formulario sobre fondo neutro -->
    <section class="flex items-center justify-center px-6 py-12">
      <div class="w-full max-w-sm">
        <div class="mb-10 flex items-center gap-2.5 lg:hidden">
          <span class="grid size-8 place-items-center rounded-md bg-placa-900 font-bold text-acento-500">T</span>
          <span class="text-xl font-semibold tracking-tight">TechCare</span>
        </div>

        <h1 class="text-2xl font-semibold tracking-tight">Iniciar sesión</h1>
        <p class="mt-1 text-sm text-bruma-600">Entra con tu usuario del taller.</p>

        <!-- Sin validar al salir del campo: si no, el error aparece, la página se mueve y se pierde el clic -->
        <UForm
          :schema="schema"
          :state="state"
          :validate-on="['change', 'input']"
          class="mt-8 space-y-5"
          @submit="entrar"
        >
          <UFormField label="Usuario" name="username">
            <UInput v-model="state.username" size="lg" class="w-full" autocomplete="username" autofocus />
          </UFormField>

          <UFormField label="Contraseña" name="password">
            <UInput
              v-model="state.password"
              :type="verClave ? 'text' : 'password'"
              size="lg"
              class="w-full"
              autocomplete="current-password"
            >
              <template #trailing>
                <UButton
                  color="neutral"
                  variant="link"
                  size="sm"
                  :icon="verClave ? 'i-lucide-eye-off' : 'i-lucide-eye'"
                  :aria-label="verClave ? 'Ocultar contraseña' : 'Mostrar contraseña'"
                  @click="verClave = !verClave"
                />
              </template>
            </UInput>
          </UFormField>

          <div aria-live="polite">
            <UAlert v-if="error" color="error" variant="subtle" icon="i-lucide-circle-alert" :description="error" />
          </div>

          <UButton type="submit" color="secondary" size="lg" block :loading="cargando">Iniciar sesión</UButton>
        </UForm>

        <div v-if="modoSimulado" class="mt-8 rounded-lg border border-bruma-200 bg-white p-4">
          <p class="text-sm font-medium">Modo simulado</p>
          <p class="mt-0.5 text-sm text-bruma-600">Elige un rol para rellenar el formulario. La contraseña es Demo2026!</p>
          <div class="mt-3 flex flex-wrap gap-2">
            <UButton
              v-for="p in PRUEBA"
              :key="p.usuario"
              size="xs"
              color="neutral"
              variant="outline"
              @click="rellenar(p.usuario)"
            >
              {{ p.rol }}
            </UButton>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>
