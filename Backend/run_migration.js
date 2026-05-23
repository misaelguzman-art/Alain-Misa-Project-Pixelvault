const { poolBolivia, poolPeru, sql } = require('./database');

// Obtener el tipo de nodo desde la consola (ej: 'node run_migration.js bolivia' o 'node run_migration.js peru')
const targetNode = process.argv[2] ? process.argv[2].toLowerCase() : null;

if (!targetNode || (targetNode !== 'bolivia' && targetNode !== 'peru')) {
    console.error('❌ Debes especificar el nodo objetivo: "node run_migration.js bolivia" o "node run_migration.js peru"');
    process.exit(1);
}

const pool = targetNode === 'peru' ? poolPeru : poolBolivia;
const paisLocalID = targetNode === 'peru' ? 4 : 1; // 1 = Bolivia, 4 = Perú

async function run() {
    console.log(`🚀 Iniciando migración automatizada para el nodo: ${targetNode.toUpperCase()}`);
    
    try {
        // Asegurar que el pool esté conectado
        if (!pool.connected) {
            await pool.connect();
        }

        const transaction = new sql.Transaction(pool);
        await transaction.begin();

        try {
            const request = new sql.Request(transaction);

            // ============================================================
            // 1. DESACTIVAR LLAVES FORÁNEAS Y TRIGGERS TEMPORALMENTE
            // ============================================================
            console.log('⏳ Desactivando triggers y restricciones...');
            await request.query(`
                DISABLE TRIGGER ALL ON DATABASE;
                DECLARE @sql NVARCHAR(MAX) = '';
                SELECT @sql += 'ALTER TABLE [' + s.name + '].[' + t.name + '] NOCHECK CONSTRAINT ALL; '
                FROM sys.tables t
                JOIN sys.schemas s ON t.schema_id = s.schema_id;
                EXEC sp_executesql @sql;
            `);

            // ============================================================
            // 2. ELIMINAR CLIENTES QUE NO SEAN DE BOLIVIA (1) NI DE PERÚ (4)
            // ============================================================
            console.log('🧹 Eliminando clientes de otros países ajenos en cascada segura...');
            await request.query(`
                -- 2.1 Borrar detalles de pedidos asociados a clientes ajenos
                DELETE pd FROM Venta.PedidoDetalles pd
                JOIN Venta.Pedido p ON pd.pedido_id = p.pedido_id
                JOIN Cliente.Cliente c ON p.Id_cliente = c.Id_cliente
                WHERE c.paisid NOT IN (1, 4) OR c.paisid IS NULL;

                -- 2.2 Borrar pedidos
                DELETE p FROM Venta.Pedido p
                JOIN Cliente.Cliente c ON p.Id_cliente = c.Id_cliente
                WHERE c.paisid NOT IN (1, 4) OR c.paisid IS NULL;

                -- 2.3 Borrar detalles de carritos
                DELETE cd FROM Venta.CarroDetalles cd
                JOIN Venta.Carrito ca ON cd.carro_id = ca.carro_id
                JOIN Cliente.Cliente c ON ca.Id_cliente = c.Id_cliente
                WHERE c.paisid NOT IN (1, 4) OR c.paisid IS NULL;

                -- 2.4 Borrar carritos
                DELETE ca FROM Venta.Carrito ca
                JOIN Cliente.Cliente c ON ca.Id_cliente = c.Id_cliente
                WHERE c.paisid NOT IN (1, 4) OR c.paisid IS NULL;

                -- 2.5 Borrar métodos de pago de clientes ajenos
                DELETE cmp FROM Cliente.Cliente_Metodo_Pago cmp
                JOIN Cliente.Cliente c ON cmp.Id_cliente = c.Id_cliente
                WHERE c.paisid NOT IN (1, 4) OR c.paisid IS NULL;

                -- 2.6 Borrar los clientes ajenos
                DELETE FROM Cliente.Cliente
                WHERE (paisid NOT IN (1, 4) OR paisid IS NULL)
                  AND email NOT IN ('admin@gmail.com', 'vendedor@gmail.com');
            `);

            // ============================================================
            // 3. LIMPIAR TODOS LOS JUEGOS Y TRANSACCIONES ANTERIORES (COMO SE SOLICITÓ)
            // ============================================================
            console.log('🧹 Limpiando todo el catálogo de juegos anterior y datos dinámicos...');
            await request.query(`
                -- 3.1 Limpiar transacciones para evitar conflictos de llave foránea
                DELETE FROM Venta.PedidoDetalles;
                DELETE FROM Venta.Pedido;
                DELETE FROM Venta.CarroDetalles;
                DELETE FROM Venta.Carrito;

                -- 3.2 Limpiar catálogo de productos
                DELETE FROM Product.MovimientoInventario;
                DELETE FROM Product.Inventario;
                DELETE FROM Product.Ejemplar;
                DELETE FROM Product.CategoriaProduct;
                DELETE FROM Product.ProductPlataforma;
                DELETE FROM Product.EdicionProduct;
                DELETE FROM Product.Product;
                
                -- Reiniciar autoincrementables
                DBCC CHECKIDENT ('Product.Product', RESEED, 0);
                DBCC CHECKIDENT ('Product.EdicionProduct', RESEED, 0);
                DBCC CHECKIDENT ('Product.Ejemplar', RESEED, 0);
                DBCC CHECKIDENT ('Product.Inventario', RESEED, 0);
                
                IF OBJECT_ID('dbo.Auditoria', 'U') IS NOT NULL
                BEGIN
                    DELETE FROM dbo.Auditoria;
                    DBCC CHECKIDENT ('dbo.Auditoria', RESEED, 0);
                END
            `);

            // ============================================================
            // 4. CONFIGURAR TABLA LOCAL Y AGREGAR COLUMNA PAISID
            // ============================================================
            console.log('⚙️ Configurando estructura geográfica local...');
            await request.query(`
                -- Crear tabla de configuración local
                IF OBJECT_ID('dbo.ConfiguracionLocal', 'U') IS NULL
                BEGIN
                    CREATE TABLE dbo.ConfiguracionLocal (
                        pais_local_id INT NOT NULL FOREIGN KEY REFERENCES Paises(paisid)
                    );
                END

                -- Insertar/actualizar configuración de país local
                TRUNCATE TABLE dbo.ConfiguracionLocal;
                INSERT INTO dbo.ConfiguracionLocal (pais_local_id) VALUES (${paisLocalID});

                -- Crear columna de país en productos
                IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Product.Product') AND name = 'paisid')
                BEGIN
                    ALTER TABLE Product.Product ADD paisid INT NULL FOREIGN KEY REFERENCES Paises(paisid);
                END
            `);

            // ============================================================
            // 5. ACTUALIZAR O CREAR VISTAS FILTRADAS POR PAÍS
            // ============================================================
            console.log('👁️ Creando Vistas Distribuidas y de Privacidad...');
            
            // 5.1 Vista de Productos para Clientes
            if (targetNode === 'peru') {
                // En Perú, unimos juegos locales con globales usando Linked Server NODO_CENTRAL
                await request.query(`
                    CREATE OR ALTER VIEW Product.v_ProductCliente AS
                    SELECT productid, name, developerid, estado, tipo_juego, juego_base, precio_base, fecha_de_lanzamiento, paisid
                    FROM Product.Product
                    WHERE paisid = 4
                    UNION ALL
                    SELECT productid, name, developerid, estado, tipo_juego, juego_base, precio_base, fecha_de_lanzamiento, paisid
                    FROM [NODO_CENTRAL].[BD2_tienda].[Product].[Product]
                    WHERE paisid IS NULL;
                `);
            } else {
                // En Bolivia, mostramos juegos locales y globales propios
                await request.query(`
                    CREATE OR ALTER VIEW Product.v_ProductCliente AS
                    SELECT productid, name, developerid, estado, tipo_juego, juego_base, precio_base, fecha_de_lanzamiento, paisid
                    FROM Product.Product
                    WHERE paisid = 1 OR paisid IS NULL;
                `);
            }

            // 5.2 Vista de Clientes (Restringida en Perú, abierta en Bolivia)
            if (targetNode === 'peru') {
                await request.query(`
                    CREATE OR ALTER VIEW VW_Directorio_clientes AS
                    SELECT 
                        C.Id_cliente,
                        c.nombre primer_nombre,
                        c.apellido apellido,
                        c.email as correo,
                        c.numero_contacto as telefono,
                        p.nombre as pais,
                        c.estado as estado_usuario
                    FROM Cliente.Cliente C  
                    LEFT JOIN Paises P ON C.paisid = p.paisid
                    WHERE C.paisid = 4; -- STRICT LIMIT: Solo clientes de Perú
                `);
            } else {
                await request.query(`
                    CREATE OR ALTER VIEW VW_Directorio_clientes AS
                    SELECT 
                        C.Id_cliente,
                        c.nombre primer_nombre,
                        c.apellido apellido,
                        c.email as correo,
                        c.numero_contacto as telefono,
                        p.nombre as pais,
                        c.estado as estado_usuario
                    FROM Cliente.Cliente C  
                    LEFT JOIN Paises P ON C.paisid = p.paisid; -- Todos los clientes
                `);
            }

            // 5.3 Vista Jerárquica de Catálogo con Columna de Ámbito de País
            await request.query(`
                CREATE OR ALTER VIEW VW_TODAS_Juegos_ED_DLC AS
                WITH catalago_juegos AS (
                    SELECT pp.name AS nombre_juego,
                           CASE 
                               WHEN ep.edicionproductid IS NULL THEN ed.name
                               ELSE pp.tipo_juego
                           END tipo_dejuego,
                           padre.name AS Cabeza,
                           pp.paisid
                    FROM Product.Product pp
                    LEFT JOIN Product.Product padre ON padre.productid = pp.juego_base
                    LEFT JOIN Product.EdicionProduct ep ON ep.edicionproductid = pp.productid
                    LEFT JOIN Product.Edicion ed ON ep.edicionid = ed.edicionid
                )
                SELECT nombre_juego, tipo_dejuego, Cabeza,
                       COALESCE(Cabeza, nombre_juego) AS GrupoOrden,
                       CASE WHEN Cabeza IS NULL THEN 0 ELSE 1 END AS EsDLC,
                       ISNULL(p.nombre, 'Global') AS pais_ambito
                FROM catalago_juegos cj
                LEFT JOIN Paises p ON cj.paisid = p.paisid;
            `);

            // ============================================================
            // 6. CREACIÓN DE STORED PROCEDURES DE CONTROL GEOGRÁFICO
            // ============================================================
            console.log('💾 Creando procedimientos almacenados y triggers...');
            await request.query(`
                -- SP AgregarCliente con validación geográfica
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
                    SELECT TOP 1 @PaisLocalID = pais_local_id FROM dbo.ConfiguracionLocal;

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
                        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                        THROW; 
                    END CATCH
                END;
            `);

            await request.query(`
                -- SP CrearProductoAdmin con validación de ámbito geográfico
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
                        COMMIT TRANSACTION;
                    END TRY
                    BEGIN CATCH
                        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                        THROW;
                    END CATCH
                END;
            `);

            // Si es el nodo de Perú, habilitar el Trigger de protección absoluta
            if (targetNode === 'peru') {
                await request.query(`
                    CREATE OR ALTER TRIGGER Product.trg_Protect_Product_Distribuidor
                    ON Product.Product
                    INSTEAD OF UPDATE, DELETE
                    AS
                    BEGIN
                        SET NOCOUNT ON;
                        DECLARE @PaisLocalID INT = NULL;
                        SELECT TOP 1 @PaisLocalID = pais_local_id FROM dbo.ConfiguracionLocal;

                        IF @PaisLocalID = 4
                        BEGIN
                            IF EXISTS (SELECT 1 FROM deleted WHERE paisid IS NULL OR paisid <> 4)
                               OR EXISTS (SELECT 1 FROM inserted WHERE paisid IS NULL OR paisid <> 4)
                            BEGIN
                                THROW 53000, 'La sucursal de Perú no tiene permisos para modificar o eliminar productos globales o de otros países.', 1;
                                RETURN;
                            END
                        END

                        IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
                        BEGIN
                            UPDATE p
                            SET p.name = i.name, p.developerid = i.developerid, p.estado = i.estado,
                                p.tipo_juego = i.tipo_juego, p.juego_base = i.juego_base, p.precio_base = i.precio_base,
                                p.fecha_de_lanzamiento = i.fecha_de_lanzamiento, p.paisid = i.paisid
                            FROM Product.Product p JOIN inserted i ON p.productid = i.productid;
                        END
                        ELSE IF EXISTS (SELECT 1 FROM deleted)
                        BEGIN
                            DELETE p FROM Product.Product p JOIN deleted d ON p.productid = d.productid;
                        END
                    END;
                `);
            }

            // ============================================================
            // 7. INSERTAR JUEGOS DE PRUEBA NUEVOS (CENTRAL O LOCAL SEGÚN EL CASO)
            // ============================================================
            console.log('🆕 Insertando juegos de prueba nuevos con sus ámbitos de país...');
            
            if (targetNode === 'bolivia') {
                // La central inserta juegos Globales y juegos específicos de Bolivia
                await request.query(`
                    -- Asegurar que existan desarrolladores para evitar conflictos de FK
                    DECLARE @devid INT;
                    IF NOT EXISTS (SELECT 1 FROM Product.Developer)
                    BEGIN
                        INSERT INTO Product.Developer (name) VALUES ('FromSoftware'), ('Nintendo');
                    END
                    SELECT TOP 1 @devid = developerid FROM Product.Developer;

                    -- 1. Juego Global
                    INSERT INTO Product.Product (name, developerid, estado, tipo_juego, juego_base, precio_base, fecha_de_lanzamiento, paisid)
                    VALUES ('Elden Ring (Global)', @devid, 'activo', 'juego', NULL, 59.99, '2022-02-25', NULL);

                    -- 2. Juego exclusivo de Bolivia
                    INSERT INTO Product.Product (name, developerid, estado, tipo_juego, juego_base, precio_base, fecha_de_lanzamiento, paisid)
                    VALUES ('Zelda Tears of the Kingdom (Bolivia)', @devid, 'activo', 'juego', NULL, 69.99, '2023-05-12', 1);
                `);
            } else if (targetNode === 'peru') {
                // La sucursal de Perú inserta únicamente juegos de Perú
                await request.query(`
                    -- Asegurar que existan desarrolladores para evitar conflictos de FK
                    DECLARE @devid INT;
                    IF NOT EXISTS (SELECT 1 FROM Product.Developer)
                    BEGIN
                        INSERT INTO Product.Developer (name) VALUES ('Codemasters');
                    END
                    SELECT TOP 1 @devid = developerid FROM Product.Developer;

                    -- 3. Juego exclusivo de Perú
                    INSERT INTO Product.Product (name, developerid, estado, tipo_juego, juego_base, precio_base, fecha_de_lanzamiento, paisid)
                    VALUES ('F1 2024 (Peru Edition)', @devid, 'activo', 'juego', NULL, 49.99, '2024-05-31', 4);
                `);
            }

            // ============================================================
            // 8. RE-HABILITAR LLAVES FORÁNEAS Y TRIGGERS
            // ============================================================
            console.log('⏳ Habilitando triggers y restricciones...');
            await request.query(`
                DECLARE @sql NVARCHAR(MAX) = '';
                SELECT @sql += 'ALTER TABLE [' + s.name + '].[' + t.name + '] WITH CHECK CHECK CONSTRAINT ALL; '
                FROM sys.tables t
                JOIN sys.schemas s ON t.schema_id = s.schema_id;
                EXEC sp_executesql @sql;
                ENABLE TRIGGER ALL ON DATABASE;
            `);

            await transaction.commit();
            console.log(`\n========================================================`);
            console.log(`✅ ¡MIGRACIÓN COMPLETADA CON ÉXITO PARA: ${targetNode.toUpperCase()}!`);
            console.log(`========================================================\n`);
            process.exit(0);

        } catch (innerErr) {
            console.error('❌ Error interno detectado en la base de datos:', innerErr);
            try {
                await transaction.rollback();
            } catch (rollbackErr) {
                // Silenciar error de rollback si la transacción ya fue abortada por SQL Server
            }
            throw innerErr;
        }

    } catch (err) {
        console.error('❌ Error fatal durante la migración:', err);
        process.exit(1);
    }
}

run();
