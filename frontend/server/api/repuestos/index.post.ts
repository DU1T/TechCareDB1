import { crearSim } from '../../utils/simuladoCatalogos'
// API SIMULADA de POST /repuestos
export default defineEventHandler((event) => crearSim(event, 'repuestos'))
