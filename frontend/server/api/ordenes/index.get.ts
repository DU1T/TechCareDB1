// API SIMULADA de GET /ordenes (órdenes activas, misma forma que vw_OrdenesActivas)
const ORDENES = [
  { idOrden: 3, numeroOrden: 'OS-000003', fechaIngreso: '2026-10-24T09:30:00', prioridad: 'ALTA', estado: 'REPARACION', cliente: 'María López', tipoEquipo: 'Laptop', marca: 'Lenovo', modelo: 'ThinkPad E14', tecnicoAsignado: 'Técnico Uno', diasAbierta: 5 },
  { idOrden: 2, numeroOrden: 'OS-000002', fechaIngreso: '2026-10-26T14:10:00', prioridad: 'MEDIA', estado: 'RECIBIDO', cliente: 'Carlos Méndez', tipoEquipo: 'Celular', marca: 'Samsung', modelo: 'A54', tecnicoAsignado: null, diasAbierta: 3 },
  { idOrden: 4, numeroOrden: 'OS-000004', fechaIngreso: '2026-10-27T11:00:00', prioridad: 'URGENTE', estado: 'LISTO', cliente: 'Taller Los Pinos, S.A.', tipoEquipo: 'Impresora', marca: 'HP', modelo: 'LaserJet M404', tecnicoAsignado: 'Técnico Dos', diasAbierta: 2 },
]

export default defineEventHandler((event) => {
  requerirSimulado(event)
  const estado = getQuery(event).estado
  return ORDENES.filter((o) => !estado || o.estado === estado)
})
