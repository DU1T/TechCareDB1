import { crearSim } from '../../utils/simuladoCatalogos'
// API SIMULADA de POST /bodegas
export default defineEventHandler((event) => crearSim(event, 'bodegas'))
