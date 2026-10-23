import type { H3Event } from 'h3'

/*
  Los endpoints de server/api son una API SIMULADA. Se compilan dentro del build,
  así que cada uno debe llamar a esto primero: si el modo simulado está apagado
  (producción por defecto), responden 404 como si no existieran.
*/
export function requerirSimulado(event: H3Event) {
  if (useRuntimeConfig(event).public.modoSimulado !== true) {
    throw createError({ statusCode: 404, statusMessage: 'Not Found' })
  }
}
