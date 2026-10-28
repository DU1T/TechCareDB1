/*
  Menú lateral e inicio salen de esta lista.
  - permiso: si el usuario no lo tiene, el ítem no aparece
  - listo:   cámbialo a true cuando la pantalla exista; mientras tanto se muestra como "Pronto"
  C agrega aquí sus pantallas de inventario y compras con la misma forma.
*/
export type ItemMenu = {
  etiqueta: string
  descripcion: string
  ruta: string
  icono: string
  grupo: string
  permiso?: string
  listo: boolean
}

export const MENU: ItemMenu[] = [
  {
    etiqueta: 'Inicio',
    descripcion: 'Resumen del taller',
    ruta: '/',
    icono: 'i-lucide-layout-dashboard',
    grupo: 'General',
    listo: true,
  },
  {
    etiqueta: 'Clientes',
    descripcion: 'Altas, búsqueda y equipos de cada cliente',
    ruta: '/clientes',
    icono: 'i-lucide-users',
    grupo: 'Taller',
    permiso: 'CLIENTE_GESTIONAR',
    listo: false,
  },
  {
    etiqueta: 'Nueva orden',
    descripcion: 'Recibir un equipo y abrir su orden de servicio',
    ruta: '/ordenes/nueva',
    icono: 'i-lucide-clipboard-plus',
    grupo: 'Taller',
    permiso: 'ORDEN_CREAR',
    listo: false,
  },
  {
    etiqueta: 'Órdenes',
    descripcion: 'Seguimiento de diagnóstico, reparación y entrega',
    ruta: '/ordenes',
    icono: 'i-lucide-wrench',
    grupo: 'Taller',
    permiso: 'REPORTE_VER',
    listo: false,
  },
  {
    etiqueta: 'Caja',
    descripcion: 'Facturas con saldo y registro de pagos',
    ruta: '/caja',
    icono: 'i-lucide-receipt',
    grupo: 'Caja',
    permiso: 'PAGO_REGISTRAR',
    listo: false,
  },
  {
    etiqueta: 'Inventario',
    descripcion: 'Existencias por bodega, mínimos y ajustes',
    ruta: '/inventario',
    icono: 'i-lucide-boxes',
    grupo: 'Bodega',
    permiso: 'REPORTE_VER',
    listo: true,
  },
  {
    etiqueta: 'Kárdex',
    descripcion: 'Entradas y salidas de cada repuesto',
    ruta: '/inventario/kardex',
    icono: 'i-lucide-history',
    grupo: 'Bodega',
    permiso: 'REPORTE_VER',
    listo: true,
  },
  {
    etiqueta: 'Compras',
    descripcion: 'Compras a proveedores y su recepción en bodega',
    ruta: '/compras',
    icono: 'i-lucide-truck',
    grupo: 'Bodega',
    permiso: 'COMPRA_REGISTRAR',
    listo: true,
  },
  {
    etiqueta: 'Reportes',
    descripcion: 'Los 12 reportes con filtros',
    ruta: '/reportes',
    icono: 'i-lucide-chart-no-axes-column',
    grupo: 'Análisis',
    permiso: 'REPORTE_VER',
    listo: true,
  },
  {
    etiqueta: 'Usuarios',
    descripcion: 'Cuentas y roles del personal',
    ruta: '/admin/usuarios',
    icono: 'i-lucide-user-cog',
    grupo: 'Administración',
    permiso: 'USUARIO_GESTIONAR',
    listo: false,
  },
  {
    etiqueta: 'Catálogos',
    descripcion: 'Repuestos, proveedores y bodegas',
    ruta: '/admin/catalogos',
    icono: 'i-lucide-package',
    grupo: 'Administración',
    permiso: 'CATALOGO_GESTIONAR',
    listo: false,
  },
]
