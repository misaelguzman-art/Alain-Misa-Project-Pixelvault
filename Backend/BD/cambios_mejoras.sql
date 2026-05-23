USE [BD2_tienda];
GO

-- ============================================================
-- 1. MODIFICACIONES DE ESQUEMA (TABLAS)
-- ============================================================

-- 1.1 Agregar columnas 'rol' y 'contrasena' a Cliente.Cliente
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Cliente.Cliente') AND name = 'rol')
BEGIN
    ALTER TABLE Cliente.Cliente ADD rol VARCHAR(20) NOT NULL DEFAULT 'cliente';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Cliente.Cliente') AND name = 'contrasena')
BEGIN
    ALTER TABLE Cliente.Cliente ADD contrasena VARCHAR(255) NOT NULL DEFAULT '12345';
END
GO

-- Asegurar que todos los clientes existentes tengan la contraseña por defecto '12345'
UPDATE Cliente.Cliente SET contrasena = '12345' WHERE contrasena IS NULL OR contrasena = '';
GO

-- 1.2 Agregar columna 'estado' a Metodo_Pago
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Metodo_Pago') AND name = 'estado')
BEGIN
    ALTER TABLE Metodo_Pago ADD estado VARCHAR(20) NOT NULL DEFAULT 'activo';
END
GO

-- 1.3 Agregar columna 'estado' a Marketing.Promocion
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Marketing.Promocion') AND name = 'estado')
BEGIN
    ALTER TABLE Marketing.Promocion ADD estado VARCHAR(20) NOT NULL DEFAULT 'activo';
END
GO

-- ============================================================
-- 2. TABLA DE AUDITORÍA Y SUS TRIGGERS
-- ============================================================

-- 2.1 Crear tabla global Auditoria
IF OBJECT_ID('dbo.Auditoria', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Auditoria (
        id_auditoria INT IDENTITY(1,1) PRIMARY KEY,
        tabla_afectada VARCHAR(50) NOT NULL,
        operacion VARCHAR(20) NOT NULL, -- INSERT, UPDATE, DELETE
        fecha DATETIME NOT NULL DEFAULT GETDATE(),
        usuario VARCHAR(100) NOT NULL DEFAULT ORIGINAL_DB_NAME(),
        detalle NVARCHAR(MAX) NOT NULL
    );
END
GO

-- 2.2 Trigger para auditar cambios en Product.Product
CREATE OR ALTER TRIGGER Product.trg_Audit_Product
ON Product.Product
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.Auditoria (tabla_afectada, operacion, detalle)
        SELECT 'Product.Product', 'UPDATE', 
               'Producto ID: ' + CAST(i.productid AS VARCHAR) + 
               ', Nombre anterior: ' + d.name + ' -> Nuevo: ' + i.name + 
               ', Estado anterior: ' + d.estado + ' -> Nuevo: ' + i.estado
        FROM inserted i
        JOIN deleted d ON i.productid = d.productid;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.Auditoria (tabla_afectada, operacion, detalle)
        SELECT 'Product.Product', 'INSERT', 
               'Nuevo Producto ID: ' + CAST(i.productid AS VARCHAR) + 
               ', Nombre: ' + i.name + ', Tipo: ' + i.tipo_juego
        FROM inserted i;
    END
    ELSE IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.Auditoria (tabla_afectada, operacion, detalle)
        SELECT 'Product.Product', 'DELETE', 
               'Producto Eliminado ID: ' + CAST(d.productid AS VARCHAR) + 
               ', Nombre: ' + d.name
        FROM deleted d;
    END
END;
GO

-- 2.3 Trigger para auditar cambios en Product.Inventario
CREATE OR ALTER TRIGGER Product.trg_Audit_Inventario
ON Product.Inventario
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.Auditoria (tabla_afectada, operacion, detalle)
        SELECT 'Product.Inventario', 'UPDATE', 
               'Inventario ID: ' + CAST(i.inventoryid AS VARCHAR) + 
               ', Producto ID: ' + ISNULL(CAST(i.productid AS VARCHAR), 'NULL') +
               ', Edicion ID: ' + ISNULL(CAST(i.edicionproductid AS VARCHAR), 'NULL') +
               ', Cantidad anterior: ' + CAST(d.cantidad AS VARCHAR) + ' -> Nueva: ' + CAST(i.cantidad AS VARCHAR)
        FROM inserted i
        JOIN deleted d ON i.inventoryid = d.inventoryid;
    END
    ELSE IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.Auditoria (tabla_afectada, operacion, detalle)
        SELECT 'Product.Inventario', 'INSERT', 
               'Nuevo Inventario ID: ' + CAST(i.inventoryid AS VARCHAR) + 
               ', Producto ID: ' + ISNULL(CAST(i.productid AS VARCHAR), 'NULL') +
               ', Edicion ID: ' + ISNULL(CAST(i.edicionproductid AS VARCHAR), 'NULL') +
               ', Cantidad: ' + CAST(i.cantidad AS VARCHAR)
        FROM inserted i;
    END
END;
GO

-- 2.4 Trigger para auditar cambios en Venta.Pedido (cambios de estado)
CREATE OR ALTER TRIGGER Venta.trg_Audit_Pedido
ON Venta.Pedido
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.Auditoria (tabla_afectada, operacion, detalle)
    SELECT 'Venta.Pedido', 'UPDATE', 
           'Pedido ID: ' + CAST(i.pedido_id AS VARCHAR) + 
           ', Estado anterior: ' + d.estado + ' -> Nuevo: ' + i.estado +
           ', Total Pago: ' + CAST(i.Total_pago AS VARCHAR)
    FROM inserted i
    JOIN deleted d ON i.pedido_id = d.pedido_id
    WHERE i.estado <> d.estado;
END;
GO

-- ============================================================
-- 3. PROCEDIMIENTOS ALMACENADOS SOLICITADOS
-- ============================================================

-- 3.1 Entregar Pedido (pendiente a entregado)
CREATE OR ALTER PROCEDURE dbo.EntregarPedido
    @pedido_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        IF NOT EXISTS (SELECT 1 FROM Venta.Pedido WHERE pedido_id = @pedido_id)
        BEGIN
            RAISERROR('El pedido no existe.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        UPDATE Venta.Pedido
        SET estado = 'entregado',
            fecha_de_entrega = CAST(GETDATE() AS DATE)
        WHERE pedido_id = @pedido_id;

        COMMIT TRANSACTION;
        PRINT 'Pedido entregado correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @err_msg NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR(@err_msg, 16, 1);
    END CATCH
END;
GO

-- 3.2 Modificar stock de inventario (Vendedor y Admin)
-- Esta lógica calcula la diferencia e inserta una entrada/salida en MovimientoInventario
-- para no interferir con el trigger INSTEAD OF INSERT original
CREATE OR ALTER PROCEDURE dbo.ActualizarInventarioStock
    @productid INT = NULL,
    @edicionproductid INT = NULL,
    @cantidad INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        IF @cantidad < 0
        BEGIN
            RAISERROR('La cantidad de stock no puede ser negativa.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        DECLARE @stock_actual INT = 0;
        DECLARE @diff INT = 0;

        -- Obtener el stock actual
        IF @edicionproductid IS NOT NULL
        BEGIN
            SET @stock_actual = ISNULL((SELECT cantidad FROM Product.Inventario WHERE edicionproductid = @edicionproductid), 0);
            SET @diff = @cantidad - @stock_actual;

            IF @diff > 0
            BEGIN
                -- Entrada: insertamos con proveedor 2 ('DigitalKeys Bolivia' de prueba)
                INSERT INTO Product.MovimientoInventario (productid, edicionproductid, cantidad, fecha, provedorid)
                VALUES (
                    (SELECT productid FROM Product.EdicionProduct WHERE edicionproductid = @edicionproductid),
                    @edicionproductid,
                    @diff,
                    CAST(GETDATE() AS DATE),
                    2
                );

                -- AUTO-GENERAR EJEMPLARES (CD KEYS) PARA JUEGOS
                DECLARE @loop_i INT = 0;
                DECLARE @code_prefix VARCHAR(30) = 'KEY-' + CAST(@edicionproductid AS VARCHAR) + '-';
                WHILE @loop_i < @diff
                BEGIN
                    DECLARE @rand_code VARCHAR(50) = @code_prefix + SUBSTRING(REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', ''), 1, 10);
                    INSERT INTO Product.Ejemplar (productid, edicionproductid, canjear_codigo, estado)
                    VALUES (NULL, @edicionproductid, UPPER(@rand_code), 'activo');
                    SET @loop_i = @loop_i + 1;
                END
            END
            ELSE IF @diff < 0
            BEGIN
                -- Salida: insertamos con proveedor nulo
                INSERT INTO Product.MovimientoInventario (productid, edicionproductid, cantidad, fecha, provedorid)
                VALUES (
                    (SELECT productid FROM Product.EdicionProduct WHERE edicionproductid = @edicionproductid),
                    @edicionproductid,
                    ABS(@diff),
                    CAST(GETDATE() AS DATE),
                    NULL
                );

                -- Eliminar ABS(@diff) ejemplares activos de esta edición
                DELETE FROM Product.Ejemplar
                WHERE id_ejemplar IN (
                    SELECT TOP (ABS(@diff)) id_ejemplar 
                    FROM Product.Ejemplar 
                    WHERE edicionproductid = @edicionproductid AND estado = 'activo'
                );
            END
        END
        ELSE IF @productid IS NOT NULL
        BEGIN
            SET @stock_actual = ISNULL((SELECT cantidad FROM Product.Inventario WHERE productid = @productid AND edicionproductid IS NULL), 0);
            SET @diff = @cantidad - @stock_actual;

            IF @diff > 0
            BEGIN
                -- Entrada
                INSERT INTO Product.MovimientoInventario (productid, edicionproductid, cantidad, fecha, provedorid)
                VALUES (@productid, NULL, @diff, CAST(GETDATE() AS DATE), 2);

                -- AUTO-GENERAR EJEMPLARES (CD KEYS) PARA COMPLEMENTOS/DLCs
                DECLARE @loop_p INT = 0;
                DECLARE @code_prefix_p VARCHAR(30) = 'KEY-P' + CAST(@productid AS VARCHAR) + '-';
                WHILE @loop_p < @diff
                BEGIN
                    DECLARE @rand_code_p VARCHAR(50) = @code_prefix_p + SUBSTRING(REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', ''), 1, 10);
                    INSERT INTO Product.Ejemplar (productid, edicionproductid, canjear_codigo, estado)
                    VALUES (@productid, NULL, UPPER(@rand_code_p), 'activo');
                    SET @loop_p = @loop_p + 1;
                END
            END
            ELSE IF @diff < 0
            BEGIN
                -- Salida
                INSERT INTO Product.MovimientoInventario (productid, edicionproductid, cantidad, fecha, provedorid)
                VALUES (@productid, NULL, ABS(@diff), CAST(GETDATE() AS DATE), NULL);

                -- Eliminar ABS(@diff) ejemplares activos de este producto (DLC)
                DELETE FROM Product.Ejemplar
                WHERE id_ejemplar IN (
                    SELECT TOP (ABS(@diff)) id_ejemplar 
                    FROM Product.Ejemplar 
                    WHERE productid = @productid AND edicionproductid IS NULL AND estado = 'activo'
                );
            END
        END

        COMMIT TRANSACTION;
        PRINT 'Stock y ejemplares actualizados con éxito.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @err_msg NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR(@err_msg, 16, 1);
    END CATCH
END;
GO

-- 3.3 Modificar Stored Procedure AgregarCliente para incluir contraseña
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
    BEGIN TRY
        BEGIN TRANSACTION
            
            INSERT INTO Cliente.Cliente (nombre, nmedio, apellido, email, estado, paisid, numero_contacto, rol, contrasena)
            VALUES (@nombre, @medio, @apellido, @correo, 'activo', @paisid, @numero_contacto, 'cliente', @contrasena);

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW; 
    END CATCH
END;
GO

-- 3.4 Modificar Stored Procedure LoginCliente para validar contraseña y retornar rol
CREATE OR ALTER PROCEDURE LoginCliente
    @email VARCHAR(50),
    @contrasena VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Si no se provee contraseña (compatibilidad inicial), solo validar email
    IF @contrasena IS NULL
    BEGIN
        SELECT Id_cliente, nombre, apellido, email, estado, paisid, numero_contacto, rol
        FROM Cliente.Cliente
        WHERE email = @email AND estado = 'activo';
    END
    ELSE
    BEGIN
        SELECT Id_cliente, nombre, apellido, email, estado, paisid, numero_contacto, rol
        FROM Cliente.Cliente
        WHERE email = @email AND contrasena = @contrasena AND estado = 'activo';
    END
END;
GO

-- ============================================================
-- 4. PROCEDIMIENTOS ALMACENADOS CRUD PARA EL ADMINISTRADOR
-- ============================================================

-- 4.1 Productos: Crear
CREATE OR ALTER PROCEDURE dbo.CrearProductoAdmin
    @name VARCHAR(50),
    @developerid INT,
    @tipo_juego VARCHAR(20) = 'juego',
    @juego_base INT = NULL,
    @precio_base DECIMAL(10,2) = NULL,
    @fecha_de_lanzamiento DATE = NULL,
    @paisid INT = NULL,
    @stock_inicial INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @PaisLocalID INT = NULL;
    SELECT TOP 1 @PaisLocalID = pais_local_id FROM dbo.ConfiguracionLocal;

    IF @PaisLocalID = 4 AND (@paisid IS NULL OR @paisid <> 4)
    BEGIN
        THROW 52000, 'La sucursal de Perú solo puede registrar juegos de Perú (no globales ni de otros países).', 1;
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;
            INSERT INTO Product.Product (name, developerid, estado, tipo_juego, juego_base, precio_base, fecha_de_lanzamiento, paisid)
            VALUES (@name, @developerid, 'activo', @tipo_juego, @juego_base, @precio_base, @fecha_de_lanzamiento, @paisid);
            
            DECLARE @new_product_id INT = SCOPE_IDENTITY();

            IF @tipo_juego = 'juego'
            BEGIN
                -- Encontrar o insertar la edición estándar
                DECLARE @estandar_id INT;
                SELECT TOP 1 @estandar_id = edicionid FROM Product.Edicion WHERE name LIKE '%estandar%' OR name LIKE '%Estandar%' OR name LIKE '%Standard%';
                IF @estandar_id IS NULL
                BEGIN
                    INSERT INTO Product.Edicion (name) VALUES ('Estandar');
                    SET @estandar_id = SCOPE_IDENTITY();
                END

                -- Vincular a la edición estándar
                INSERT INTO Product.EdicionProduct (productid, edicionid, precio, fecha_lanzamiento)
                VALUES (@new_product_id, @estandar_id, ISNULL(@precio_base, 0), ISNULL(@fecha_de_lanzamiento, GETDATE()));
                
                DECLARE @new_ep_id INT = SCOPE_IDENTITY();

                -- Auto-generar Ejemplares si hay stock inicial
                IF @stock_inicial > 0
                BEGIN
                    -- Registrar movimiento de inventario (Entrada)
                    -- El trigger trg_MovimientoInventario insertará automáticamente la fila en Product.Inventario
                    INSERT INTO Product.MovimientoInventario (productid, edicionproductid, cantidad, fecha, provedorid)
                    VALUES (@new_product_id, @new_ep_id, @stock_inicial, CAST(GETDATE() AS DATE), 2);

                    DECLARE @loop_i INT = 0;
                    DECLARE @code_prefix VARCHAR(30) = 'KEY-' + CAST(@new_ep_id AS VARCHAR) + '-';
                    WHILE @loop_i < @stock_inicial
                    BEGIN
                        DECLARE @rand_code VARCHAR(50) = @code_prefix + SUBSTRING(REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', ''), 1, 10);
                        INSERT INTO Product.Ejemplar (productid, edicionproductid, canjear_codigo, estado)
                        VALUES (NULL, @new_ep_id, UPPER(@rand_code), 'activo');
                        SET @loop_i = @loop_i + 1;
                    END
                END
                ELSE
                BEGIN
                    -- Si es 0, inicializar inventario directamente (el trigger no se gatilla)
                    INSERT INTO Product.Inventario (productid, edicionproductid, cantidad)
                    VALUES (NULL, @new_ep_id, 0);
                END
            END
            ELSE
            BEGIN
                -- Para DLC o Complemento
                -- Registrar movimiento si stock_inicial > 0 y auto-generar llaves
                IF @stock_inicial > 0
                BEGIN
                    -- El trigger trg_MovimientoInventario insertará automáticamente la fila en Product.Inventario
                    INSERT INTO Product.MovimientoInventario (productid, edicionproductid, cantidad, fecha, provedorid)
                    VALUES (@new_product_id, NULL, @stock_inicial, CAST(GETDATE() AS DATE), 2);

                    DECLARE @loop_j INT = 0;
                    DECLARE @code_prefix_dlc VARCHAR(30) = 'KEY-DLC-' + CAST(@new_product_id AS VARCHAR) + '-';
                    WHILE @loop_j < @stock_inicial
                    BEGIN
                        DECLARE @rand_code_dlc VARCHAR(50) = @code_prefix_dlc + SUBSTRING(REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', ''), 1, 10);
                        INSERT INTO Product.Ejemplar (productid, edicionproductid, canjear_codigo, estado)
                        VALUES (@new_product_id, NULL, UPPER(@rand_code_dlc), 'activo');
                        SET @loop_j = @loop_j + 1;
                    END
                END
                ELSE
                BEGIN
                    -- Si es 0, inicializar inventario directamente
                    INSERT INTO Product.Inventario (productid, edicionproductid, cantidad)
                    VALUES (@new_product_id, NULL, 0);
                END
            END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4.2 Productos: Activar / Desactivar
CREATE OR ALTER PROCEDURE dbo.DesactivarProductoAdmin
    @productid INT,
    @estado VARCHAR(20) -- 'activo' o 'inactivo'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        UPDATE Product.Product
        SET estado = @estado
        WHERE productid = @productid;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4.3 Métodos de Pago: Crear
CREATE OR ALTER PROCEDURE dbo.CrearMetodoPagoAdmin
    @nombre VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        INSERT INTO Metodo_Pago (nombre, estado)
        VALUES (@nombre, 'activo');
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4.4 Métodos de Pago: Activar / Desactivar
CREATE OR ALTER PROCEDURE dbo.DesactivarMetodoPagoAdmin
    @id_metodo INT,
    @estado VARCHAR(20) -- 'activo' o 'inactivo'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        UPDATE Metodo_Pago
        SET estado = @estado
        WHERE id_metodo = @id_metodo;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4.5 Promociones: Crear
CREATE OR ALTER PROCEDURE dbo.CrearPromocionAdmin
    @nombre VARCHAR(50),
    @descuento DECIMAL(5,2),
    @fecha_inicio DATE,
    @fecha_fin DATE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        INSERT INTO Marketing.Promocion (nombre, descuento, fecha_inicio, fecha_fin, estado)
        VALUES (@nombre, @descuento, @fecha_inicio, @fecha_fin, 'activo');
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4.6 Promociones: Activar / Desactivar
CREATE OR ALTER PROCEDURE dbo.DesactivarPromocionAdmin
    @promocionid INT,
    @estado VARCHAR(20) -- 'activo' o 'inactivo'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        UPDATE Marketing.Promocion
        SET estado = @estado
        WHERE promocionid = @promocionid;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4.7 Ediciones: Crear
CREATE OR ALTER PROCEDURE dbo.CrearEdicionAdmin
    @name VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        INSERT INTO Product.Edicion (name, estado)
        VALUES (@name, 'activo');
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4.8 Ediciones: Activar / Desactivar
CREATE OR ALTER PROCEDURE dbo.DesactivarEdicionAdmin
    @edicionid INT,
    @estado VARCHAR(20) -- 'activo' o 'no activo'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        UPDATE Product.Edicion
        SET estado = @estado
        WHERE edicionid = @edicionid;
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 4.9 Unir Producto con Edición
CREATE OR ALTER PROCEDURE dbo.UnirProductoEdicion
    @productid INT,
    @edicionid INT,
    @precio DECIMAL(10,2),
    @fecha_lanzamiento DATE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        INSERT INTO Product.EdicionProduct (productid, edicionid, precio, fecha_lanzamiento)
        VALUES (@productid, @edicionid, @precio, @fecha_lanzamiento);
        
        DECLARE @new_edicionproductid INT = SCOPE_IDENTITY();
        
        -- Inicializar el inventario para esta unión a 0 si no existe
        IF NOT EXISTS (SELECT 1 FROM Product.Inventario WHERE edicionproductid = @new_edicionproductid)
        BEGIN
            INSERT INTO Product.Inventario (productid, edicionproductid, cantidad)
            VALUES (NULL, @new_edicionproductid, 0);
        END
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 5. CREACIÓN DE USUARIOS DE PRUEBA (ADMIN, VENDEDOR Y CONTRASEÑAS)
-- ============================================================

-- 5.1 Asegurar que admin tenga rol y contraseña en la base de datos
IF NOT EXISTS (SELECT 1 FROM Cliente.Cliente WHERE email = 'admin@gmail.com')
BEGIN
    INSERT INTO Cliente.Cliente (nombre, nmedio, apellido, email, estado, numero_contacto, paisid, rol, contrasena)
    VALUES ('Administrador', NULL, 'Sistema', 'admin@gmail.com', 'activo', '591-00000000', 1, 'admin', 'admin');
END
ELSE
BEGIN
    UPDATE Cliente.Cliente 
    SET rol = 'admin', contrasena = 'admin'
    WHERE email = 'admin@gmail.com';
END
GO

-- 5.2 Asegurar que vendedor tenga rol y contraseña en la base de datos
IF NOT EXISTS (SELECT 1 FROM Cliente.Cliente WHERE email = 'vendedor@gmail.com')
BEGIN
    INSERT INTO Cliente.Cliente (nombre, nmedio, apellido, email, estado, numero_contacto, paisid, rol, contrasena)
    VALUES ('Vendedor', NULL, 'Tienda', 'vendedor@gmail.com', 'activo', '591-11111111', 1, 'vendedor', 'vendedor');
END
ELSE
BEGIN
    UPDATE Cliente.Cliente 
    SET rol = 'vendedor', contrasena = 'vendedor'
    WHERE email = 'vendedor@gmail.com';
END
GO

PRINT 'Cambios y mejoras de base de datos creados correctamente.';
GO

-- ============================================================
-- 6. PROCEDIMIENTO PARA CONFIRMAR COMPRA Y ASIGNAR CÓDIGOS DE CANJE
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.ConfirmarCompra
    @carro_id INT,
    @metodo_pago_id INT,
    @pedido_id INT OUTPUT,
    @total DECIMAL(10,2) OUTPUT,
    @codigos_json NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Cambiar estado del carrito a 'en_proceso' (dispara trigger que crea pedido)
        UPDATE Venta.Carrito SET estado = 'en_proceso' WHERE carro_id = @carro_id;

        -- 2. Obtener el pedido recién creado por el trigger
        SELECT TOP 1 @pedido_id = pedido_id, @total = Total_pago
        FROM Venta.Pedido
        WHERE carro_id = @carro_id
        ORDER BY pedido_id DESC;

        IF @pedido_id IS NULL
            THROW 50000, 'El trigger no pudo crear el pedido.', 1;

        -- 3. Asignar método de pago al pedido
        EXEC SP_TRG_AsignarMetodoPagoAPedido @metodo_pago_id, @pedido_id;

        -- 4. Obtener los items del pedido (productoid, edicionproductid, cantidad_pedida)
        DECLARE @items TABLE (
            idx INT IDENTITY(1,1),
            productoid INT,
            cantidad_pedida INT,
            edicionproductid INT,
            nombre_producto VARCHAR(100),
            nombre_edicion VARCHAR(50)
        );

        INSERT INTO @items (productoid, cantidad_pedida, edicionproductid, nombre_producto, nombre_edicion)
        SELECT 
            pd.productoid,
            pd.cantidad_pedida,
            ep.edicionproductid,
            p.name,
            e.name
        FROM Venta.PedidoDetalles pd
        LEFT JOIN Product.EdicionProduct ep ON ep.productid = pd.productoid
        LEFT JOIN Product.Product p ON p.productid = pd.productoid
        LEFT JOIN Product.Edicion e ON e.edicionid = ep.edicionid
        WHERE pd.pedido_id = @pedido_id;

        -- 5. Tabla temporal para códigos asignados
        DECLARE @codigos TABLE (producto NVARCHAR(200), codigo VARCHAR(50));

        DECLARE @i INT = 1, @max INT;
        DECLARE @producto_actual NVARCHAR(200);
        DECLARE @cantidad_actual INT;
        DECLARE @edicion_actual INT;
        DECLARE @productoid_actual INT;
        DECLARE @ejemplares TABLE (id INT, codigo VARCHAR(50));

        SELECT @max = COUNT(*) FROM @items;

        WHILE @i <= @max
        BEGIN
            SELECT 
                @producto_actual = ISNULL(nombre_producto, '') + ISNULL(' (' + nombre_edicion + ')', ''),
                @cantidad_actual = cantidad_pedida,
                @edicion_actual = edicionproductid,
                @productoid_actual = productoid
            FROM @items WHERE idx = @i;

            IF @producto_actual IS NULL OR @producto_actual = '' 
                SET @producto_actual = 'Producto #' + CAST(@productoid_actual AS VARCHAR);

            DELETE FROM @ejemplares;

            IF @edicion_actual IS NOT NULL
            BEGIN
                INSERT INTO @ejemplares
                SELECT TOP (@cantidad_actual) id_ejemplar, canjear_codigo
                FROM Product.Ejemplar
                WHERE edicionproductid = @edicion_actual
                  AND estado = 'activo'
                  AND productid IS NULL
                ORDER BY id_ejemplar;
            END
            ELSE
            BEGIN
                INSERT INTO @ejemplares
                SELECT TOP (@cantidad_actual) id_ejemplar, canjear_codigo
                FROM Product.Ejemplar
                WHERE productid = @productoid_actual
                  AND estado = 'activo'
                  AND edicionproductid IS NULL
                ORDER BY id_ejemplar;
            END

            IF (SELECT COUNT(*) FROM @ejemplares) < @cantidad_actual
            BEGIN
                DECLARE @faltantes INT = @cantidad_actual - (SELECT COUNT(*) FROM @ejemplares);
                DECLARE @msg NVARCHAR(200) = 'No hay suficientes códigos disponibles para "' + @producto_actual + '". Faltan ' + CAST(@faltantes AS VARCHAR(10)) + ' unidades.';
                THROW 50000, @msg, 1;
            END

            -- Marcar ejemplares como 'comprado'
            UPDATE Product.Ejemplar
            SET estado = 'comprado'
            WHERE id_ejemplar IN (SELECT id FROM @ejemplares);

            -- Guardar códigos
            INSERT INTO @codigos (producto, codigo)
            SELECT @producto_actual, codigo FROM @ejemplares;

            SET @i = @i + 1;
        END

        -- 6. Marcar carrito como completado
        UPDATE Venta.Carrito
        SET estado = 'completado', fecha_cierre = CAST(GETDATE() AS DATE)
        WHERE carro_id = @carro_id;

        -- 7. Generar JSON manualmente
        SET @codigos_json = '[' +
            STUFF((SELECT ',' + '{"producto":"' + REPLACE(producto, '"', '\"') + '","codigo":"' + codigo + '"}'
                   FROM @codigos
                   FOR XML PATH('')), 1, 1, '') + ']';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @err_msg NVARCHAR(MAX) = ERROR_MESSAGE();
        THROW 50000, @err_msg, 1;
    END CATCH
END;
GO

-- ============================================================
-- 7. TRIGGER PARA DISMINUIR INVENTARIO AL ENTREGAR EL PEDIDO
-- ============================================================
IF OBJECT_ID('Venta.trg_Pedido_entregado', 'TR') IS NOT NULL
    DROP TRIGGER Venta.trg_Pedido_entregado;
GO

CREATE TRIGGER trg_Pedido_entregado
on Venta.Pedido 
AFTER UPDATE 
as 
begin
    SET NOCOUNT ON;
    IF EXISTS( 
        select 1 from inserted i  
        join deleted d on d.pedido_id = i.pedido_id
        where i.estado = 'entregado' and d.estado <> 'entregado'
    )
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
                -- verificar si tiene promo y si tiene verificar si esta dentro de la fecha de la promo
                IF EXISTS (
                    SELECT 1 
                    FROM inserted i
                    INNER JOIN Marketing.Promocion mp ON i.promocionid = mp.promocionid
                    WHERE i.fecha_de_entrega > mp.fecha_fin
                )
                BEGIN
                    RAISERROR('se intento agregar una promo que ya expiro para la fecha de entrega', 16, 1);
                END

                INSERT INTO Product.MovimientoInventario (productid, edicionproductid, cantidad, fecha, provedorid)
                SELECT 
                    det.productoid,
                    COALESCE(det.edicionproductid, ep.edicionproductid),
                    det.cantidad_pedida,
                    CAST(GETDATE() AS DATE),
                    NULL
                FROM Venta.PedidoDetalles det  
                LEFT JOIN Product.EdicionProduct ep ON ep.productid = det.productoid
                JOIN inserted i ON i.pedido_id = det.pedido_id
                JOIN deleted d ON d.pedido_id = i.pedido_id
                WHERE i.estado = 'entregado' AND d.estado <> 'entregado';

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            DECLARE @err NVARCHAR(MAX) = ERROR_MESSAGE();
            RAISERROR(@err, 16, 1);
        END CATCH
    END
end;
GO
