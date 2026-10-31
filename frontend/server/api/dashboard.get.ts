// API SIMULADA de GET /dashboard (misma forma que vw_DashboardResumen)
export default defineEventHandler((event) => {
  requerirSimulado(event)
  return {
    ordenesAbiertas: 44, recibidas: 11, enDiagnostico: 1, esperandoAutorizacion: 5, enReparacion: 4, listasParaEntregar: 23,
    facturasConSaldo: 11, saldoPorCobrar: 3550.4, repuestosBajoMinimo: 30,
  }
})
