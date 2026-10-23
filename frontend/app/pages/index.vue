<script setup lang="ts">
// Inicio es para cualquier usuario con sesión: es el destino al que el middleware manda
// a quien no tiene permiso, así que NO debe pedir uno (si no, se forma un bucle).
definePageMeta({ titulo: 'Inicio' })

const auth = useAuthStore()

const primerNombre = computed(() => auth.usuario?.nombreCompleto.split(' ')[0] ?? '')
const accesos = computed(() =>
  MENU.filter((i) => i.ruta !== '/' && (!i.permiso || auth.puede(i.permiso))),
)
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <h2 class="text-2xl font-semibold tracking-tight">Hola, {{ primerNombre }}</h2>
    <p class="mt-1 text-bruma-600">Estos son los módulos que tu rol puede usar.</p>

    <ul class="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <li v-for="a in accesos" :key="a.ruta">
        <NuxtLink
          v-if="a.listo"
          :to="a.ruta"
          class="flex h-full gap-3 rounded-lg border border-bruma-200 bg-white p-4 transition-colors hover:border-placa-300 motion-reduce:transition-none"
        >
          <span class="grid size-9 shrink-0 place-items-center rounded-md bg-placa-50 text-placa-600">
            <UIcon :name="a.icono" class="size-5" />
          </span>
          <span>
            <span class="block font-medium">{{ a.etiqueta }}</span>
            <span class="mt-0.5 block text-sm text-bruma-600">{{ a.descripcion }}</span>
          </span>
        </NuxtLink>

        <div v-else class="flex h-full gap-3 rounded-lg border border-dashed border-bruma-300 p-4" aria-disabled="true">
          <span class="grid size-9 shrink-0 place-items-center rounded-md bg-bruma-200 text-bruma-500">
            <UIcon :name="a.icono" class="size-5" />
          </span>
          <span>
            <span class="block font-medium text-bruma-600">{{ a.etiqueta }}</span>
            <span class="mt-0.5 block text-sm text-bruma-500">{{ a.descripcion }}</span>
            <span class="mt-1.5 block text-xs text-bruma-500">Disponible pronto</span>
          </span>
        </div>
      </li>
    </ul>
  </div>
</template>
