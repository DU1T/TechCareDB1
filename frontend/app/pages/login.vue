<script setup lang="ts">
import { z } from 'zod'

definePageMeta({ layout: 'blank' })
useHead({ title: 'Iniciar sesión · TechCare' })

const auth = useAuthStore()
const config = useRuntimeConfig()
const modoSimulado = computed(() => config.public.modoSimulado === true)

const schema = z.object({
  username: z.string().trim().min(1, 'Escribe tu usuario').max(LIMITE.usuario, `Máximo ${LIMITE.usuario} caracteres`),
  password: z.string().min(1, 'Escribe tu contraseña').max(LIMITE.passwordMax, `Máximo ${LIMITE.passwordMax} caracteres`),
})

const state = reactive({ username: '', password: '' })
const verClave = ref(false)
const cargando = ref(false)
const exito = ref(false)
const error = ref('')

// Lo que muestra la escena del panel verde (components/login/EscenaTaller.vue)
const fase = computed(() => (exito.value ? 'listo' : cargando.value ? 'leyendo' : 'espera'))

// Error: el formulario da una sacudida corta (como un "no" con la cabeza). Sin ella si se pidió reducir movimiento
const reducido = useReducedMotion()
const [alcance, animar] = useAnimate()
// Pausas de la escena; con "reducir movimiento" no se espera nada
const esperar = (ms: number) => new Promise((r) => setTimeout(r, reducido.value ? 0 : ms))
function sacudir() {
  if (!reducido.value && alcance.value) animar(alcance.value, { x: [0, -10, 9, -6, 4, 0] }, { duration: 0.42, ease: 'easeOut' })
}

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
    // El escáner de la etiqueta se ve al menos 450 ms aunque la API responda antes (corren a la vez)
    await Promise.all([auth.login(state.username.trim(), state.password), esperar(450)])
    // Un momento para ver el sello "Autorizado" antes de pasar al sistema
    exito.value = true
    await esperar(600)
    await navigateTo('/')
  } catch (e: any) {
    // Solo es "sin conexión" si la petición no obtuvo respuesta; un fallo nuestro no se disfraza de red
    error.value = e?.response
      ? (typeof e.data?.error === 'string' ? e.data.error : 'No se pudo iniciar sesión.')
      : e?.name === 'FetchError'
        ? 'No hay conexión con el servidor. Revisa que la API esté encendida.'
        : 'La respuesta del servidor no tiene el formato esperado.'
    sacudir()
  } finally {
    cargando.value = false
  }
}
</script>

<template>
  <div class="grid min-h-dvh lg:grid-cols-[minmax(0,5fr)_minmax(0,4fr)]">
    <!-- 30 %: panel de marca con la escena de la etiqueta de servicio (solo en pantallas anchas) -->
    <LoginEscenaTaller :fase="fase" />

    <!-- 60 %: formulario sobre fondo neutro. "entra" + --i: cada bloque llega un poco después del anterior -->
    <section class="flex items-center justify-center px-6 py-12">
      <div ref="alcance" class="w-full max-w-sm">
        <div class="entra mb-10 flex items-center gap-2.5 lg:hidden" style="--i: 0">
          <span class="grid size-8 place-items-center rounded-md bg-placa-900 font-bold text-acento-500">T</span>
          <span class="text-xl font-semibold tracking-tight">TechCare</span>
        </div>

        <div class="entra" style="--i: 1">
          <h1 class="text-2xl font-semibold tracking-tight">Iniciar sesión</h1>
          <p class="mt-1 text-sm text-bruma-600">Entra con tu usuario del taller.</p>
        </div>

        <!-- Sin validar al salir del campo: si no, el error aparece, la página se mueve y se pierde el clic -->
        <UForm
          :schema="schema"
          :state="state"
          :validate-on="['change', 'input']"
          class="mt-8 space-y-5"
          @submit="entrar"
        >
          <UFormField label="Usuario" name="username" class="entra" style="--i: 2">
            <UInput v-model="state.username" size="lg" :maxlength="LIMITE.usuario" class="w-full" autocomplete="username" autofocus />
          </UFormField>

          <UFormField label="Contraseña" name="password" class="entra" style="--i: 3">
            <UInput
              v-model="state.password"
              :type="verClave ? 'text' : 'password'"
              :maxlength="LIMITE.passwordMax"
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
            <Transition name="aparece">
              <UAlert v-if="error" color="error" variant="subtle" icon="i-lucide-circle-alert" :description="error" />
            </Transition>
          </div>

          <UButton
            type="submit"
            color="secondary"
            size="lg"
            block
            class="entra"
            style="--i: 4"
            :loading="cargando && !exito"
            :icon="exito ? 'i-lucide-check' : undefined"
          >
            {{ exito ? 'Listo' : 'Iniciar sesión' }}
          </UButton>
        </UForm>

        <div v-if="modoSimulado" class="entra mt-8 rounded-lg border border-bruma-200 bg-white p-4" style="--i: 5">
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
