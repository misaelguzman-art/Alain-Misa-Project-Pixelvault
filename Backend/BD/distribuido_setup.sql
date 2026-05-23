-- ========================================================================================
-- SCRIPT DE CONFIGURACIÓN DISTRIBUIDA (CENTRAL BOLIVIA Y SUCURSAL PERÚ)
-- ========================================================================================
-- Este script realiza:
-- 1. Eliminación segura en cascada de clientes que no pertenezcan a Bolivia (1) o Perú (4).
-- 2. Creación de la tabla de Configuración Local y columna de Ámbito Geográfico en Productos.
-- 3. Modificación del SP AgregarCliente para blindar geográficamente el registro en Perú.
-- 4. Modificación del SP CrearProductoAdmin para proteger la creación de juegos globales.
-- 5. Creación de las vistas unificadas filtradas por país (usando Linked Server en Perú).
-- 6. Creación de un Trigger de protección en Perú para evitar modificaciones a datos de otros nodos.
-- ========================================================================================

-- A. ASEGURAR NOMBRE DE LA BASE DE DATOS CORRECTA
-- (Por favor ejecuta este script en la base de datos correspondiente: 'BD2_tienda' o 'NodoSucursal')
-- USE [BD2_tienda]; -- Habilitar en Central Bolivia
-- USE [NodoSucursal]; -- Habilitar en Sucursal Perú
GO

-- ========================================================================================
-- 1. ELIMINACIÓN DE CLIENTES DE OTROS PAÍSES (EN CASCADA SEGURA)
-- ========================================================================================
PRINT '1. Iniciando eliminación en cascada de clientes ajenos a Bolivia (1) y Perú (4)...';

-- 1.1 Borrar detalles de pedidos asociados a clientes eliminados
DELETE pd
FROM Venta.PedidoDetalles pd
JOIN Venta.Pedido p ON pd.pedido_id = p.pedido_id
JOIN Cliente.Cliente c ON p.Id_cliente = c.Id_cliente
WHERE c.paisid NOT IN (1, 4) OR c.paisid IS NULL;

-- 1.2 Borrar pedidos asociados a clientes eliminados
DELETE p
FROM Venta.Pedido p
JOIN Cliente.Cliente c ON p.Id_cliente = c.Id_cliente
WHERE c.paisid NOT IN (1, 4) OR c.paisid IS NULL;

-- 1.3 Borrar detalles de carritos asociados a clientes eliminados
DELETE cd
FROM Venta.CarroDetalles cd
JOIN Venta.Carrito ca ON cd.carro_id = ca.carro_id
JOIN Cliente.Cliente c ON ca.Id_cliente = c.Id_cliente
WHERE c.paisid NOT IN (1, 4) OR c.paisid IS NULL;

-- 1.4 Borrar carritos asociados a clientes eliminados
DELETE ca
FROM Venta.Carrito ca
JOIN Cliente.Cliente c ON ca.Id_cliente = c.Id_cliente
WHERE c.paisid NOT IN (1, 4) OR c.paisid IS NULL;

-- 1.5 Borrar métodos de pago asociados a clientes eliminados
DELETE cmp
FROM Cliente.Cliente_Metodo_Pago cmp
JOIN Cliente.Cliente c ON cmp.Id_cliente = c.Id_cliente
WHERE c.paisid NOT IN (1, 4) OR c.paisid IS NULL;

-- 1.6 Borrar de forma final los clientes
DELETE FROM Cliente.Cliente
WHERE (paisid NOT IN (1, 4) OR paisid IS NULL)
  AND email NOT IN ('admin@gmail.com', 'vendedor@gmail.com'); -- Proteger cuentas de sistema

PRINT '¡Clientes ajenos eliminados de forma segura!';
GO


-- ========================================================================================
-- 2. ESTRUCTURA GEOGRÁFICA Y CONFIGURACIÓN LOCAL
-- ========================================================================================
PRINT '2. Creando estructuras geográficas locales...';

-- 2.1 Tabla para almacenar la configuración de nodo local
IF OBJECT_ID('dbo.ConfiguracionLocal', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ConfiguracionLocal (
        pais_local_id INT NOT NULL FOREIGN KEY REFERENCES Paises(paisid)
    );
END
GO

-- 2.2 Agregar columna 'paisid' a tabla Product.Product para control geográfico
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Product.Product') AND name = 'paisid')
BEGIN
    ALTER TABLE Product.Product ADD paisid INT NULL FOREIGN KEY REFERENCES Paises(paisid);
    PRINT 'Columna paisid agregada a Product.Product.';
END
GO


-- ========================================================================================
-- INSTRUCCIONES DE REGISTRO DE CONFIGURACIÓN (EJECUTAR EN CADA INSTANCIA RESPECTIVA)
-- ========================================================================================
/*
-- [EN NODO CENTRAL - BOLIVIA]:
TRUNCATE TABLE dbo.ConfiguracionLocal;
INSERT INTO dbo.ConfiguracionLocal (pais_local_id) VALUES (1); -- 1 = Bolivia
PRINT 'Nodo Central configurado como Bolivia.';

-- [EN NODO SUCURSAL - PERÚ]:
TRUNCATE TABLE dbo.ConfiguracionLocal;
INSERT INTO dbo.ConfiguracionLocal (pais_local_id) VALUES (4); -- 4 = Perú
PRINT 'Nodo Sucursal configurado como Perú.';
*/


-- ========================================================================================
-- 3. STORED PROCEDURES DE CONTROL GEOGRÁFICO
-- ========================================================================================
PRINT '3. Actualizando Stored Procedures de Control Geográfico...';

-- 3.1 AgregarCliente con Bloqueo Geográfico en Perú
GO
CREATE OR ALTER PROCEDURE AgregarCliente
    @nombre VARCHAR(50),
    @medio VARCHAR(50) = NULL,
    @apellido VARCHAR(50),
    @correo VARCHAR(50),
    @paisid INT,
    @numero_contacto VARCHAR(20),
    @contrasena VARCHAR(255) = '12345'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @PaisLocalID INT = NULL;
    
    -- Obtener el ID del nodo local
    IF OBJECT_ID('dbo.ConfiguracionLocal', 'U') IS NOT NULL
    BEGIN
        SELECT TOP 1 @PaisLocalID = pais_local_id FROM dbo.ConfiguracionLocal;
    END

    -- Validación geográfica: si estamos en Perú (4), solo permitimos Perú (4)
    IF @PaisLocalID = 4 AND @paisid <> 4
    BEGIN
        THROW 51000, 'el pais no esta disponible para nuestro servicios por ahora', 1;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;
            
            INSERT INTO Cliente.Cliente (nombre, nmedio, apellido, email, estado, paisid, numero_contacto, rol, contrasena)
            VALUES (@nombre, @medio, @apellido, @correo, 'activo', @paisid, @numero_contacto, 'cliente', @contrasena);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW; 
    END CATCH
END;
GO

-- 3.2 CrearProductoAdmin con Control de Juegos Globales y Locales
CREATE OR ALTER PROCEDURE dbo.CrearProductoAdmin
    @name VARCHAR(50),
    @developerid INT,
    @tipo_juego VARCHAR(20) = 'juego',
    @juego_base INT = NULL,
    @precio_base DECIMAL(10,2) = NULL,
    @fecha_de_lanzamiento DATE = NULL,
    @paisid INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @PaisLocalID INT = NULL;
    
    IF OBJECT_ID('dbo.ConfiguracionLocal', 'U') IS NOT NULL
    BEGIN
        SELECT TOP 1 @PaisLocalID = pais_local_id FROM dbo.ConfiguracionLocal;
    END

    -- Si estamos en Perú (4), solo podemos crear juegos locales de Perú (4)
    -- No permitimos crear juegos globales (NULL) ni de otros países.
    IF @PaisLocalID = 4 AND (@paisid IS NULL OR @paisid <> 4)
    BEGIN
        THROW 52000, 'La sucursal de Perú solo puede registrar juegos de Perú (no globales ni de otros países).', 1;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;
        
        INSERT INTO Product.Product (name, developerid, estado, tipo_juego, juego_base, precio_base, fecha_de_lanzamiento, paisid)
        VALUES (@name, @developerid, 'activo', @tipo_juego, @juego_base, @precio_base, @fecha_de_lanzamiento, @paisid);
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


-- ========================================================================================
-- 4. VISTAS DISTRIBUIDAS (VISIBILIDAD FILTRADA)
-- ========================================================================================
PRINT '4. Creando Vistas Distribuidas...';
GO

-- [CREAR EN CENTRAL BOLIVIA (BD2_tienda)]
/*
CREATE OR ALTER VIEW Product.v_ProductCliente AS
SELECT productid, name, developerid, estado, tipo_juego, juego_base, precio_base, fecha_de_lanzamiento, paisid
FROM Product.Product
WHERE paisid = 1 OR paisid IS NULL; -- Solo juegos de Bolivia y globales
GO
*/

-- [CREAR EN SUCURSAL PERÚ (NodoSucursal) UTILIZANDO LINKED SERVER 'NODO_CENTRAL']
/*
CREATE OR ALTER VIEW Product.v_ProductCliente AS
SELECT productid, name, developerid, estado, tipo_juego, juego_base, precio_base, fecha_de_lanzamiento, paisid
FROM Product.Product
WHERE paisid = 4 -- Juegos locales de Perú
UNION ALL
SELECT productid, name, developerid, estado, tipo_juego, juego_base, precio_base, fecha_de_lanzamiento, paisid
FROM [NODO_CENTRAL].[BD2_tienda].[Product].[Product]
WHERE paisid IS NULL; -- Juegos globales consultados de forma distribuida en tiempo real de la Central
GO
*/


-- ========================================================================================
-- 5. TRIGGER DE PROTECCIÓN ABSOLUTA (INSTEAD OF UPDATE, DELETE EN PERÚ)
-- ========================================================================================
-- (Ejecutar solo en el nodo de Perú para evitar ediciones o borrados accidentales de otros nodos)
/*
GO
CREATE OR ALTER TRIGGER Product.trg_Protect_Product_Distribuidor
ON Product.Product
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PaisLocalID INT = NULL;
    IF OBJECT_ID('dbo.ConfiguracionLocal', 'U') IS NOT NULL
    BEGIN
        SELECT TOP 1 @PaisLocalID = pais_local_id FROM dbo.ConfiguracionLocal;
    END

    -- Validación solo en el nodo de Perú (4)
    IF @PaisLocalID = 4
    BEGIN
        -- Bloquear modificaciones o borrados si el registro no era de Perú o si se le intenta asignar otro país
        IF EXISTS (
            SELECT 1 FROM deleted WHERE paisid IS NULL OR paisid <> 4
        ) OR EXISTS (
            SELECT 1 FROM inserted WHERE paisid IS NULL OR paisid <> 4
        )
        BEGIN
            THROW 53000, 'La sucursal de Perú no tiene permisos para modificar o eliminar productos globales o de otros países.', 1;
            RETURN;
        END
    END

    -- Si pasa la validación, ejecutar la acción real
    -- OPERACIÓN UPDATE:
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        UPDATE p
        SET p.name = i.name,
            p.developerid = i.developerid,
            p.estado = i.estado,
            p.tipo_juego = i.tipo_juego,
            p.juego_base = i.juego_base,
            p.precio_base = i.precio_base,
            p.fecha_de_lanzamiento = i.fecha_de_lanzamiento,
            p.paisid = i.paisid
        FROM Product.Product p
        JOIN inserted i ON p.productid = i.productid;
    END
    -- OPERACIÓN DELETE:
    ELSE IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        DELETE p
        FROM Product.Product p
        JOIN deleted d ON p.productid = d.productid;
    END
END;
GO
*/

PRINT '=======================================================================================';
PRINT '¡Lógica de Base de Datos Distribuidora Generada e Integrada Exitosamente!';
PRINT '=======================================================================================';
GO
