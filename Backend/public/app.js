// ========== CLIENTE API SIMPLIFICADO ==========
class API {
    constructor(baseURL) {
        this.baseURL = baseURL;
    }
    async request(endpoint, options = {}) {
        const res = await fetch(this.baseURL + endpoint, {
            headers: { 'Content-Type': 'application/json' },
            ...options
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || `Error ${res.status}`);
        return data;
    }
    get(e) { return this.request(e); }
    post(e, b) { return this.request(e, { method: 'POST', body: JSON.stringify(b) }); }
    put(e, b) { return this.request(e, { method: 'PUT', body: JSON.stringify(b) }); }
    delete(e) { return this.request(e, { method: 'DELETE' }); }
}

// ========== CLASE CARRITO ==========
class Carrito {
    constructor(api, carroId, items = []) {
        this.api = api;
        this.carroId = carroId;
        this.items = items;
    }
    total() { return this.items.reduce((s, i) => s + i.precio_prod * i.cantidad_pedida, 0); }
    cantidad() { return this.items.reduce((s, i) => s + i.cantidad_pedida, 0); }
    async agregar(productId, nombre, edicion, precio) {
        await this.api.post(`/carrito/${this.carroId}/items`, { productoid: productId, cantidad_pedida: 1, precio_prod: precio });
        let existente = this.items.find(i => i.productoid === productId);
        if (existente) existente.cantidad_pedida++;
        else this.items.push({ productoid: productId, nombre_producto: nombre, nombre_edicion: edicion, precio_prod: precio, cantidad_pedida: 1 });
    }
    async eliminar(detallesId, productoid) {
        await this.api.delete(`/carrito/${this.carroId}/items/${detallesId}`);
        this.items = this.items.filter(i => i.detallesid !== detallesId && i.productoid !== productoid);
    }
    vaciar() { this.items = []; }
    async confirmar(metodoPagoId, promocionId = null) {
        let data = await this.api.put(`/carrito/${this.carroId}/confirmar`, { metodo_pago_id: metodoPagoId });
        if (promocionId) await this.api.post('/pedidos/aplicar-promocion', { pedido_id: data.pedido_id, promocion_id: promocionId });
        return data;
    }
}

// ========== CLASE PRINCIPAL APP ==========
class App {
    constructor() {
        this.api = new API('http://localhost:3000/api');
        this.usuario = null;
        this.carrito = null;
        this.pagos = [];
        this.promociones = [];
        this.bindGlobalFunctions();
        this.mostrarRegistro();
        this.setupEventDelegation();
    }

    bindGlobalFunctions() {
        window.registrarCliente = () => this.registrarCliente();
        window.loginPorEmail = () => this.loginPorEmail();
        window.mostrarRegistro = () => this.mostrarRegistro();
        window.mostrarLogin = () => this.mostrarLogin();
        window.cerrarSesion = () => this.cerrarSesion();
        window.cambiarPestana = (p, btn) => this.cambiarPestana(p, btn);
        window.mostrarModalAgregarPago = () => this.mostrarModal('modal-agregar-pago');
        window.cerrarModalAgregarPago = () => this.cerrarModal('modal-agregar-pago');
        window.agregarMetodoPago = () => this.agregarMetodoPago();
        window.prepararEliminarPagoGlobal = (id, num) => this.prepararEliminarPago(id, num);
        window.cerrarModalEliminarPago = () => this.cerrarModal('modal-eliminar-pago');
        window.abrirCheckout = () => this.abrirCheckout();
        window.cerrarCheckout = () => this.cerrarCheckout();
        window.confirmarCompra = (promoId) => this.confirmarCompra(promoId);
        window.reiniciarCarritoGlobal = () => this.reiniciarCarrito();
        window.cargarReporte = (e) => this.cargarReporte(e);
        window.limpiarTablaAdmin = () => this.limpiarTablaAdmin();
        window.eliminarItem = (id, pid) => this.eliminarItem(id, pid);
    }

    setupEventDelegation() {
        document.getElementById('catalogo-contenedor')?.addEventListener('click', async (e) => {
            const btn = e.target.closest('.btn-agregar');
            if (btn) {
                const card = btn.closest('.card');
                if (!card) return;
                const idx = card.dataset.idx;
                const productId = parseInt(card.dataset.productid);
                const nombre = card.dataset.nombre;
                const tipo = card.dataset.tipo;
                if (isNaN(productId)) {
                    console.error('ID de producto inválido:', card.dataset.productid);
                    this.toast('Error: ID de producto no válido', 'error');
                    return;
                }
                await this.toggleEdiciones(e, idx, productId, nombre, tipo);
                return;
            }
            const opt = e.target.closest('.edition-opt');
            if (opt && !opt.classList.contains('no-stock')) {
                const productId = parseInt(opt.dataset.productid);
                const nombre = opt.dataset.nombre;
                const edicion = opt.dataset.edicion;
                const precio = parseFloat(opt.dataset.precio);
                if (isNaN(productId)) {
                    this.toast('Error: ID de producto no válido', 'error');
                    return;
                }
                await this.agregarAlCarrito(productId, nombre, edicion, precio);
                opt.closest('.edition-picker')?.classList.remove('open');
            }
        });
    }

    // ========== REGISTRO Y LOGIN ==========
    async cargarPaises() {
        try {
            let paises = await this.api.get('/paises');
            let select = document.getElementById('reg-pais');
            if (select) select.innerHTML = '<option value="">Selecciona un país</option>' + paises.map(p => `<option value="${p.paisid}">${p.nombre}</option>`).join('');
        } catch { document.getElementById('reg-pais').innerHTML = '<option value="1">Bolivia</option><option value="2">Perú</option><option value="3">Chile</option>'; }
    }
    async registrarCliente() {
        let nombre = document.getElementById('reg-nombre').value.trim();
        let apellido = document.getElementById('reg-apellido').value.trim();
        let email = document.getElementById('reg-email').value.trim();
        let telefono = document.getElementById('reg-telefono').value.trim();
        let paisid = document.getElementById('reg-pais').value;
        if (!nombre || !apellido || !email || !paisid) return this.toast('Completa todos los campos', 'error');
        try {
            await this.api.post('/clientes', { nombre, medio: null, apellido, correo: email, paisid: parseInt(paisid), numero_contacto: telefono || null });
            this.toast('Cliente registrado con éxito. Ahora inicia sesión.');
            this.mostrarLogin();
        } catch (err) { this.toast('Error al registrar: ' + err.message, 'error'); }
    }
    mostrarRegistro() {
        document.getElementById('sec-login').classList.add('hidden');
        document.getElementById('sec-registro').classList.remove('hidden');
        this.cargarPaises();
    }
    mostrarLogin() {
        document.getElementById('sec-registro').classList.add('hidden');
        document.getElementById('sec-login').classList.remove('hidden');
    }
    async loginPorEmail() {
        let email = document.getElementById('login-email').value.trim();
        if (!email) return this.toast('Ingresa tu correo', 'error');
        try {
            let data = await this.api.post('/login', { email });
            this.usuario = { id: data.Id_cliente, rol: data.rol || 'cliente', nombre: data.nombre, apellido: data.apellido, email: data.email };
            this.actualizarNav();
            if (this.usuario.rol === 'admin') this.mostrarSeccion('admin');
            else {
                this.mostrarSeccion('cliente');
                await Promise.all([this.cargarCatalogo(), this.cargarPagos(), this.cargarCarrito(), this.cargarPromociones()]);
                this.cargarPerfil();
            }
        } catch (err) { this.toast('Error: ' + err.message, 'error'); }
    }
    cerrarSesion() {
        this.usuario = null;
        this.carrito = null;
        this.mostrarLogin();
        document.getElementById('nav-links').innerHTML = '';
    }
    actualizarNav() {
        let links = document.getElementById('nav-links');
        if (!links || !this.usuario) return;
        links.innerHTML = `<button class="nav-btn danger" onclick="cerrarSesion()">${this.usuario.rol === 'admin' ? 'Cerrar sesión' : 'Salir'}</button>`;
    }
    mostrarSeccion(id) {
        document.querySelectorAll('section').forEach(s => s.classList.add('hidden'));
        document.getElementById(`sec-${id}`).classList.remove('hidden');
    }
    toast(msg, tipo = 'success') {
        let el = document.getElementById('toast');
        if (!el) return;
        el.textContent = msg;
        el.className = `show ${tipo}`;
        setTimeout(() => el.className = '', 2500);
    }
 
// ========== CATÁLOGO ==========
async cargarCatalogo() {
    let container = document.getElementById('catalogo-contenedor');
    if (!container) return;
    container.innerHTML = '<div class="text-center">Cargando catálogo...</div>';
    try {
        let juegos = await this.api.get('/juegos/todo');
        if (!juegos.length) { container.innerHTML = '<div class="text-center">No hay juegos disponibles</div>'; return; }
        const colores = ['#3b1f8c','#1a3a5c','#1a4a2e','#4a1a1a'];
        const emojis = { juego: '🎮', dlc: '🔮', complemento: '🎁' };
        container.innerHTML = juegos.map((j, idx) => {
            let tipo = j.tipo_dejuego || 'juego';
            let tagClass = tipo === 'juego' ? 'tag-juego' : (tipo === 'dlc' ? 'tag-dlc' : 'tag-comp');
            let color = colores[idx % colores.length];
            return `
                <div class="card" data-idx="${idx}" data-productid="${j.productid}" data-nombre="${j.nombre_juego.replace(/'/g, "\\'")}" data-tipo="${tipo}">
                    <div class="card-header" style="background:linear-gradient(135deg,${color},${color}88)"><span style="font-size:2.5rem">${emojis[tipo] || '🎮'}</span></div>
                    <div class="card-body"><h5>${j.nombre_juego}</h5><span class="tag ${tagClass}">${tipo}</span>${j.Cabeza ? `<div class="ed-stock mt-1">de ${j.Cabeza}</div>` : ''}</div>
                    <div class="card-footer">
                        <div class="ed-price">Ver ediciones →</div>
                        <button class="btn btn-primario w-full mt-1 btn-agregar">+ Agregar</button>
                        <div class="edition-picker" id="picker-${idx}"><h6 class="label">Elige edición</h6><div id="editions-${idx}"><div class="spinner"></div></div></div>
                    </div>
                </div>`;
        }).join('');
    } catch (err) {
        console.error(err);
        container.innerHTML = '<div class="text-center" style="color:var(--rojo)">Error al cargar catálogo</div>';
    }
}

async toggleEdiciones(e, idx, productId, nombre, tipo) {
    e.stopPropagation();
    let picker = document.getElementById(`picker-${idx}`);
    if (!picker) return;
    if (picker.classList.contains('open')) { picker.classList.remove('open'); return; }
    document.querySelectorAll('.edition-picker').forEach(p => p.classList.remove('open'));
    picker.classList.add('open');
    let editionsDiv = document.getElementById(`editions-${idx}`);
    if (editionsDiv.dataset.loaded) return;
    try {
        if (tipo !== 'juego') {
            editionsDiv.innerHTML = `<div class="edition-opt" data-productid="${productId}" data-nombre="${nombre}" data-edicion="Estándar" data-precio="0"><div><div class="ed-name">Contenido Digital</div><div class="ed-stock">Disponible</div></div></div>`;
            editionsDiv.dataset.loaded = '1';
            return;
        }
        // Petición manual para controlar errores
        const res = await fetch(`http://localhost:3000/api/productos/${productId}/ediciones`);
        const text = await res.text();
        let eds = [];
        try {
            eds = text ? JSON.parse(text) : [];
        } catch(e) {
            console.error('JSON inválido:', text);
            editionsDiv.innerHTML = '<div class="text-center">Error al cargar ediciones</div>';
            return;
        }
        if (!eds.length) {
            editionsDiv.innerHTML = '<div class="text-center">No hay ediciones disponibles</div>';
        } else {
            editionsDiv.innerHTML = eds.map(ed => `<div class="edition-opt ${ed.stock === 0 ? 'no-stock' : ''}" data-productid="${productId}" data-nombre="${nombre.replace(/'/g, "\\'")}" data-edicion="${ed.nombre_edicion}" data-precio="${ed.precio}"><div><div class="ed-name">${ed.nombre_edicion}</div><div class="ed-stock">${ed.stock === 0 ? 'Sin stock' : `Stock: ${ed.stock}`}</div></div><div class="ed-price">$${parseFloat(ed.precio).toFixed(2)}</div></div>`).join('');
        }
        editionsDiv.dataset.loaded = '1';
    } catch (err) {
        console.error('Error cargando ediciones:', err);
        editionsDiv.innerHTML = '<div class="text-center" style="color:var(--rojo)">Error al cargar ediciones</div>';
    }
}

    // ========== CARRITO ==========
    async cargarCarrito() {
        try {
            let data = await this.api.get(`/clientes/${this.usuario.id}/carrito`);
            if (data.carrito) this.carrito = new Carrito(this.api, data.carrito.carro_id, data.items);
            else {
                let nuevo = await this.api.post(`/clientes/${this.usuario.id}/carrito`, {});
                this.carrito = new Carrito(this.api, nuevo.carro_id, []);
            }
            this.renderCarrito();
        } catch (err) { this.toast('Error al cargar carrito', 'error'); }
    }
    async agregarAlCarrito(productId, nombre, edicion, precio) {
        if (!this.carrito) return this.toast('Error: carrito no activo', 'error');
        try {
            await this.carrito.agregar(productId, nombre, edicion, precio);
            await this.cargarCarrito();   // ← RECARGA EL CARRITO PARA OBTENER detallesid
            this.renderCarrito();
            this.toast(`✅ ${nombre} agregado`);
            document.querySelectorAll('.edition-picker').forEach(p => p.classList.remove('open'));
        } catch (err) { this.toast('Error al agregar', 'error'); }
    }
   async eliminarItem(detallesId, productId) {
    if (!detallesId || detallesId === null || detallesId === 'null') {
        this.toast('No se puede eliminar: falta identificador del producto', 'error');
        return;
    }
    try {
        await this.carrito.eliminar(detallesId, productId);
        this.renderCarrito();
        this.toast('Item eliminado');
    } catch (err) {
        this.toast('Error al eliminar', 'error');
    }
}

    renderCarrito() {
        let list = document.getElementById('cart-list');
        let footer = document.getElementById('cart-footer');
        let badge = document.getElementById('cart-count');
        if (!list) return;
        if (!this.carrito || !this.carrito.items.length) {
            list.innerHTML = '<div class="cart-empty">Tu carrito está vacío<br><span style="font-size:1.5rem">🛒</span></div>';
            if (footer) footer.classList.add('hidden');
            if (badge) badge.style.display = 'none';
            return;
        }
        let total = this.carrito.total();
        list.innerHTML = this.carrito.items.map(item => `
            <div class="cart-item">
                <div style="flex:1"><div class="cart-name">${item.nombre_producto}</div>${item.nombre_edicion ? `<div class="cart-edition">${item.nombre_edicion}</div>` : ''}<div class="cart-edition">x${item.cantidad_pedida}</div></div>
                <div class="flex gap-1 center"><div class="cart-price">$${(item.precio_prod * item.cantidad_pedida).toFixed(2)}<button class="cart-remove" onclick="eliminarItem(${item.detallesid ? item.detallesid : 'null'}, ${item.productoid})">✕</button>
            </div>`).join('');
        document.getElementById('cart-total').textContent = `$${total.toFixed(2)}`;
        if (footer) footer.classList.remove('hidden');
        if (badge) { badge.style.display = 'inline'; badge.textContent = this.carrito.cantidad(); }
    }

    // ========== PAGOS ==========
    async cargarPagos() {
        try {
            this.pagos = await this.api.get(`/clientes/${this.usuario.id}/pagos`);
            let container = document.getElementById('perfil-pagos');
            if (!container) return;
            if (!this.pagos.length) container.innerHTML = '<div class="text-center" style="color:var(--texto-sec)">No tienes tarjetas registradas</div>';
            else container.innerHTML = this.pagos.map((p, i) => `<div class="pago-item"><div><div class="pago-number">•••• •••• •••• ${p.numero_de_tarjeta ? p.numero_de_tarjeta.slice(-4) : i+1}</div><div class="pago-method">${p.MetodoPago || 'Tarjeta'}</div></div><button class="btn btn-peligro btn-eliminar-pago" data-id-metodo="${p.id_metodo}" data-numero="${p.numero_de_tarjeta}">Eliminar</button></div>`).join('');
            document.querySelectorAll('.btn-eliminar-pago').forEach(btn => btn.onclick = () => this.prepararEliminarPago(parseInt(btn.dataset.idMetodo), btn.dataset.numero));
        } catch { this.toast('Error al cargar pagos', 'error'); }
    }
    async agregarMetodoPago() {
        let id_metodo = document.getElementById('pago-metodo').value;
        let numero_tarjeta = document.getElementById('pago-numero').value.trim();
        let cvv = document.getElementById('pago-cvv').value.trim();
        let fechaRaw = document.getElementById('pago-fecha').value.trim();
        if (!numero_tarjeta || !cvv || !fechaRaw) return this.toast('Completa todos los campos', 'error');
        let partes = fechaRaw.split('/');
        if (partes.length !== 2) return this.toast('Formato de fecha inválido. Usa MM/AA', 'error');
        let mes = partes[0].padStart(2,'0'), anio = partes[1];
        if (isNaN(parseInt(mes)) || parseInt(mes)<1 || parseInt(mes)>12) return this.toast('Mes inválido (01-12)', 'error');
        if (isNaN(parseInt(anio)) || parseInt(anio)<0 || parseInt(anio)>99) return this.toast('Año inválido (00-99)', 'error');
        let fecha = `20${anio}-${mes}-01`;
        try {
            await this.api.post('/pagos', { cliente_id: this.usuario.id, id_metodo: parseInt(id_metodo), numero_tarjeta, cvv, fecha_vencimiento: fecha });
            this.toast('Método de pago agregado');
            this.cerrarModal('modal-agregar-pago');
            await this.cargarPagos();
        } catch { this.toast('Error al agregar', 'error'); }
    }
    prepararEliminarPago(id_metodo, numero_tarjeta) {
        this.pagoAEliminar = { id_metodo, numero_tarjeta };
        document.getElementById('modal-eliminar-pago').classList.remove('hidden');
        document.getElementById('btn-confirmar-eliminar').onclick = () => this.eliminarMetodoPago();
    }
    async eliminarMetodoPago() {
        if (!this.pagoAEliminar) return;
        try {
            await this.api.delete('/clientes/pagos', { body: JSON.stringify({ cliente_id: this.usuario.id, id_metodo: this.pagoAEliminar.id_metodo, numero_tarjeta: this.pagoAEliminar.numero_tarjeta }) });
            this.toast('Método de pago eliminado');
            this.cerrarModal('modal-eliminar-pago');
            await this.cargarPagos();
        } catch { this.toast('Error al eliminar', 'error'); }
    }

    // ========== PROMOCIONES ==========
    async cargarPromociones() {
        try { this.promociones = await this.api.get('/promociones/vigentes'); } catch { this.promociones = []; }
        let select = document.getElementById('promo-select');
        if (select) select.innerHTML = '<option value="">Sin promoción</option>' + this.promociones.map(p => `<option value="${p.promocionid}">${p.nombre} (-${p.descuento}%)</option>`).join('');
    }

    // ========== CHECKOUT ==========
    abrirCheckout() {
        if (!this.carrito?.items?.length) return this.toast('No hay productos en el carrito', 'error');
        if (!this.pagos.length) {
            document.getElementById('checkout-modal').innerHTML = `<h3>No hay métodos de pago</h3><p>Debes registrar al menos una tarjeta antes de comprar.</p><button class="btn btn-primario btn-full" onclick="cerrarCheckout(); cambiarPestana('perfil', document.querySelector('.tab:last-child'))">Ir a Mis Tarjetas</button>`;
            document.getElementById('checkout-overlay').classList.remove('hidden');
            return;
        }
        let total = this.carrito.total();
        let promoId = document.getElementById('promo-select').value;
        let promo = this.promociones.find(p => p.promocionid == promoId);
        let totalDesc = promo ? total * (1 - promo.descuento/100) : total;
        let opciones = this.pagos.map((p, idx) => `<option value="${idx}">${p.MetodoPago || 'Tarjeta'} ****${p.numero_de_tarjeta ? p.numero_de_tarjeta.slice(-4) : idx+1}</option>`).join('');
        document.getElementById('checkout-modal').innerHTML = `
            <h3>Confirmar Pedido</h3>
            ${this.carrito.items.map(i => `<div class="order-row"><span>${i.nombre_producto}${i.nombre_edicion ? ` (${i.nombre_edicion})` : ''}</span><span>$${(i.precio_prod * i.cantidad_pedida).toFixed(2)}</span></div>`).join('')}
            <div class="divider"></div>${promo ? `<div class="order-row"><span class="promo-tag">🏷 ${promo.nombre} (-${promo.descuento}%)</span><span class="promo-tag">-$${(total - totalDesc).toFixed(2)}</span></div>` : ''}
            <div class="order-row total"><span>Total a pagar</span><span>$${totalDesc.toFixed(2)}</span></div><div class="divider"></div>
            <div class="mb-2"><label class="label">Método de pago</label><select id="checkout-metodo" class="select w-full">${opciones}</select></div>
            <div class="flex gap-1"><button class="btn btn-secundario flex-1" onclick="cerrarCheckout()">Cancelar</button><button class="btn btn-exito flex-2" onclick="confirmarCompra(${promoId || 'null'})">Pagar $${totalDesc.toFixed(2)} →</button></div>`;
        document.getElementById('checkout-overlay').classList.remove('hidden');
    }
    cerrarCheckout() { document.getElementById('checkout-overlay').classList.add('hidden'); }
    async confirmarCompra(promoId) {
        let idx = document.getElementById('checkout-metodo')?.value;
        if (idx === undefined) return this.toast('Selecciona un método de pago', 'error');
        let metodo = this.pagos[parseInt(idx)];
        if (!metodo) return this.toast('Método inválido', 'error');
        let metodoId = metodo.id_metodo || (metodo.MetodoPago?.toLowerCase().includes('crédito') ? 1 : metodo.MetodoPago?.toLowerCase().includes('débito') ? 2 : 1);
        let btn = document.querySelector('#checkout-modal .btn-exito');
        if (btn) { btn.disabled = true; btn.innerHTML = '<span class="spinner"></span>'; }
        try {
            let data = await this.carrito.confirmar(metodoId, promoId);
            let promoAplicada = promoId ? this.promociones.find(p => p.promocionid == promoId) : null;
            this.mostrarFactura(data.pedido_id, metodo.MetodoPago || 'Tarjeta', promoAplicada, data.total, this.carrito.items, data.codigos);
            this.carrito.vaciar();
            this.renderCarrito();
        } catch (err) { this.toast(`Error: ${err.message}`, 'error'); if (btn) { btn.disabled = false; btn.textContent = 'Reintentar'; } }
    }
    mostrarFactura(pedidoId, metodoPago, promo, total, items, codigos) {
        if (!codigos) codigos = [];
        let modal = document.getElementById('checkout-modal');
        if (!modal) return;
        let fecha = new Date().toLocaleString();
        let subtotal = items.reduce((s,i)=> s + i.precio_prod*i.cantidad_pedida,0);
        let descuento = promo ? subtotal * (promo.descuento/100) : 0;
        let mapa = new Map();
        if (codigos) codigos.forEach(c => { let key = c.producto; if (!mapa.has(key)) mapa.set(key,[]); mapa.get(key).push(c.codigo); });
        modal.innerHTML = `
            <div class="factura">
                <div class="factura-header"><h2>PIXELVAULT</h2><div>Factura #${pedidoId}</div></div>
                <div class="factura-detalle"><p><strong>Fecha:</strong> ${fecha}</p><p><strong>Método de pago:</strong> ${metodoPago}</p>${promo ? `<p><strong>Promoción:</strong> ${promo.nombre} (${promo.descuento}% dto.)</p>` : ''}</div>
                <table><thead><tr><th>Producto</th><th>Cant.</th><th>Precio unit.</th><th>Subtotal</th><th>Código de canje</th></tr></thead>
                <tbody>${items.map(item => {
                    let nombre = `${item.nombre_producto}${item.nombre_edicion ? ` (${item.nombre_edicion})` : ''}`;
                    let cods = mapa.get(nombre) || [];
                    return `<tr><td>${nombre}</td><td>${item.cantidad_pedida}</td><td>$${item.precio_prod.toFixed(2)}</td><td>$${(item.precio_prod*item.cantidad_pedida).toFixed(2)}</td><td>${cods.map(c=>`<div>${c}</div>`).join('') || '—'}</td></tr>`;
                }).join('')}</tbody>
                <div class="total"><p>Subtotal: $${subtotal.toFixed(2)}</p>${descuento>0?`<p>Descuento: -$${descuento.toFixed(2)}</p>`:''}<p><strong>Total pagado: $${total.toFixed(2)}</strong></p></div>
                <button class="btn-print" onclick="window.print()">🖨️ Descargar / Imprimir factura</button>
                <button class="btn btn-primario" style="margin-top:1rem;width:100%" onclick="reiniciarCarritoGlobal()">Seguir comprando</button>
            </div>`;
    }
    async reiniciarCarrito() {
        this.cerrarCheckout();
        try {
            let nuevo = await this.api.post(`/clientes/${this.usuario.id}/carrito`, {});
            this.carrito = new Carrito(this.api, nuevo.carro_id, []);
            this.renderCarrito();
            await this.cargarPagos();
        } catch {}
    }

    // ========== PERFIL, HISTORIAL, ADMIN ==========
    cargarPerfil() {
        let div = document.getElementById('perfil-datos');
        if (div) div.innerHTML = `<p><strong>Nombre:</strong> ${this.usuario.nombre} ${this.usuario.apellido}</p><p><strong>Email:</strong> ${this.usuario.email}</p><button class="btn btn-peligro" onclick="desactivarCuenta()">Desactivar mi cuenta</button>`;
    }
    async desactivarCuenta() {
        if (!confirm('¿Estás seguro? Se cerrarán tus pedidos pendientes y desactivará tu cuenta.')) return;
        try {
            await this.api.put(`/clientes/desactivar/${this.usuario.id}`, {});
            this.toast('Cuenta desactivada. Serás redirigido.');
            setTimeout(() => this.cerrarSesion(), 2000);
        } catch { this.toast('Error al desactivar', 'error'); }
    }
    async cargarHistorial() {
    let container = document.getElementById('historial-contenedor');
    if (!container) return;
    container.innerHTML = '<div class="text-center">Cargando...</div>';
    try {
        let data = await this.api.get(`/clientes/${this.usuario.id}/pedidos`);
        if (!data || !data.length) {
            container.innerHTML = '<div class="text-center" style="color:var(--texto-sec);padding:2rem">No tienes pedidos entregados aún</div>';
            return;
        }
        container.innerHTML = data.map(p => `
            <div class="historial-item">
                <div>
                    <div class="historial-id">Pedido #${p.pedido_id}</div>
                    <div class="historial-date">📅 ${p.fecha_del_pedido} → ${p.fecha_de_entrega || 'Pendiente'}</div>
                </div>
                <div class="text-right">
                    <div class="historial-total">$${parseFloat(p.Total_pago).toFixed(2)}</div>
                    <span class="estado-badge estado-${p.estado}">${p.estado}</span>
                </div>
            </div>
        `).join('');
    } catch (err) {
        console.error('Error al cargar historial:', err);
        container.innerHTML = '<div class="text-center" style="color:var(--rojo)">Error al cargar historial</div>';
    }
}

    cambiarPestana(pestana, btn) {
        document.getElementById('pestana-catalogo').classList.toggle('hidden', pestana !== 'catalogo');
        document.getElementById('pestana-historial').classList.toggle('hidden', pestana !== 'historial');
        document.getElementById('pestana-perfil').classList.toggle('hidden', pestana !== 'perfil');
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        if (btn) btn.classList.add('active');
        if (pestana === 'historial') this.cargarHistorial();
        if (pestana === 'perfil') { this.cargarPerfil(); this.cargarPagos(); }
    }
    async cargarReporte(endpoint) {
        let head = document.getElementById('report-head');
        let body = document.getElementById('report-body');
        if (!head || !body) return;
        body.innerHTML = '<tr><td style="padding:2rem;text-align:center"><div class="spinner"></div> Cargando...</td></tr>';
        try {
            let data = await this.api.get(`/${endpoint}`);
            if (!data || !data.length) { body.innerHTML = '<tr><td colspan="100%" style="padding:1rem;text-align:center">Sin datos disponibles</td></tr>'; head.innerHTML = ''; return; }
            let cols = Object.keys(data[0]);
            head.innerHTML = `<tr>${cols.map(c => `<th>${c}</th>`).join('')}</tr>`;
            body.innerHTML = data.map(row => `<tr>${cols.map(c => `<td>${row[c] ?? '—'}</td>`).join('')}</tr>`).join('');
        } catch (err) { body.innerHTML = `<td><td colspan="100%" style="padding:1rem;text-align:center;color:var(--rojo)">Error: ${err.message}</td></table>`; this.toast('Error al cargar reporte', 'error'); }
    }
    limpiarTablaAdmin() {
        document.getElementById('report-head').innerHTML = '';
        document.getElementById('report-body').innerHTML = '<tr><td style="padding:2rem;text-align:center">Selecciona un reporte</td></tr>';
    }
    mostrarModal(id) { document.getElementById(id).classList.remove('hidden'); }
    cerrarModal(id) {
        document.getElementById(id).classList.add('hidden');
        if (id === 'modal-agregar-pago') { document.getElementById('pago-numero').value = ''; document.getElementById('pago-cvv').value = ''; document.getElementById('pago-fecha').value = ''; }
        if (id === 'modal-eliminar-pago') this.pagoAEliminar = null;
    }
}

// ========== INICIALIZACIÓN ==========
const app = new App();