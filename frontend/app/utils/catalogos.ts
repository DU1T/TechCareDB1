/*
  Descripción de los seis catálogos que se mantienen en /admin/catalogos.
  Las mismas reglas de longitud que valida la API (MantenimientosController) se repiten aquí solo para avisar antes.
  Los precios se cambian con PUT normal: el trigger de auditoría del repuesto deja el registro del cambio.
*/
export type CampoCatalogo = {
  clave: string
  etiqueta: string
  tipo: 'texto' | 'area' | 'dinero' | 'categoria'
  max?: number
  obligatorio?: boolean
}
export type DefCatalogo = {
  clave: string
  titulo: string
  singular: string
  ruta: string // GET (lista) y POST; el PUT es ruta/{id}
  id: string // nombre de la columna id en la lista
  campos: CampoCatalogo[]
  estados?: { activo: string; inactivo: string }
}

export const MANT_CATALOGOS: DefCatalogo[] = [
  {
    clave: 'repuestos', titulo: 'Repuestos', singular: 'repuesto', ruta: '/repuestos', id: 'idRepuesto',
    estados: { activo: 'ACTIVO', inactivo: 'INACTIVO' },
    campos: [
      { clave: 'codigo', etiqueta: 'Código', tipo: 'texto', max: 30, obligatorio: true },
      { clave: 'nombre', etiqueta: 'Nombre', tipo: 'texto', max: 120, obligatorio: true },
      { clave: 'idCategoria', etiqueta: 'Categoría', tipo: 'categoria', obligatorio: true },
      { clave: 'precioCompraRef', etiqueta: 'Precio de compra (Q)', tipo: 'dinero', obligatorio: true },
      { clave: 'precioVenta', etiqueta: 'Precio de venta (Q)', tipo: 'dinero', obligatorio: true },
      { clave: 'descripcion', etiqueta: 'Descripción', tipo: 'area', max: 300 },
    ],
  },
  {
    clave: 'proveedores', titulo: 'Proveedores', singular: 'proveedor', ruta: '/proveedores', id: 'idProveedor',
    estados: { activo: 'ACTIVO', inactivo: 'INACTIVO' },
    campos: [
      { clave: 'nit', etiqueta: 'NIT', tipo: 'texto', max: 15, obligatorio: true },
      { clave: 'nombre', etiqueta: 'Nombre', tipo: 'texto', max: 150, obligatorio: true },
      { clave: 'contacto', etiqueta: 'Contacto', tipo: 'texto', max: 120 },
      { clave: 'telefono', etiqueta: 'Teléfono', tipo: 'texto', max: 20 },
      { clave: 'email', etiqueta: 'Correo', tipo: 'texto', max: 120 },
      { clave: 'direccion', etiqueta: 'Dirección', tipo: 'texto', max: 250 },
    ],
  },
  {
    clave: 'bodegas', titulo: 'Bodegas', singular: 'bodega', ruta: '/bodegas', id: 'idBodega',
    estados: { activo: 'ACTIVA', inactivo: 'INACTIVA' },
    campos: [
      { clave: 'codigo', etiqueta: 'Código', tipo: 'texto', max: 10, obligatorio: true },
      { clave: 'nombre', etiqueta: 'Nombre', tipo: 'texto', max: 80, obligatorio: true },
      { clave: 'ubicacion', etiqueta: 'Ubicación', tipo: 'texto', max: 200 },
    ],
  },
  {
    clave: 'categorias', titulo: 'Categorías', singular: 'categoría', ruta: '/categorias', id: 'idCategoria',
    campos: [{ clave: 'nombre', etiqueta: 'Nombre', tipo: 'texto', max: 60, obligatorio: true }],
  },
  {
    clave: 'tipos', titulo: 'Tipos de equipo', singular: 'tipo de equipo', ruta: '/tipos-equipo', id: 'idTipoEquipo',
    campos: [{ clave: 'nombre', etiqueta: 'Nombre', tipo: 'texto', max: 50, obligatorio: true }],
  },
  {
    clave: 'marcas', titulo: 'Marcas', singular: 'marca', ruta: '/marcas', id: 'idMarca',
    campos: [{ clave: 'nombre', etiqueta: 'Nombre', tipo: 'texto', max: 50, obligatorio: true }],
  },
]
