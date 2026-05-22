use [BD2_tienda]

-- ============================================================
--  DATOS DE PRUEBA
-- ============================================================
 
-- ============================================================
--  TABLAS BASE
-- ============================================================
 
INSERT INTO Paises (nombre) VALUES
('Bolivia'),
('Argentina'),
('Chile'),
('Peru'),
('Colombia'),
('Mexico'),
('Brasil'),
('Uruguay'),
('Paraguay'),
('Ecuador');

INSERT INTO Metodo_Pago (nombre) VALUES
('Tarjeta de Credito'),
('Tarjeta de Debito'),
('PayPal'),
('Transferencia Bancaria'),
('Criptomoneda');
 
-- ============================================================
--  PROMOCIONES
-- ============================================================
 
INSERT INTO Venta.Promocion (nombre, descuento, fecha_inicio, fecha_fin) VALUES
('Black Friday',         20.00, '2025-11-28', '2025-11-30'),
('Cyber Monday',         15.00, '2025-12-01', '2025-12-02'),
('Navidad',              10.00, '2025-12-20', '2025-12-25'),
('Año Nuevo',            25.00, '2025-12-31', '2026-01-02'),
('Verano Gaming',        12.00, '2026-01-10', '2026-02-10'),
('Semana Santa',          8.00, '2026-03-28', '2026-04-05');
 
-- ============================================================
--  CLIENTE
-- ============================================================
 
INSERT INTO Cliente.Cliente (nombre, nmedio, apellido, email, estado, numero_contacto, paisid) VALUES
('Juan',     'Carlos',  'Perez',    'juan.perez@gmail.com',     'activo',   '591-70012345', 1),
('Maria',    NULL,      'Lopez',    'maria.lopez@gmail.com',    'activo',   '591-70023456', 1),
('Diego',    'Andres',  'Mamani',   'diego.mamani@gmail.com',   'activo',   '591-70034567', 1),
('Sofia',    NULL,      'Rojas',    'sofia.rojas@gmail.com',    'activo',   '54-91123456',  2),
('Carlos',   'Luis',    'Gomez',    'carlos.gomez@gmail.com',   'activo',   '56-91234567',  3),
('Valentina',NULL,      'Torres',   'vale.torres@gmail.com',    'activo',   '51-91345678',  4),
('Andres',   'Felipe',  'Castro',   'andres.castro@gmail.com',  'activo',   '57-91456789',  5),
('Lucia',    NULL,      'Vargas',   'lucia.vargas@gmail.com',   'inactivo', '52-91567890',  6),
('Miguel',   'Angel',   'Quispe',   'miguel.quispe@gmail.com',  'activo',   '591-70045678', 1),
('Paula',    NULL,      'Mendoza',  'paula.mendoza@gmail.com',  'activo',   '598-91678901', 8),
('Roberto',  'Ivan',    'Flores',   'roberto.flores@gmail.com', 'activo',   '595-91789012', 9),
('Camila',   NULL,      'Herrera',  'camila.herrera@gmail.com', 'activo',   '593-91890123', 10),
('Fernando', 'Jose',    'Morales',  'fer.morales@gmail.com',    'activo',   '591-70056789', 1),
('Isabella', NULL,      'Ruiz',     'isa.ruiz@gmail.com',       'activo',   '54-92234567',  2),
('Sebastian','Matias',  'Jimenez',  'seba.jimenez@gmail.com',   'inactivo', '56-92345678',  3);
 
INSERT INTO Cliente.Cliente_Metodo_Pago (id_metodo, Id_cliente, numero_de_tarjeta, CVV, fecha_vencimiento) VALUES
(1, 1,  '4111111111111111', '123', '2027-12-01'),
(2, 1,  '4222222222222222', '456', '2026-08-01'),
(1, 2,  '4333333333333333', '789', '2028-03-01'),
(3, 3,  '4444444444444444', '321', '2027-06-01'),
(1, 4,  '4555555555555555', '654', '2026-11-01'),
(2, 5,  '4666666666666666', '987', '2027-09-01'),
(3, 6,  '4777777777777777', '111', '2028-01-01'),
(1, 7,  '4888888888888888', '222', '2026-07-01'),
(4, 8,  '4999999999999999', '333', '2027-04-01'),
(1, 9,  '5111111111111111', '444', '2028-05-01'),
(2, 10, '5222222222222222', '555', '2026-10-01'),
(5, 11, '5333333333333333', '666', '2027-02-01'),
(1, 12, '5444444444444444', '777', '2028-08-01'),
(3, 13, '5555555555555555', '888', '2026-12-01'),
(2, 14, '5666666666666666', '999', '2027-07-01');
 
-- ============================================================
--  PRODUCT
-- ============================================================
 
INSERT INTO Product.Categoria (nombre) VALUES
('Accion'),
('Aventura'),
('RPG'),
('Shooter'),
('Deportes'),
('Estrategia'),
('Terror'),
('Simulacion'),
('Pelea'),
('Plataformas');
 
INSERT INTO Product.Plataforma (nombre) VALUES
('PC'),
('PlayStation 5'),
('Xbox Series X'),
('Nintendo Switch'),
('PlayStation 4');
 
INSERT INTO Product.Edicion (name, estado) VALUES
('Estandar',        'activo'),
('Deluxe',          'activo'),
('Gold',            'activo'),
('Ultimate',        'activo'),
('Game of the Year','activo'),
('Anniversary',     'activo');
 
INSERT INTO Product.Developer (name) VALUES
('FromSoftware'),
('Naughty Dog'),
('CD Projekt Red'),
('Rockstar Games'),
('Nintendo'),
('Ubisoft'),
('Bethesda'),
('Square Enix'),
('Capcom'),
('Valve');
 
-- Juegos base
INSERT INTO Product.Product (name, developerid, estado, tipo_juego, juego_base, precio_base, fecha_de_lanzamiento) VALUES
('Elden Ring',                  1, 'activo', 'juego', NULL, NULL, NULL),
('The Last of Us Part II',      2, 'activo', 'juego', NULL, NULL, NULL),
('Cyberpunk 2077',              3, 'activo', 'juego', NULL, NULL, NULL),
('Red Dead Redemption 2',       4, 'activo', 'juego', NULL, NULL, NULL),
('The Legend of Zelda TOTK',    5, 'activo', 'juego', NULL, NULL, NULL),
('Assassins Creed Mirage',      6, 'activo', 'juego', NULL, NULL, NULL),
('Starfield',                   7, 'activo', 'juego', NULL, NULL, NULL),
('Final Fantasy XVI',           8, 'activo', 'juego', NULL, NULL, NULL),
('Resident Evil 4 Remake',      9, 'activo', 'juego', NULL, NULL, NULL),
('Half Life Alyx',              10,'activo', 'juego', NULL, NULL, NULL);
 
-- DLCs y complementos (juego_base referencia al productid del juego base)
INSERT INTO Product.Product (name, developerid, estado, tipo_juego, juego_base, precio_base, fecha_de_lanzamiento) VALUES
('Elden Ring - Shadow of the Erdtree',      1, 'activo', 'dlc',         1,  39.99, '2024-06-21'),
('Cyberpunk 2077 - Phantom Liberty',        3, 'activo', 'dlc',         3,  29.99, '2023-09-26'),
('Starfield - Shattered Space',             7, 'activo', 'dlc',         7,  29.99, '2024-09-30'),
('Final Fantasy XVI - The Rising Tide',     8, 'activo', 'dlc',         8,  19.99, '2024-04-18'),
('Resident Evil 4 - Separate Ways',         9, 'activo', 'dlc',         9,  9.99,  '2023-09-21'),
('Red Dead Online Outlaw Pass',             4, 'activo', 'complemento', 4,  9.99,  '2023-11-15'),
('Zelda - Pack de Expansion TOTK',          5, 'activo', 'complemento', 5,  14.99, '2024-02-10');
 
-- ============================================================
--  RELACIONES DE PRODUCTO
-- ============================================================
 
INSERT INTO Product.ProductPlataforma (productid, id_plataforma) VALUES
(1, 1),(1, 2),(1, 3),   -- Elden Ring: PC, PS5, Xbox
(2, 2),(2, 5),           -- Last of Us: PS5, PS4
(3, 1),(3, 2),(3, 3),   -- Cyberpunk: PC, PS5, Xbox
(4, 1),(4, 2),(4, 3),(4, 5), -- RDR2: PC, PS5, Xbox, PS4
(5, 4),                  -- Zelda: Switch
(6, 1),(6, 2),(6, 3),   -- AC Mirage: PC, PS5, Xbox
(7, 1),(7, 3),           -- Starfield: PC, Xbox
(8, 2),                  -- FF XVI: PS5
(9, 1),(9, 2),(9, 3),   -- RE4: PC, PS5, Xbox
(10,1);                  -- Half Life: PC
 
INSERT INTO Product.CategoriaProduct (productid, id_categoria) VALUES
(1, 1),(1, 3),   -- Elden Ring: Accion, RPG
(2, 1),(2, 2),   -- Last of Us: Accion, Aventura
(3, 1),(3, 3),   -- Cyberpunk: Accion, RPG
(4, 1),(4, 2),   -- RDR2: Accion, Aventura
(5, 2),(5, 3),   -- Zelda: Aventura, RPG
(6, 1),(6, 2),   -- AC Mirage: Accion, Aventura
(7, 3),(7, 8),   -- Starfield: RPG, Simulacion
(8, 3),          -- FF XVI: RPG
(9, 1),(9, 7),   -- RE4: Accion, Terror
(10,1),(10,4);   -- Half Life: Accion, Shooter
 
-- ============================================================
--  EDICIONES Y PRECIOS
-- ============================================================
 
INSERT INTO Product.EdicionProduct (productid, edicionid, precio, fecha_lanzamiento) VALUES
-- Elden Ring
(1, 1, 59.99, '2022-02-25'),   -- Estandar
(1, 2, 79.99, '2022-02-25'),   -- Deluxe
(1, 4, 99.99, '2022-02-25'),   -- Ultimate
-- Last of Us
(2, 1, 49.99, '2020-06-19'),
(2, 5, 59.99, '2022-01-14'),   -- GOTY
-- Cyberpunk 2077
(3, 1, 59.99, '2020-12-10'),
(3, 2, 79.99, '2020-12-10'),
(3, 4, 99.99, '2023-09-26'),   -- Ultimate con Phantom Liberty
-- RDR2
(4, 1, 49.99, '2018-10-26'),
(4, 5, 59.99, '2019-08-13'),
-- Zelda TOTK
(5, 1, 69.99, '2023-05-12'),
-- AC Mirage
(6, 1, 49.99, '2023-10-05'),
(6, 2, 59.99, '2023-10-05'),
-- Starfield
(7, 1, 69.99, '2023-09-06'),
(7, 2, 99.99, '2023-09-06'),   -- Deluxe
-- FF XVI
(8, 1, 69.99, '2023-06-22'),
(8, 2, 84.99, '2023-06-22'),
-- RE4
(9, 1, 59.99, '2023-03-24'),
(9, 2, 69.99, '2023-03-24'),
-- Half Life Alyx
(10,1, 59.99, '2020-03-23');
 
-- ============================================================
--  EJEMPLARES (codigos de canje unicos)
-- ============================================================
 
-- Elden Ring Estandar (edicionproductid = 1)
INSERT INTO Product.Ejemplar (productid, edicionproductid, canjear_codigo, estado) VALUES
(NULL, 1,  'ER-EST-00001', 'activo'),
(NULL, 1,  'ER-EST-00002', 'activo'),
(NULL, 1,  'ER-EST-00003', 'activo'),
(NULL, 1,  'ER-EST-00004', 'comprado'),
(NULL, 1,  'ER-EST-00005', 'comprado'),
-- Elden Ring Deluxe (edicionproductid = 2)
(NULL, 2,  'ER-DLX-00001', 'activo'),
(NULL, 2,  'ER-DLX-00002', 'activo'),
(NULL, 2,  'ER-DLX-00003', 'comprado'),
-- Cyberpunk Estandar (edicionproductid = 6)
(NULL, 6,  'CP-EST-00001', 'activo'),
(NULL, 6,  'CP-EST-00002', 'activo'),
(NULL, 6,  'CP-EST-00003', 'comprado'),
-- Cyberpunk Ultimate (edicionproductid = 8)
(NULL, 8,  'CP-ULT-00001', 'activo'),
(NULL, 8,  'CP-ULT-00002', 'activo'),
-- Last of Us Estandar (edicionproductid = 4)
(NULL, 4,  'LOU-EST-00001', 'activo'),
(NULL, 4,  'LOU-EST-00002', 'comprado'),
-- Zelda (edicionproductid = 11)
(NULL, 11, 'ZLD-EST-00001', 'activo'),
(NULL, 11, 'ZLD-EST-00002', 'activo'),
(NULL, 11, 'ZLD-EST-00003', 'comprado'),
-- RE4 Estandar (edicionproductid = 18)
(NULL, 18, 'RE4-EST-00001', 'activo'),
(NULL, 18, 'RE4-EST-00002', 'activo'),
-- DLCs (productid directo, edicionproductid NULL)
(11, NULL, 'DLC-ER-SOTE-001', 'activo'),
(11, NULL, 'DLC-ER-SOTE-002', 'activo'),
(11, NULL, 'DLC-ER-SOTE-003', 'comprado'),
(12, NULL, 'DLC-CP-PL-001',   'activo'),
(12, NULL, 'DLC-CP-PL-002',   'comprado'),
(15, NULL, 'DLC-RE4-SW-001',  'activo'),
(16, NULL, 'COMP-RDO-OP-001', 'activo'),
(17, NULL, 'COMP-ZLD-EX-001', 'activo');
 
-- ============================================================
--  INVENTARIO
-- ============================================================
 
-- Juegos (por edicionproductid)
INSERT INTO Product.Inventario (productid, edicionproductid, cantidad) VALUES
(NULL, 1,  3),   -- Elden Ring Estandar
(NULL, 2,  2),   -- Elden Ring Deluxe
(NULL, 4,  1),   -- Last of Us Estandar
(NULL, 6,  2),   -- Cyberpunk Estandar
(NULL, 8,  2),   -- Cyberpunk Ultimate
(NULL, 11, 2),   -- Zelda Estandar
(NULL, 18, 2),   -- RE4 Estandar
-- DLCs (por productid)
(11, NULL, 2),   -- Elden Ring SOTE
(12, NULL, 1),   -- Cyberpunk Phantom Liberty
(15, NULL, 1),   -- RE4 Separate Ways
(16, NULL, 1),   -- RDO Outlaw Pass
(17, NULL, 1);   -- Zelda Pack Expansion
 
-- ============================================================
--  PROVEEDORES Y MOVIMIENTOS
-- ============================================================
 
INSERT INTO Provedor.Provedor (nombre) VALUES
('GameDistrib SA'),
('DigitalKeys Bolivia'),
('SteamKeys Latam'),
('PSN Distribuidor Oficial'),
('Xbox Game Pass Proveedor');
 
INSERT INTO Product.MovimientoInventario (productid, edicionproductid, cantidad, fecha, provedorid) VALUES
-- Entradas juegos
(1,  1,  5, '2025-01-10', 1),
(1,  2,  3, '2025-01-10', 1),
(2,  4,  3, '2025-01-12', 4),
(3,  6,  4, '2025-01-15', 3),
(3,  8,  2, '2025-01-15', 3),
(5,  11, 5, '2025-01-20', 1),
(9,  18, 4, '2025-02-01', 4),
-- Salidas por ventas
(1,  1,  2, '2025-02-10', NULL),
(2,  4,  2, '2025-02-15', NULL),
(3,  6,  2, '2025-02-20', NULL),
-- Entradas DLCs
(11, NULL, 5, '2025-03-01', 2),
(12, NULL, 3, '2025-03-01', 3),
(15, NULL, 2, '2025-03-05', 4),
-- Salidas DLCs
(11, NULL, 3, '2025-03-15', NULL),
(12, NULL, 2, '2025-03-20', NULL);
 
-- ============================================================
--  CARRITOS
-- ============================================================
 
INSERT INTO Venta.Carrito (Id_cliente, estado, fecha_creacion, fecha_cierre) VALUES
(1,  'completado', '2025-02-10', '2025-02-10'),
(2,  'completado', '2025-02-15', '2025-02-15'),
(3,  'completado', '2025-02-20', '2025-02-20'),
(4,  'abandonado', '2025-02-22', '2025-03-01'),
(5,  'completado', '2025-03-01', '2025-03-01'),
(6,  'activo',     '2025-03-10', NULL),
(7,  'activo',     '2025-03-12', NULL),
(9,  'en_proceso', '2025-03-14', NULL),
(10, 'abandonado', '2025-02-28', '2025-03-07'),
(13, 'activo',     '2025-03-15', NULL);
 
INSERT INTO Venta.CarroDetalles (carro_id, productoid, cantidad_pedida, precio_prod) VALUES
-- Carrito 1 (completado - cliente 1)
(1, 1,  1, 59.99),  -- Elden Ring Estandar
(1, 11, 1, 39.99),  -- DLC Shadow of Erdtree
-- Carrito 2 (completado - cliente 2)
(2, 3,  1, 59.99),  -- Cyberpunk Estandar
-- Carrito 3 (completado - cliente 3)
(3, 9,  1, 59.99),  -- RE4 Estandar
(3, 15, 1, 9.99),   -- RE4 Separate Ways
-- Carrito 4 (abandonado - cliente 4)
(4, 5,  1, 69.99),  -- Zelda
(4, 17, 1, 14.99),  -- Zelda Pack Expansion
-- Carrito 5 (completado - cliente 5)
(5, 2,  1, 49.99),  -- Last of Us
-- Carrito 6 (activo - cliente 6)
(6, 7,  1, 69.99),  -- Starfield
(6, 13, 1, 29.99),  -- Starfield DLC
-- Carrito 7 (activo - cliente 7)
(7, 8,  1, 69.99),  -- FF XVI
(7, 14, 1, 19.99),  -- FF XVI DLC
-- Carrito 8 (en proceso - cliente 9)
(8, 1,  1, 79.99),  -- Elden Ring Deluxe
(8, 12, 1, 29.99),  -- Cyberpunk Phantom Liberty
-- Carrito 9 (abandonado - cliente 10)
(9, 4,  1, 49.99),  -- RDR2
(9, 16, 1, 9.99),   -- RDO Outlaw Pass
-- Carrito 10 (activo - cliente 13)
(10, 3, 1, 99.99),  -- Cyberpunk Ultimate
(10, 6, 1, 49.99);  -- AC Mirage
 
-- ============================================================
--  PEDIDOS (solo de carritos completados)
-- ============================================================
 
INSERT INTO Venta.Pedido (Id_cliente, id_metodo, carro_id, Total_pago, fecha_del_pedido, fecha_de_entrega, estado, promocionid) VALUES
(1, 1, 1, 99.98,  '2025-02-10', '2025-02-10', 'entregado', NULL),
(2, 3, 2, 59.99,  '2025-02-15', '2025-02-15', 'entregado', NULL),
(3, 1, 3, 69.98,  '2025-02-20', '2025-02-20', 'entregado', NULL),
(5, 2, 5, 49.99,  '2025-03-01', '2025-03-01', 'entregado', NULL);
 
INSERT INTO Venta.PedidoDetalles (pedido_id, productoid, cantidad_pedida, precio_prod) VALUES
-- Pedido 1
(1, 1,  1, 59.99),
(1, 11, 1, 39.99),
-- Pedido 2
(2, 3,  1, 59.99),
-- Pedido 3
(3, 9,  1, 59.99),
(3, 15, 1, 9.99),
-- Pedido 4
(4, 2,  1, 49.99);
 
