use [BD2_tienda]



-- ============================================================
--  TABLAS BASE
-- ============================================================

CREATE TABLE Paises (
    paisid  INT         PRIMARY KEY IDENTITY(1,1),
    nombre  VARCHAR(50) NOT NULL
);

CREATE TABLE Metodo_Pago (
    id_metodo  INT         PRIMARY KEY IDENTITY(1,1),
    nombre     VARCHAR(30) NOT NULL
);

CREATE TABLE Venta.Promocion (
    promocionid   INT           PRIMARY KEY IDENTITY(1,1),
    nombre        VARCHAR(50)   NOT NULL,
    descuento     DECIMAL(5,2)  NOT NULL,
    fecha_inicio  DATE          NOT NULL,
    fecha_fin     DATE          NOT NULL,
    CONSTRAINT chk_promo_fechas CHECK (fecha_fin >= fecha_inicio)
);

-- ============================================================
--  CLIENTE
-- ============================================================

CREATE TABLE Cliente.Cliente (
    Id_cliente       INT         PRIMARY KEY IDENTITY(1,1),
    nombre           VARCHAR(50) NOT NULL,
    nmedio           VARCHAR(50),
    apellido         VARCHAR(50) NOT NULL,
    email            VARCHAR(50) NOT NULL UNIQUE,
    estado           VARCHAR(20) NOT NULL DEFAULT 'activo',
    numero_contacto  VARCHAR(30),
    paisid           INT         FOREIGN KEY REFERENCES Paises(paisid)
);

CREATE TABLE Cliente.Cliente_Metodo_Pago (
    Cliente_metodo    INT         PRIMARY KEY IDENTITY(1,1),
    id_metodo         INT         NOT NULL FOREIGN KEY REFERENCES Metodo_Pago(id_metodo),
    Id_cliente        INT         NOT NULL FOREIGN KEY REFERENCES Cliente.Cliente(Id_cliente),
    numero_de_tarjeta VARCHAR(50) NOT NULL,
    CVV               CHAR(3)     NOT NULL,
    fecha_vencimiento DATE        NOT NULL
);

-- ============================================================
--  PRODUCT
-- ============================================================

CREATE TABLE Product.Categoria (
    id_categoria  INT         PRIMARY KEY IDENTITY(1,1),
    nombre        VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Product.Plataforma (
    id_plataforma  INT         PRIMARY KEY IDENTITY(1,1),
    nombre         VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Product.Edicion (
    edicionid  INT         PRIMARY KEY IDENTITY(1,1),  -- no habra ediciones para los complementos
    name       VARCHAR(20) NOT NULL,
    estado  varchar(20) default 'no activo'
    
);

CREATE TABLE Product.Developer (
    developerid  INT         PRIMARY KEY IDENTITY(1,1),
    name         VARCHAR(50) NOT NULL
);

CREATE TABLE Product.Product (
    productid             INT           PRIMARY KEY IDENTITY(1,1),
    name                  VARCHAR(50)   NOT NULL,
    developerid           INT           FOREIGN KEY REFERENCES Product.Developer(developerid),
    estado                VARCHAR(20)   NOT NULL DEFAULT 'activo',
    tipo_juego           varchar(20)   not null default 'juego',
    juego_base            int  null foreign key references Product.Product(productid),--dlc
    precio_base           DECIMAL(10,2) NULL, -- solo para DLCs o complementos
    fecha_de_lanzamiento  DATE          NULL -- solo para DLCs o complementos
-- auto referencia para poder tener DLCS y complementos dentro de esta tabla y ocupar la estructura creada
    
    
);

CREATE TABLE Product.ProductPlataforma ( -- puede estar en producto o en ejemplar
    productplataforma  INT  PRIMARY KEY IDENTITY(1,1),
    productid          INT  NOT NULL FOREIGN KEY REFERENCES Product.Product(productid),
    id_plataforma      INT  NOT NULL FOREIGN KEY REFERENCES Product.Plataforma(id_plataforma)
    
);

CREATE TABLE Product.CategoriaProduct (
    catproduc_id  INT  PRIMARY KEY IDENTITY(1,1),
    productid     INT  NOT NULL FOREIGN KEY REFERENCES Product.Product(productid),
    id_categoria  INT  NOT NULL FOREIGN KEY REFERENCES Product.Categoria(id_categoria)
    
);

CREATE TABLE Product.EdicionProduct (
    edicionproductid INT  PRIMARY KEY IDENTITY(1,1),
    productid        INT  NOT NULL FOREIGN KEY REFERENCES Product.Product(productid),
    edicionid         INT  NOT NULL FOREIGN KEY REFERENCES Product.Edicion(edicionid),
    precio            DECIMAL(10,2) NOT NULL,
    fecha_lanzamiento date  -- cada edicion tiene su propia fecha de lanzamiento
    

);
CREATE TABLE Product.Ejemplar (
    id_ejemplar     INT         PRIMARY KEY IDENTITY(1,1),
productid        INT   NULL FOREIGN KEY REFERENCES Product.Product(productid), -- null si es juego y no null si es complemento
    edicionproductid  INT  null foreign key references Product.EdicionProduct(edicionproductid),  --Null si es complemento y no null si es juego
    canjear_codigo  VARCHAR(50) NOT NULL UNIQUE,
    estado          VARCHAR(20) NOT NULL DEFAULT 'activo'
    
);

CREATE TABLE Product.Inventario (
    inventoryid  INT  PRIMARY KEY IDENTITY(1,1),
productid        INT   NULL FOREIGN KEY REFERENCES Product.Product(productid),
   edicionproductid  INT  null foreign key references Product.EdicionProduct(edicionproductid),
    cantidad     INT  NOT NULL DEFAULT 0
   
);



-- ============================================================
--  PROVEEDOR Y MOVIMIENTOS
-- ============================================================

CREATE TABLE Provedor.Provedor (
    provedorid  INT         PRIMARY KEY IDENTITY(1,1),
    nombre      VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Product.MovimientoInventario (
    movimientoid  INT           PRIMARY KEY IDENTITY(1,1),
    productid     INT           NOT NULL FOREIGN KEY REFERENCES Product.Product(productid),
edicionproductid  INT null foreign key references Product.EdicionProduct(edicionproductid), -- puede ser null porque tambien se nos entregara dlcs ,
   -- no vamos usar(era para ver si era entrada o salida) tipo          VARCHAR-- (20)   NOT NULL
    cantidad      INT           NOT NULL,
    fecha         DATE          NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    provedorid    INT           FOREIGN KEY REFERENCES Provedor.Provedor(provedorid)
    
);
 
/* no vamos a usar
CREATE TABLE Product.MovimientoEjemplaresnuevos (
    MovimientoEjemplaresnuevos  INT  PRIMARY KEY IDENTITY(1,1),
    movimientoid                INT  NOT NULL FOREIGN KEY REFERENCES Product.MovimientoInventario(movimientoid),
    id_ejemplar                 INT  NOT NULL FOREIGN KEY REFERENCES Product.Ejemplar(id_ejemplar)
);

*/

-- ============================================================
--  VENTA: CARRITO
--
--  Ciclo de vida:
--    activo     -> cliente agregando productos
--    en_proceso -> cliente en checkout
--    completado -> se genero un Pedido (actualizar manualmente desde la app)
--    abandonado -> nunca se completo
-- ============================================================

CREATE TABLE Venta.Carrito (
    carro_id        INT         PRIMARY KEY IDENTITY(1,1),
    Id_cliente      INT         NOT NULL FOREIGN KEY REFERENCES Cliente.Cliente(Id_cliente),
    estado          VARCHAR(20) NOT NULL DEFAULT 'activo',
    fecha_creacion  DATE        NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    fecha_cierre    DATE        NULL
    
);

create TABLE Venta.CarroDetalles (
    detallesid      INT           PRIMARY KEY IDENTITY(1,1),
    carro_id        INT           NOT NULL  FOREIGN KEY REFERENCES Venta.Carrito(carro_id),
    productoid      INT          NOT NULL  FOREIGN KEY REFERENCES Product.Product(productid),
    cantidad_pedida INT           NOT NULL,
    precio_prod     DECIMAL(10,2) NOT NULL
    
);



   
    



-- ============================================================
--  VENTA: PEDIDO
-- ============================================================

CREATE TABLE Venta.Pedido (
    pedido_id         INT           PRIMARY KEY IDENTITY(1,1),
    Id_cliente        INT           NOT NULL FOREIGN KEY REFERENCES Cliente.Cliente(Id_cliente),
    id_metodo         INT           NOT NULL FOREIGN KEY REFERENCES Metodo_Pago(id_metodo),
    carro_id          INT           NOT NULL UNIQUE FOREIGN KEY REFERENCES Venta.Carrito(carro_id),
    Total_pago        DECIMAL(10,2) NOT NULL,
    fecha_del_pedido  DATE          NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    fecha_de_entrega  date  ,
    estado            VARCHAR(20)   NOT NULL DEFAULT 'pendiente',
    promocionid       INT           FOREIGN KEY REFERENCES Venta.Promocion(promocionid)
   
);



CREATE TABLE Venta.PedidoDetalles (
    pedidodetallesid  INT           PRIMARY KEY IDENTITY(1,1),
    pedido_id         INT           NOT NULL  FOREIGN KEY REFERENCES Venta.Pedido(pedido_id),
    productoid        INT           NOT NULL  FOREIGN KEY REFERENCES Product.Product(productid),
    cantidad_pedida   INT           NOT NULL,
    precio_prod       DECIMAL(10,2) NOT NULL
    
);
