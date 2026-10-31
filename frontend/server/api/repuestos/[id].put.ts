import { editarSim } from '../../utils/simuladoCatalogos'
// API SIMULADA de PUT /repuestos/{id}
export default defineEventHandler((event) => editarSim(event, 'repuestos'))
