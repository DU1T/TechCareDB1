#!/usr/bin/env python3
"""
Prueba de punta a punta de TechCare por la API REAL (no toca la base compartida).

Recorre: seguridad por rol, clientes y equipos, orden, diagnóstico, autorización, reparación,
repuestos (con y sin stock), factura, pagos parciales y excedido, entrega, compras y recepción,
usuarios, catálogos, auditoría de precio, dashboard y los 12 reportes.

Uso:  python backend/pruebas/prueba_api_e2e.py [URL_BASE] [CLAVE]
      URL_BASE por omisión http://localhost:5199 ; CLAVE por omisión Demo2026!
La API debe estar conectada a una base de PRUEBA (TechCare_<algo>): la prueba crea datos.
Termina con código 1 si algo falla.
"""
import json, sys, urllib.request, urllib.error, urllib.parse, random, datetime

BASE = (sys.argv[1] if len(sys.argv) > 1 else 'http://localhost:5199').rstrip('/')
CLAVE = sys.argv[2] if len(sys.argv) > 2 else 'Demo2026!'
API = BASE + '/api'
ok = fallas = 0
SUFIJO = str(random.randint(100000, 999999))


def req(metodo, ruta, token=None, cuerpo=None):
    datos = None if cuerpo is None else json.dumps(cuerpo).encode('utf-8')
    r = urllib.request.Request(API + ruta, data=datos, method=metodo)
    r.add_header('Content-Type', 'application/json')
    if token:
        r.add_header('Authorization', 'Bearer ' + token)
    try:
        with urllib.request.urlopen(r, timeout=60) as resp:
            texto = resp.read().decode('utf-8')
            return resp.status, (json.loads(texto) if texto else None)
    except urllib.error.HTTPError as e:
        texto = e.read().decode('utf-8')
        try:
            return e.code, json.loads(texto)
        except Exception:
            return e.code, texto


def chk(nombre, cond, info=''):
    global ok, fallas
    if cond:
        ok += 1
        print(f'  OK     {nombre}')
    else:
        fallas += 1
        print(f'  FALLA  {nombre}   {str(info)[:300]}')


def seccion(t):
    print(f'\n== {t}')


def buscar(d, clave):
    """Primer valor de la clave (sin distinguir mayúsculas) en un JSON anidado."""
    if isinstance(d, dict):
        for k, v in d.items():
            if k.lower() == clave.lower():
                return v
        for v in d.values():
            r = buscar(v, clave)
            if r is not None:
                return r
    elif isinstance(d, list):
        for v in d:
            r = buscar(v, clave)
            if r is not None:
                return r
    return None


def login(usuario, clave=CLAVE):
    s, d = req('POST', '/auth/login', None, {'username': usuario, 'password': clave})
    return d.get('token') if s == 200 and isinstance(d, dict) else None


# ---------------------------------------------------------------- 1. seguridad
seccion('1. Seguridad y roles')
T = {u: login(u) for u in ['administrador1', 'recepcion1', 'tecnico1', 'bodega1', 'caja1']}
chk('los 5 roles inician sesión', all(T.values()), {k: bool(v) for k, v in T.items()})
chk('clave incorrecta -> 401', req('POST', '/auth/login', None, {'username': 'recepcion1', 'password': 'mala'})[0] == 401)
chk('sin token -> 401', req('GET', '/ordenes')[0] == 401)
chk('token falso -> 401', req('GET', '/ordenes', 'abc.def.ghi')[0] == 401)
chk('bodega no crea clientes -> 403', req('POST', '/clientes', T['bodega1'], {'tipoCliente': 'INDIVIDUAL', 'nit': 'CF', 'nombre': 'Prueba E2E', 'telefono': '22334455'})[0] == 403)
chk('caja no crea órdenes -> 403', req('POST', '/ordenes', T['caja1'], {'idEquipo': 1, 'problemaReportado': 'x', 'prioridad': 'BAJA'})[0] == 403)
chk('recepción no ve usuarios -> 403', req('GET', '/usuarios', T['recepcion1'])[0] == 403)
chk('técnico no factura -> 403', req('POST', '/ordenes/1/factura', T['tecnico1'], {})[0] == 403)

# ---------------------------------------------------------------- 2. clientes y equipos (T01)
seccion('2. Clientes y equipos (T01)')
s, tipos = req('GET', '/tipos-equipo', T['recepcion1'])
s2, marcas = req('GET', '/marcas', T['recepcion1'])
chk('catálogos de tipos y marcas', s == 200 and s2 == 200 and len(tipos) >= 8 and len(marcas) >= 13, (s, s2))
nit = f'9{SUFIJO}-1'   # formato de NIT válido: dígitos, guion y dígito verificador
s, cli = req('POST', '/clientes', T['recepcion1'], {'tipoCliente': 'EMPRESA', 'nit': nit, 'nombre': f'Cliente E2E {SUFIJO} Ñandú', 'telefono': '22334455', 'email': 'e2e@prueba.test', 'direccion': 'Zona 4'})
idc = buscar(cli, 'idCliente')
chk('crear cliente empresa', s == 200 and idc, (s, cli))
sd, dd = req('POST', '/clientes', T['recepcion1'], {'tipoCliente': 'EMPRESA', 'nit': nit, 'nombre': 'otro', 'telefono': '22334455'})
chk('NIT repetido -> 409 con mensaje claro', sd == 409 and 'NIT' in str(dd), (sd, dd))
chk('empresa con NIT CF -> 400', req('POST', '/clientes', T['recepcion1'], {'tipoCliente': 'EMPRESA', 'nit': 'CF', 'nombre': 'otro', 'telefono': '22334455'})[0] == 400)
chk('cliente sin contacto -> 400', req('POST', '/clientes', T['recepcion1'], {'tipoCliente': 'INDIVIDUAL', 'nit': 'CF', 'nombre': 'sin contacto'})[0] == 400)
equipos = []
for i, (t, m) in enumerate([(1, 1), (3, 2)]):
    s, e = req('POST', '/equipos', T['recepcion1'], {'idCliente': idc, 'idTipoEquipo': t, 'idMarca': m, 'modelo': f'Modelo {i}', 'numeroSerie': f'E2E-{SUFIJO}-{i}', 'descripcion': 'prueba'})
    equipos.append(buscar(e, 'idEquipo'))
chk('crear 2 equipos', all(equipos), equipos)
sd, dd = req('POST', '/equipos', T['recepcion1'], {'idCliente': idc, 'idTipoEquipo': 1, 'idMarca': 1, 'modelo': 'x', 'numeroSerie': f'E2E-{SUFIJO}-0'})
chk('serie repetida -> 409 con mensaje claro', sd == 409 and 'serie' in str(dd), (sd, dd))
s, lista = req('GET', f'/clientes/{idc}/equipos', T['recepcion1'])
chk('el cliente tiene sus 2 equipos', s == 200 and len(lista) == 2, lista)
s, busq = req('GET', '/clientes?buscar=' + urllib.parse.quote(f'E2E {SUFIJO}'), T['recepcion1'])
chk('búsqueda de clientes por nombre', s == 200 and len(busq) == 1, busq)
s, ed = req('PUT', f'/clientes/{idc}', T['recepcion1'], {'tipoCliente': 'EMPRESA', 'nit': nit, 'nombre': f'Cliente E2E {SUFIJO} Ñandú', 'telefono': '99998888', 'email': 'e2e@prueba.test', 'direccion': 'Zona 4', 'estado': 'ACTIVO'})
chk('editar cliente', s == 200, (s, ed))

# ---------------------------------------------------------------- 3. orden (T02)
seccion('3. Orden de servicio (T02)')
mañana = (datetime.date.today() + datetime.timedelta(days=7)).isoformat()
s, o = req('POST', '/ordenes', T['recepcion1'], {'idEquipo': equipos[0], 'problemaReportado': 'No enciende; huele a quemado. Ñandú "prueba".', 'prioridad': 'ALTA', 'fechaEstimada': mañana, 'observaciones': 'deja cargador'})
ido = buscar(o, 'idOrden')
chk('crear orden', s == 200 and ido, (s, o))
s, d = req('GET', f'/ordenes/{ido}', T['recepcion1'])
chk('estado inicial RECIBIDO, prioridad ALTA', s == 200 and buscar(d, 'estado') == 'RECIBIDO' and buscar(d, 'prioridad') == 'ALTA', d)
chk('orden con prioridad inválida -> 400/409', req('POST', '/ordenes', T['recepcion1'], {'idEquipo': equipos[1], 'problemaReportado': 'x', 'prioridad': 'LOQUESEA'})[0] in (400, 409))
chk('orden con equipo inexistente -> 4xx', req('POST', '/ordenes', T['recepcion1'], {'idEquipo': 999999, 'problemaReportado': 'x', 'prioridad': 'BAJA'})[0] in (400, 404, 409))

# ---------------------------------------------------------------- 4. diagnóstico, autorización, reparación
seccion('4. Diagnóstico, autorización y reparación (T03)')
chk('recepción no diagnostica -> 403', req('POST', f'/ordenes/{ido}/diagnostico', T['recepcion1'], {'descripcion': 'x', 'costoManoObraEstimado': 10})[0] == 403)
chk('no se repara sin diagnóstico (R06)', req('POST', f'/ordenes/{ido}/reparacion', T['tecnico1'])[0] in (400, 409))
s, d = req('POST', f'/ordenes/{ido}/diagnostico', T['tecnico1'], {'descripcion': 'Fuente de poder dañada por sobrevoltaje.', 'costoManoObraEstimado': 250})
chk('diagnóstico -> ESPERANDO_AUTORIZACION', s == 200 and buscar(d, 'estado') == 'ESPERANDO_AUTORIZACION', (s, d))
chk('costo de mano de obra negativo -> 4xx', req('POST', f'/ordenes/{ido}/diagnostico', T['tecnico1'], {'descripcion': 'x', 'costoManoObraEstimado': -5})[0] in (400, 409))
s, d = req('POST', f'/ordenes/{ido}/autorizacion', T['recepcion1'], {'autorizado': True})
chk('cliente autoriza', s == 200, (s, d))
s, d = req('POST', f'/ordenes/{ido}/reparacion', T['tecnico1'])
idr = buscar(d, 'idReparacion')
chk('iniciar reparación', s == 200 and idr, (s, d))

# ---------------------------------------------------------------- 5. repuestos (T04, T05)
seccion('5. Repuestos: sin stock y con stock (T04, T05)')
s, inv = req('GET', '/inventario', T['tecnico1'])
con_stock = [r for r in inv if r['existencia'] >= 5 and r['estado'] == 'ACTIVO'] if inv and 'estado' in inv[0] else [r for r in inv if r['existencia'] >= 5]
sin_stock = [r for r in inv if r['existencia'] == 0]
chk('el inventario tiene filas con y sin stock', s == 200 and con_stock and sin_stock, (s, len(inv) if inv else inv))
r1 = con_stock[0]
antes = r1['existencia']
chk('repuesto sin stock rechazado (409)', req('POST', f'/reparaciones/{idr}/repuestos', T['tecnico1'], {'idBodega': sin_stock[0]['idBodega'], 'idRepuesto': sin_stock[0]['idRepuesto'], 'cantidad': 1})[0] == 409)
chk('cantidad mayor que la existencia rechazada (409)', req('POST', f'/reparaciones/{idr}/repuestos', T['tecnico1'], {'idBodega': r1['idBodega'], 'idRepuesto': r1['idRepuesto'], 'cantidad': antes + 100})[0] == 409)
chk('cantidad 0 rechazada', req('POST', f'/reparaciones/{idr}/repuestos', T['tecnico1'], {'idBodega': r1['idBodega'], 'idRepuesto': r1['idRepuesto'], 'cantidad': 0})[0] in (400, 409))
chk('repuesto inexistente rechazado', req('POST', f'/reparaciones/{idr}/repuestos', T['tecnico1'], {'idBodega': r1['idBodega'], 'idRepuesto': 999999, 'cantidad': 1})[0] in (400, 404, 409))
s, inv2 = req('GET', f'/inventario?idBodega={r1["idBodega"]}', T['tecnico1'])
ex = [r for r in inv2 if r['idRepuesto'] == r1['idRepuesto']][0]['existencia']
chk('los rechazos no dejaron cambios en el inventario', ex == antes, (ex, antes))
chk('bodega no usa repuestos en reparación -> 403', req('POST', f'/reparaciones/{idr}/repuestos', T['bodega1'], {'idBodega': r1['idBodega'], 'idRepuesto': r1['idRepuesto'], 'cantidad': 1})[0] == 403)
s, d = req('POST', f'/reparaciones/{idr}/repuestos', T['tecnico1'], {'idBodega': r1['idBodega'], 'idRepuesto': r1['idRepuesto'], 'cantidad': 2})
chk('usar 2 unidades con stock', s == 200, (s, d))
s, inv2 = req('GET', f'/inventario?idBodega={r1["idBodega"]}', T['tecnico1'])
ex = [r for r in inv2 if r['idRepuesto'] == r1['idRepuesto']][0]['existencia']
chk('la existencia bajó exactamente 2', ex == antes - 2, (ex, antes))
s, k = req('GET', f'/inventario/kardex?idBodega={r1["idBodega"]}&idRepuesto={r1["idRepuesto"]}', T['tecnico1'])
ult = k[-1] if k else {}   # el kárdex viene en orden cronológico: el último es el más reciente
chk('el kárdex registra la SALIDA por reparación con la existencia resultante', s == 200 and ult.get('tipo') == 'SALIDA' and ult.get('origen') == 'REPARACION' and ult.get('cantidad') == 2 and ult.get('existenciaAnterior') == antes and ult.get('existenciaResultante') == ex, ult)
s, d = req('POST', f'/reparaciones/{idr}/actividades', T['tecnico1'], {'descripcion': 'Cambio de fuente y pruebas de carga', 'horas': 1.5})
chk('registrar actividad', s == 200, (s, d))
chk('horas > 24 rechazadas', req('POST', f'/reparaciones/{idr}/actividades', T['tecnico1'], {'descripcion': 'x', 'horas': 30})[0] in (400, 409))
s, d = req('POST', f'/reparaciones/{idr}/finalizar', T['tecnico1'], {'descripcionTrabajo': 'Fuente reemplazada; equipo enciende y pasa pruebas.', 'costoManoObra': 200})
chk('finalizar reparación', s == 200, (s, d))
chk('ya finalizada: no admite más repuestos', req('POST', f'/reparaciones/{idr}/repuestos', T['tecnico1'], {'idBodega': r1['idBodega'], 'idRepuesto': r1['idRepuesto'], 'cantidad': 1})[0] == 409)
s, d = req('GET', f'/ordenes/{ido}', T['recepcion1'])
chk('la orden quedó LISTO', buscar(d, 'estado') == 'LISTO', buscar(d, 'estado'))

# ---------------------------------------------------------------- 6. factura y pagos (T08-T10)
seccion('6. Factura, pagos y entrega (T08, T09, T10)')
chk('técnico no factura -> 403', req('POST', f'/ordenes/{ido}/factura', T['tecnico1'], {'nitFacturacion': 'CF', 'nombreFacturacion': 'Cliente Prueba'})[0] == 403)
s, f = req('POST', f'/ordenes/{ido}/factura', T['caja1'], {'nitFacturacion': nit, 'nombreFacturacion': f'Cliente E2E {SUFIJO}', 'direccionFacturacion': 'Zona 4'})
idf = buscar(f, 'idFactura')
total = float(buscar(f, 'total') or 0)
chk('emitir factura', s == 200 and idf and total > 0, (s, f))
_, catalogo = req('GET', '/repuestos', T['caja1'])
pventa = [x for x in catalogo if x['idRepuesto'] == r1['idRepuesto']][0]['precioVenta']
esperado = round((200 + 2 * float(pventa)) * 1.12, 2)   # (mano de obra + 2 repuestos al precio del momento) + 12 % de IVA
chk('total = (mano de obra + repuestos) + 12 % de IVA', abs(esperado - total) < 0.02, (esperado, total))
chk('segunda factura de la misma orden -> 409', req('POST', f'/ordenes/{ido}/factura', T['caja1'], {'nitFacturacion': 'CF', 'nombreFacturacion': 'Cliente Prueba'})[0] == 409)
chk('entrega con saldo pendiente rechazada (409)', req('POST', f'/ordenes/{ido}/entrega', T['caja1'], {'nombreRecibe': 'Juan', 'documentoRecibe': '2345 67890 0102'})[0] == 409)
mitad = round(total / 2, 2)
s, p1 = req('POST', f'/facturas/{idf}/pagos', T['caja1'], {'idMetodoPago': 1, 'monto': mitad})
chk('primer pago parcial', s == 200, (s, p1))
s, p2 = req('POST', f'/facturas/{idf}/pagos', T['caja1'], {'idMetodoPago': 1, 'monto': round(mitad / 2, 2)})
chk('segundo pago parcial', s == 200, (s, p2))
saldo_esp = round(total - mitad - round(mitad / 2, 2), 2)
s, fl = req('GET', '/facturas', T['caja1'])
mia = [x for x in fl if x.get('idFactura') == idf]
chk('el saldo es el esperado', mia and abs(float(mia[0]['saldo']) - saldo_esp) < 0.02, (mia[0].get('saldo') if mia else None, saldo_esp))
chk('pago que excede el saldo rechazado (409)', req('POST', f'/facturas/{idf}/pagos', T['caja1'], {'idMetodoPago': 1, 'monto': round(saldo_esp + 1, 2)})[0] == 409)
chk('pago de 0 rechazado', req('POST', f'/facturas/{idf}/pagos', T['caja1'], {'idMetodoPago': 1, 'monto': 0})[0] in (400, 409))
chk('recepción no registra pagos -> 403', req('POST', f'/facturas/{idf}/pagos', T['recepcion1'], {'idMetodoPago': 1, 'monto': 1})[0] == 403)
s, fl = req('GET', '/facturas', T['caja1'])
mia = [x for x in fl if x.get('idFactura') == idf]
chk('los rechazos no cambiaron el saldo', mia and abs(float(mia[0]['saldo']) - saldo_esp) < 0.02, mia[0].get('saldo') if mia else None)
s, p3 = req('POST', f'/facturas/{idf}/pagos', T['caja1'], {'idMetodoPago': 1, 'monto': saldo_esp})
chk('pago final deja saldo en 0', s == 200, (s, p3))
chk('factura pagada no admite más pagos (409)', req('POST', f'/facturas/{idf}/pagos', T['caja1'], {'idMetodoPago': 1, 'monto': 1})[0] == 409)
s, e = req('POST', f'/ordenes/{ido}/entrega', T['caja1'], {'nombreRecibe': 'Juan Pérez', 'documentoRecibe': '2345 67890 0101', 'observaciones': 'Se entrega con cargador'})
chk('entrega con saldo 0', s == 200, (s, e))
s, d = req('GET', f'/ordenes/{ido}', T['recepcion1'])
chk('la orden quedó ENTREGADO', buscar(d, 'estado') == 'ENTREGADO', buscar(d, 'estado'))
chk('segunda entrega rechazada (409)', req('POST', f'/ordenes/{ido}/entrega', T['caja1'], {'nombreRecibe': 'Juan Pérez', 'documentoRecibe': '2345 67890 0103'})[0] == 409)

# ---------------------------------------------------------------- 7. orden rechazada por el cliente
seccion('7. Orden que el cliente no autoriza')
s, o2 = req('POST', '/ordenes', T['recepcion1'], {'idEquipo': equipos[1], 'problemaReportado': 'Atasca el papel', 'prioridad': 'MEDIA'})
ido2 = buscar(o2, 'idOrden')
req('POST', f'/ordenes/{ido2}/diagnostico', T['tecnico1'], {'descripcion': 'Rodillo gastado', 'costoManoObraEstimado': 100})
s, d = req('POST', f'/ordenes/{ido2}/autorizacion', T['recepcion1'], {'autorizado': False})
chk('el cliente rechaza: orden a LISTO sin reparación', s == 200, (s, d))
s, d = req('GET', f'/ordenes/{ido2}', T['recepcion1'])
chk('estado tras rechazo', buscar(d, 'estado') in ('LISTO', 'CANCELADO'), buscar(d, 'estado'))

# ---------------------------------------------------------------- 8. compras (T06)
seccion('8. Compras y recepción (T06)')
s, prov = req('GET', '/proveedores', T['bodega1'])
s, bod = req('GET', '/bodegas', T['bodega1'])
s, rep = req('GET', '/repuestos', T['bodega1'])
ra, rb = rep[0], rep[1]
bodega = bod[0]['idBodega']
def existencia(idrep):
    _, iv = req('GET', f'/inventario?idBodega={bodega}', T['bodega1'])
    f = [r for r in iv if r['idRepuesto'] == idrep]
    return f[0]['existencia'] if f else 0
ea, eb = existencia(ra['idRepuesto']), existencia(rb['idRepuesto'])
doc = f'E2E-{SUFIJO}'
s, c = req('POST', '/compras', T['bodega1'], {'idProveedor': prov[0]['idProveedor'], 'idBodegaDestino': bodega, 'numeroDocumento': doc, 'observaciones': 'prueba', 'lineas': [{'idRepuesto': ra['idRepuesto'], 'cantidad': 5, 'costoUnitario': 111.11}, {'idRepuesto': rb['idRepuesto'], 'cantidad': 3, 'costoUnitario': 222.22}]})
idcomp = buscar(c, 'idCompra')
chk('registrar compra con 2 líneas (PENDIENTE)', s == 200 and idcomp, (s, c))
chk('registrar no mueve el inventario', existencia(ra['idRepuesto']) == ea and existencia(rb['idRepuesto']) == eb)
chk('documento repetido -> 409', req('POST', '/compras', T['bodega1'], {'idProveedor': prov[0]['idProveedor'], 'idBodegaDestino': bodega, 'numeroDocumento': doc, 'lineas': [{'idRepuesto': ra['idRepuesto'], 'cantidad': 1, 'costoUnitario': 1}]})[0] == 409)
chk('compra sin líneas rechazada', req('POST', '/compras', T['bodega1'], {'idProveedor': prov[0]['idProveedor'], 'idBodegaDestino': bodega, 'numeroDocumento': doc + 'X', 'lineas': []})[0] in (400, 409))
chk('caja no recibe compras -> 403', req('POST', f'/compras/{idcomp}/recepcion', T['caja1'])[0] == 403)
s, r = req('POST', f'/compras/{idcomp}/recepcion', T['bodega1'])
chk('recibir la compra', s == 200, (s, r))
chk('inventario subió +5 y +3', existencia(ra['idRepuesto']) == ea + 5 and existencia(rb['idRepuesto']) == eb + 3, (ea, eb, existencia(ra['idRepuesto']), existencia(rb['idRepuesto'])))
s, k = req('GET', f'/inventario/kardex?idBodega={bodega}&idRepuesto={ra["idRepuesto"]}', T['bodega1'])
chk('el kárdex tiene la ENTRADA por compra', s == 200 and k and k[0].get('tipoMovimiento', k[0].get('tipo')) == 'ENTRADA', k[0] if k else k)
chk('recibir dos veces -> 409', req('POST', f'/compras/{idcomp}/recepcion', T['bodega1'])[0] == 409)
s, k = req('POST', '/inventario/ajuste', T['bodega1'], {'idBodega': bodega, 'idRepuesto': ra['idRepuesto'], 'cantidad': -999999, 'motivo': 'prueba'})
chk('un ajuste no puede dejar existencia negativa', s in (400, 409), (s, k))

# ---------------------------------------------------------------- 9. usuarios
seccion('9. Usuarios y roles')
s, roles = req('GET', '/roles', T['administrador1'])
rid = {r['nombre']: r['idRol'] for r in roles}
uname = f'e2e{SUFIJO}'
s, u = req('POST', '/usuarios', T['administrador1'], {'username': uname, 'password': 'Clave2026!', 'nombreCompleto': 'Usuario E2E Ñandú', 'idRoles': [rid['CAJA']]})
idu = buscar(u, 'idUsuario')
chk('crear usuario', s == 200 and idu, (s, u))
chk('el usuario nuevo entra con su clave', bool(login(uname, 'Clave2026!')))
sd, dd = req('POST', '/usuarios', T['administrador1'], {'username': uname, 'password': 'Clave2026!', 'nombreCompleto': 'Prueba E2E', 'idRoles': [rid['CAJA']]})
chk('username repetido -> 409 con mensaje claro', sd == 409 and 'usuario' in str(dd), (sd, dd))
chk('clave corta -> 400', req('POST', '/usuarios', T['administrador1'], {'username': uname + 'b', 'password': 'abc', 'nombreCompleto': 'Prueba E2E', 'idRoles': [rid['CAJA']]})[0] == 400)
chk('sin roles -> 400', req('POST', '/usuarios', T['administrador1'], {'username': uname + 'c', 'password': 'Clave2026!', 'nombreCompleto': 'Prueba E2E', 'idRoles': []})[0] == 400)
s, d = req('PUT', f'/usuarios/{idu}', T['administrador1'], {'username': uname, 'nombreCompleto': 'Usuario E2E', 'estado': 'ACTIVO', 'idRoles': [rid['CAJA'], rid['BODEGA']], 'password': 'Nueva2026!'})
chk('editar roles y clave', s == 200, (s, d))
chk('la clave vieja ya no sirve y la nueva sí', not login(uname, 'Clave2026!') and bool(login(uname, 'Nueva2026!')))
tok_viejo = login(uname, 'Nueva2026!')
s, d = req('PUT', f'/usuarios/{idu}', T['administrador1'], {'username': uname, 'nombreCompleto': 'Usuario E2E', 'estado': 'INACTIVO', 'idRoles': [rid['CAJA']]})
chk('desactivar: ya no puede entrar', s == 200 and not login(uname, 'Nueva2026!'), (s, d))
chk('desactivar: su sesión abierta (token) deja de valer (se espera 401)', req('GET', '/ordenes', tok_viejo)[0] == 401, 'el token sigue valiendo hasta que vence (8 h)')
chk('un administrador no puede desactivarse a sí mismo (400)', req('PUT', '/usuarios/1', T['administrador1'], {'username': 'administrador1', 'nombreCompleto': 'Administrador Uno', 'estado': 'INACTIVO', 'idRoles': [rid['ADMINISTRADOR']]})[0] == 400)
s, auto = req('PUT', '/usuarios/1', T['administrador1'], {'username': 'administrador1', 'nombreCompleto': 'Administrador Uno', 'estado': 'ACTIVO', 'idRoles': [rid['RECEPCION']]})
chk('un administrador no puede quitarse su propio rol ADMINISTRADOR (se espera 400)', s == 400, (s, 'quedó sin rol' if s == 200 else auto))
if s == 200:  # revertir el daño de la propia prueba
    t2 = login('administrador2')
    req('PUT', '/usuarios/1', t2, {'username': 'administrador1', 'nombreCompleto': 'Administrador Uno', 'estado': 'ACTIVO', 'idRoles': [rid['ADMINISTRADOR']]})

# ---------------------------------------------------------------- 10. catálogos y auditoría de precio (T14)
seccion('10. Catálogos y auditoría de precios (T14)')
s, cat = req('GET', '/categorias', T['bodega1'])
s, c = req('POST', '/repuestos', T['bodega1'], {'codigo': f'E2E-{SUFIJO}', 'nombre': 'Repuesto E2E', 'descripcion': 'prueba', 'idCategoria': cat[0]['idCategoria'], 'precioCompraRef': 100.5, 'precioVenta': 150})
idrp = buscar(c, 'id')
chk('crear repuesto', s == 200 and idrp, (s, c))
sd, dd = req('POST', '/repuestos', T['bodega1'], {'codigo': f'E2E-{SUFIJO}', 'nombre': 'x', 'idCategoria': cat[0]['idCategoria'], 'precioCompraRef': 1, 'precioVenta': 2})
chk('código repetido -> 409 con mensaje claro', sd == 409 and 'código' in str(dd), (sd, dd))
sd, dd = req('POST', '/repuestos', T['bodega1'], {'codigo': f'E2E-{SUFIJO}z', 'nombre': 'x', 'idCategoria': 999999, 'precioCompraRef': 1, 'precioVenta': 2})
chk('categoría inexistente -> 409 con mensaje claro', sd == 409 and 'no existe' in str(dd), (sd, dd))
chk('precio con 3 decimales -> 400', req('POST', '/repuestos', T['bodega1'], {'codigo': f'E2E-{SUFIJO}b', 'nombre': 'x', 'idCategoria': cat[0]['idCategoria'], 'precioCompraRef': 1.234, 'precioVenta': 2})[0] == 400)
chk('precio negativo -> 400', req('POST', '/repuestos', T['bodega1'], {'codigo': f'E2E-{SUFIJO}c', 'nombre': 'x', 'idCategoria': cat[0]['idCategoria'], 'precioCompraRef': -1, 'precioVenta': 2})[0] == 400)
chk('recepción no gestiona catálogos -> 403', req('POST', '/categorias', T['recepcion1'], {'nombre': 'nope'})[0] == 403)
chk('crear categoría, tipo de equipo, marca, proveedor y bodega', all(req('POST', ruta, T['bodega1'], cuerpo)[0] == 200 for ruta, cuerpo in [
    ('/categorias', {'nombre': f'Cat E2E {SUFIJO}'}), ('/tipos-equipo', {'nombre': f'Tipo E2E {SUFIJO}'}), ('/marcas', {'nombre': f'Marca E2E {SUFIJO}'}),
    ('/proveedores', {'nit': f'8{SUFIJO}-K', 'nombre': f'Proveedor E2E {SUFIJO}'}), ('/bodegas', {'codigo': f'B{SUFIJO}'[:10], 'nombre': f'Bodega E2E {SUFIJO}'})]))
s, d = req('PUT', f'/repuestos/{idrp}', T['bodega1'], {'codigo': f'E2E-{SUFIJO}', 'nombre': 'Repuesto E2E', 'descripcion': 'prueba', 'idCategoria': cat[0]['idCategoria'], 'precioCompraRef': 100.5, 'precioVenta': 175, 'estado': 'ACTIVO'})
chk('cambiar el precio de venta', s == 200, (s, d))
# el precio histórico de la orden ya facturada no cambió: se revisa que el detalle de la orden entregada sigue igual
s, d1 = req('GET', f'/ordenes/{ido}', T['recepcion1'])
s, f2 = req('GET', '/facturas', T['caja1'])
mia = [x for x in f2 if x.get('idFactura') == idf]
chk('el total de la factura ya emitida no cambia con los precios del catálogo', mia and abs(float(mia[0]['total']) - total) < 0.005, mia[0].get('total') if mia else None)

# ---------------------------------------------------------------- 11. dashboard y reportes
seccion('11. Dashboard y los 12 reportes')
s, db = req('GET', '/dashboard', T['recepcion1'])
claves = ['ordenesAbiertas', 'recibidas', 'enDiagnostico', 'esperandoAutorizacion', 'enReparacion', 'listasParaEntregar', 'facturasConSaldo', 'saldoPorCobrar', 'repuestosBajoMinimo']
chk('dashboard con sus 9 indicadores', s == 200 and all(k in db for k in claves), db)
s, ords = req('GET', '/ordenes', T['recepcion1'])
activas = [x for x in ords if x.get('estado') not in ('ENTREGADO', 'CANCELADO')]
chk('órdenes abiertas del dashboard = órdenes no cerradas de la lista', s == 200 and db['ordenesAbiertas'] == len(activas), (db.get('ordenesAbiertas'), len(activas)))
hoy = datetime.date.today()
fi, ff = (hoy - datetime.timedelta(days=200)).isoformat(), (hoy + datetime.timedelta(days=2)).isoformat()
reportes = {
    1: '', 2: f'?idCliente={idc}', 3: f'?numeroSerie=E2E-{SUFIJO}-0', 4: f'?fechaInicio={fi}&fechaFin={ff}', 5: f'?fechaInicio={fi}&fechaFin={ff}',
    6: '', 7: '', 8: '', 9: '', 10: '', 11: f'?fechaInicio={fi}&fechaFin={ff}', 12: f'?idOrden={ido}'}
for n, q in reportes.items():
    s, d = req('GET', f'/reportes/{n}{q}', T['administrador1'])
    n_filas = len(d) if isinstance(d, list) else (sum(len(v) for v in d.values() if isinstance(v, list)) if isinstance(d, dict) else 0)
    chk(f'reporte {n} responde con datos', s == 200 and n_filas > 0, (s, str(d)[:120]))
chk('reporte 12 trae la trazabilidad de la orden entregada con factura y pagos', 'pago' in json.dumps(req('GET', f'/reportes/12?idOrden={ido}', T['administrador1'])[1]).lower())
s, d = req('GET', f'/reportes/3?numeroSerie=E2E-{SUFIJO}-0', T['administrador1'])
chk('reporte 3 (historial por serie) muestra la orden', s == 200 and json.dumps(d).count('OS-') >= 1)
chk('los técnicos pueden ver reportes, la caja también (REPORTE_VER)', req('GET', '/reportes/1', T['tecnico1'])[0] == 200 and req('GET', '/reportes/1', T['caja1'])[0] == 200)

# ---------------------------------------------------------------- validaciones de entrada (largos, formatos y topes)
seccion('Validaciones de entrada')
A_ = T['administrador1']
chk('login con contraseña de 200 caracteres -> 401 sin consultar', req('POST', '/auth/login', None, {'username': 'administrador1', 'password': 'x' * 200})[0] == 401)
chk('login con usuario de 60 caracteres -> 401', req('POST', '/auth/login', None, {'username': 'u' * 60, 'password': 'Demo2026!'})[0] == 401)
chk('usuario con espacios -> 400', req('POST', '/usuarios', A_, {'username': 'juan perez', 'password': 'Clave2026!', 'nombreCompleto': 'Prueba E2E', 'idRoles': [rid['CAJA']]})[0] == 400)
chk('usuario de 2 caracteres -> 400', req('POST', '/usuarios', A_, {'username': 'ab', 'password': 'Clave2026!', 'nombreCompleto': 'Prueba E2E', 'idRoles': [rid['CAJA']]})[0] == 400)
chk('contraseña sin números -> 400', req('POST', '/usuarios', A_, {'username': uname + 'd', 'password': 'solamenteletras', 'nombreCompleto': 'Prueba E2E', 'idRoles': [rid['CAJA']]})[0] == 400)
chk('contraseña de 129 caracteres -> 400', req('POST', '/usuarios', A_, {'username': uname + 'e', 'password': 'a1' * 64 + 'b', 'nombreCompleto': 'Prueba E2E', 'idRoles': [rid['CAJA']]})[0] == 400)
chk('teléfono de usuario con letras -> 400', req('POST', '/usuarios', A_, {'username': uname + 'f', 'password': 'Clave2026!', 'nombreCompleto': 'Prueba E2E', 'telefono': 'abc12345', 'idRoles': [rid['CAJA']]})[0] == 400)
chk('NIT de cliente con letras -> 400', req('POST', '/clientes', T['recepcion1'], {'tipoCliente': 'INDIVIDUAL', 'nit': 'ABC', 'nombre': 'Prueba E2E', 'telefono': '22334455'})[0] == 400)
chk('teléfono de cliente con menos de 8 dígitos -> 400', req('POST', '/clientes', T['recepcion1'], {'tipoCliente': 'INDIVIDUAL', 'nit': 'CF', 'nombre': 'Prueba E2E', 'telefono': '1234'})[0] == 400)
s, d = req('POST', '/clientes', T['recepcion1'], {'tipoCliente': 'INDIVIDUAL', 'nit': f'7{SUFIJO}-k', 'nombre': f'Cliente K {SUFIJO}', 'telefono': '+502 2233-4455'})
chk('NIT con dígito verificador K y teléfono con +502 se aceptan', s == 200, (s, d))
chk('NIT de proveedor inválido -> 400', req('POST', '/proveedores', T['bodega1'], {'nit': 'P-123-X', 'nombre': 'Prueba E2E'})[0] == 400)
chk('NIT de facturación inválido -> 400', req('POST', f'/ordenes/{ido2}/factura', T['caja1'], {'nitFacturacion': 'NIT??'})[0] == 400)
chk('DPI de 3 dígitos -> 400', req('POST', f'/ordenes/{ido2}/entrega', T['caja1'], {'nombreRecibe': 'Juan Pérez', 'documentoRecibe': '123'})[0] == 400)
chk('mano de obra de Q 2,000,000 -> 400 (no llega a desbordar la base)', req('POST', f'/ordenes/{ido2}/diagnostico', T['tecnico1'], {'descripcion': 'x', 'costoManoObraEstimado': 2000000})[0] == 400)
chk('compra con cantidad 10,001 -> 400', req('POST', '/compras', T['bodega1'], {'idProveedor': prov[0]['idProveedor'], 'idBodegaDestino': bodega, 'numeroDocumento': doc + 'Q', 'lineas': [{'idRepuesto': ra['idRepuesto'], 'cantidad': 10001, 'costoUnitario': 1}]})[0] == 400)
chk('compra con costo de Q 99,999,999 -> 400', req('POST', '/compras', T['bodega1'], {'idProveedor': prov[0]['idProveedor'], 'idBodegaDestino': bodega, 'numeroDocumento': doc + 'R', 'lineas': [{'idRepuesto': ra['idRepuesto'], 'cantidad': 1, 'costoUnitario': 99999999}]})[0] == 400)
chk('ajuste de 20,000 unidades -> 400', req('POST', '/inventario/ajuste', T['bodega1'], {'idBodega': bodega, 'idRepuesto': ra['idRepuesto'], 'cantidad': 20000, 'motivo': 'prueba'})[0] == 400)

# ---------------------------------------------------------------- validaciones de formato (nombres, correo, códigos, pagos)
seccion('Validaciones de formato')
R_ = T['recepcion1']
chk('nombre de cliente sin letras -> 400', req('POST', '/clientes', R_, {'tipoCliente': 'INDIVIDUAL', 'nit': 'CF', 'nombre': '12345', 'telefono': '22334455'})[0] == 400)
chk('nombre de cliente con símbolos (<script>) -> 400', req('POST', '/clientes', R_, {'tipoCliente': 'INDIVIDUAL', 'nit': 'CF', 'nombre': '<script>', 'telefono': '22334455'})[0] == 400)
chk('correo de cliente sin dominio -> 400', req('POST', '/clientes', R_, {'tipoCliente': 'INDIVIDUAL', 'nit': 'CF', 'nombre': 'Cliente Correo', 'email': 'correo@'})[0] == 400)
chk('correo de usuario inválido -> 400', req('POST', '/usuarios', A_, {'username': uname + 'g', 'password': 'Clave2026!', 'nombreCompleto': 'Usuario Correo', 'email': 'a@b', 'idRoles': [rid['CAJA']]})[0] == 400)
chk('número de serie con espacios -> 400', req('POST', '/equipos', R_, {'idCliente': idc, 'idTipoEquipo': 1, 'idMarca': 1, 'modelo': 'Modelo X', 'numeroSerie': 'SN 0001'})[0] == 400)
chk('código de repuesto con espacios -> 400', req('POST', '/repuestos', T['bodega1'], {'codigo': 'ALM 999', 'nombre': 'Repuesto prueba', 'idCategoria': cat[0]['idCategoria'], 'precioCompraRef': 1, 'precioVenta': 2})[0] == 400)
chk('correo de proveedor inválido -> 400', req('POST', '/proveedores', T['bodega1'], {'nit': f'6{SUFIJO}-1', 'nombre': 'Proveedor Correo', 'email': 'ventas@'})[0] == 400)
chk('número de documento de compra con espacios -> 400', req('POST', '/compras', T['bodega1'], {'idProveedor': prov[0]['idProveedor'], 'idBodegaDestino': bodega, 'numeroDocumento': 'FAC 1', 'lineas': [{'idRepuesto': ra['idRepuesto'], 'cantidad': 1, 'costoUnitario': 1}]})[0] == 400)
chk('pago con 3 decimales -> 400', req('POST', f'/facturas/{idf}/pagos', T['caja1'], {'idMetodoPago': 1, 'monto': 10.555})[0] == 400)
chk('referencia de pago con símbolos -> 400', req('POST', f'/facturas/{idf}/pagos', T['caja1'], {'idMetodoPago': 2, 'monto': 1, 'referencia': '#$%&'})[0] == 400)
chk('motivo de ajuste de 3 caracteres -> 400', req('POST', '/inventario/ajuste', T['bodega1'], {'idBodega': bodega, 'idRepuesto': ra['idRepuesto'], 'cantidad': 1, 'motivo': 'abc'})[0] == 400)
chk('quién recibe sin letras -> 400', req('POST', f'/ordenes/{ido2}/entrega', T['caja1'], {'nombreRecibe': '1'})[0] == 400)
chk('nombre de facturación con símbolos -> 400', req('POST', f'/ordenes/{ido2}/factura', T['caja1'], {'nombreFacturacion': '<b>x</b>'})[0] == 400)

print(f'\nRESULTADO: {ok} OK, {fallas} FALLA')
sys.exit(1 if fallas else 0)
