import { crearSim } from '../utils/simuladoCatalogos'
// API SIMULADA de POST /tipos-equipo
export default defineEventHandler((event) => crearSim(event, 'tipos-equipo'))
