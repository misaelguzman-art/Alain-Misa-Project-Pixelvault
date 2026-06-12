USE [BD2_Peru]; -- Asegúrate de que este es el nombre correcto de tu base de datos de Perú
GO

-- ============================================================
--  1. CLIENTES (Solo Perú, paisid = 4)
-- ============================================================
PRINT 'Insertando Clientes de Perú...';
INSERT INTO Cliente.Cliente (nombre, nmedio, apellido, email, estado, numero_contacto, paisid) VALUES
('Alejandro', 'Jose',   'Quispe',  'alejandro.q@peru.com', 'activo', '51-912345001', 4),
('Brenda',    NULL,     'Mamani',  'brenda.m@peru.com',    'activo', '51-912345002', 4),
('Carlos',    'Luis',   'Condori', 'carlos.c@peru.com',    'activo', '51-912345003', 4),
('Diana',     NULL,     'Chavez',  'diana.c@peru.com',     'activo', '51-912345004', 4),
('Enrique',   'Martin', 'Vargas',  'enrique.v@peru.com',   'activo', '51-912345005', 4);

-- Metodos de pago para estos clientes
INSERT INTO Cliente.Cliente_Metodo_Pago (id_metodo, Id_cliente, numero_de_tarjeta, CVV, fecha_vencimiento) VALUES
(1, (SELECT Id_cliente FROM Cliente.Cliente WHERE email='alejandro.q@peru.com'), '4111111111111111', '123', '2027-12-01'),
(2, (SELECT Id_cliente FROM Cliente.Cliente WHERE email='brenda.m@peru.com'),    '4222222222222222', '456', '2026-08-01'),
(3, (SELECT Id_cliente FROM Cliente.Cliente WHERE email='carlos.c@peru.com'),    '4333333333333333', '789', '2028-03-01'),
(1, (SELECT Id_cliente FROM Cliente.Cliente WHERE email='diana.c@peru.com'),     '4444444444444444', '321', '2027-06-01'),
(2, (SELECT Id_cliente FROM Cliente.Cliente WHERE email='enrique.v@peru.com'),   '4555555555555555', '654', '2026-11-01');


-- ============================================================
--  2. PRODUCTOS LOCALES (Juegos Exclusivos de Perú, paisid = 4)
-- ============================================================
PRINT 'Insertando Productos exclusivos de Perú...';
INSERT INTO Product.Product (name, developerid, estado, tipo_juego, precio_base, fecha_de_lanzamiento, paisid) VALUES
('Mito Inca: La Leyenda',      1, 'activo', 'juego', 49.99, '2024-01-10', 4),
('Cusco Racing Simulator',     2, 'activo', 'juego', 39.99, '2024-02-15', 4),
('Aventura en los Andes',      3, 'activo', 'juego', 59.99, '2024-03-20', 4),
('Líneas de Nazca Puzzle',     4, 'activo', 'juego', 19.99, '2024-04-25', 4),
('Super Llama Bros',           5, 'activo', 'juego', 29.99, '2024-05-30', 4);

-- Asignar Plataformas (Añadirlos a PC, id_plataforma=1)
INSERT INTO Product.ProductPlataforma (productid, id_plataforma) 
SELECT productid, 1 FROM Product.Product WHERE paisid = 4 AND name IN ('Mito Inca: La Leyenda', 'Cusco Racing Simulator', 'Aventura en los Andes', 'Líneas de Nazca Puzzle', 'Super Llama Bros');

-- Asignar Categorias (Añadirlos a Accion, id_categoria=1)
INSERT INTO Product.CategoriaProduct (productid, id_categoria) 
SELECT productid, 1 FROM Product.Product WHERE paisid = 4 AND name IN ('Mito Inca: La Leyenda', 'Cusco Racing Simulator', 'Aventura en los Andes', 'Líneas de Nazca Puzzle', 'Super Llama Bros');


-- ============================================================
--  3. EDICIONES Y PRECIOS
-- ============================================================
PRINT 'Configurando Ediciones de Productos...';
-- Usaremos la Edicion Estandar (edicionid = 1)
INSERT INTO Product.EdicionProduct (productid, edicionid, precio, fecha_lanzamiento)
SELECT productid, 1, precio_base, fecha_de_lanzamiento FROM Product.Product WHERE paisid = 4 AND name IN ('Mito Inca: La Leyenda', 'Cusco Racing Simulator', 'Aventura en los Andes', 'Líneas de Nazca Puzzle', 'Super Llama Bros');


-- ============================================================
--  4. INVENTARIO Y EJEMPLARES
-- ============================================================
PRINT 'Agregando Inventario y Ejemplares (Códigos de Canje)...';
-- Insertamos 5 unidades en el inventario para cada edicion de estos productos
INSERT INTO Product.Inventario (productid, edicionproductid, cantidad)
SELECT NULL, edicionproductid, 5 
FROM Product.EdicionProduct 
WHERE productid IN (SELECT productid FROM Product.Product WHERE paisid = 4 AND name IN ('Mito Inca: La Leyenda', 'Cusco Racing Simulator', 'Aventura en los Andes', 'Líneas de Nazca Puzzle', 'Super Llama Bros'));

-- Insertamos 1 ejemplar de muestra por juego
INSERT INTO Product.Ejemplar (productid, edicionproductid, canjear_codigo, estado)
SELECT NULL, edicionproductid, 'PERU-COD-' + CAST(productid AS VARCHAR), 'activo' 
FROM Product.EdicionProduct 
WHERE productid IN (SELECT productid FROM Product.Product WHERE paisid = 4 AND name IN ('Mito Inca: La Leyenda', 'Cusco Racing Simulator', 'Aventura en los Andes', 'Líneas de Nazca Puzzle', 'Super Llama Bros'));


-- ============================================================
--  5. PROVEEDORES Y MOVIMIENTOS
-- ============================================================
PRINT 'Agregando Proveedores de Perú...';
INSERT INTO Provedor.Provedor (nombre) VALUES
('Distribuidora Lima Gaming'),
('Andes Tech Supplies'),
('Peru Juegos S.A.'),
('Inca Digital Keys'),
('Cusco Software Distribucion');

-- Movimiento de inventario (Entrada)
INSERT INTO Product.MovimientoInventario (productid, edicionproductid, cantidad, fecha, provedorid)
SELECT productid, edicionproductid, 5, GETDATE(), (SELECT TOP 1 provedorid FROM Provedor.Provedor WHERE nombre = 'Distribuidora Lima Gaming')
FROM Product.EdicionProduct 
WHERE productid IN (SELECT productid FROM Product.Product WHERE paisid = 4 AND name IN ('Mito Inca: La Leyenda', 'Cusco Racing Simulator', 'Aventura en los Andes', 'Líneas de Nazca Puzzle', 'Super Llama Bros'));


-- ============================================================
--  6. CARRITOS Y PEDIDOS
-- ============================================================
PRINT 'Generando Carritos y Pedidos...';
INSERT INTO Venta.Carrito (Id_cliente, estado, fecha_creacion, fecha_cierre)
SELECT Id_cliente, 'completado', GETDATE(), GETDATE() FROM Cliente.Cliente WHERE email LIKE '%@peru.com';

INSERT INTO Venta.CarroDetalles (carro_id, productoid, cantidad_pedida, precio_prod)
SELECT c.carro_id, p.productid, 1, p.precio_base
FROM Venta.Carrito c
JOIN Cliente.Cliente cl ON c.Id_cliente = cl.Id_cliente
JOIN Product.Product p ON p.name = 'Mito Inca: La Leyenda'
WHERE cl.email LIKE '%@peru.com';

INSERT INTO Venta.Pedido (Id_cliente, id_metodo, carro_id, Total_pago, fecha_del_pedido, fecha_de_entrega, estado, promocionid)
SELECT c.Id_cliente, 1, c.carro_id, 49.99, GETDATE(), GETDATE(), 'entregado', NULL
FROM Venta.Carrito c
JOIN Cliente.Cliente cl ON c.Id_cliente = cl.Id_cliente
WHERE cl.email LIKE '%@peru.com';

INSERT INTO Venta.PedidoDetalles (pedido_id, productoid, cantidad_pedida, precio_prod)
SELECT p.pedido_id, prod.productid, 1, prod.precio_base
FROM Venta.Pedido p
JOIN Product.Product prod ON prod.name = 'Mito Inca: La Leyenda';

PRINT '¡Datos insertados correctamente en la Sucursal Perú!';
GO
