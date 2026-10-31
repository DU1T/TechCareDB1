<script setup lang="ts">
/*
  Cajas grises con la forma de una tabla, para el slot #loading de <UTable> (se muestra cuando no hay filas y está cargando).
  `visible` viene de useEsqueleto: la primera fracción de segundo queda en blanco y las cajas aparecen con un
  fundido solo si la carga se alarga (así no parpadean cuando la API responde rápido). El alto ya está reservado,
  de modo que al llegar los datos no se mueve nada.

    <UTable :loading="cargando" …>
      <template #loading><TablaEsqueleto :visible="esqueleto" :columnas="4" /></template>
    </UTable>
*/
const props = withDefaults(defineProps<{ visible: boolean; filas?: number; columnas?: number }>(), { filas: 5, columnas: 4 })

// Anchos distintos por fila y columna para que no parezca una rejilla de plantilla (siempre los mismos)
const ancho = (fila: number, col: number) => (col === 1 ? 38 + ((fila * 7) % 22) : 55 + ((fila * 13 + col * 9) % 40))
</script>

<template>
  <div class="space-y-5 px-4 py-4 transition-opacity duration-300 motion-reduce:transition-none" :class="visible ? 'opacity-100' : 'opacity-0'" aria-hidden="true">
    <div v-for="f in props.filas" :key="f" class="flex items-center gap-6">
      <USkeleton v-for="c in props.columnas" :key="c" class="h-4" :style="{ width: `${ancho(f, c)}%` }" />
    </div>
  </div>
  <span v-if="visible" class="sr-only" role="status">Cargando…</span>
</template>
