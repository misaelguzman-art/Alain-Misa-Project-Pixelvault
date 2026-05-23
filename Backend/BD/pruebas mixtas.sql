-- ============================================
-- LINKED SERVER HACIA EQUIPO 19caa25d4d
-- ============================================

IF EXISTS (
    SELECT *
    FROM sys.servers
    WHERE
        name = 'ZT_SERVER_BOLIVIA'
) EXEC sp_dropserver 'ZT_SERVER_BOLIVIA',
'droplogins'

EXEC sp_addlinkedserver @server = 'ZT_SERVER_BOLIVIA',
@srvproduct = '',
@provider = 'SQLNCLI',
@datasrc = '10.132.203.185' -- IP ZeroTier del equipo destino

EXEC sp_addlinkedsrvlogin @rmtsrvname = 'ZT_SERVER_BOLIVIA',
@useself = 'FALSE',
@locallogin = NULL,
@rmtuser = 'Admin_Central',
@rmtpassword = 'admin'

EXEC sp_serveroption 'ZT_SERVER_BOLIVIA',
'rpc',
'true' EXEC sp_serveroption 'ZT_SERVER_BOLIVIA',
'rpc out',
'true' EXEC sp_serveroption 'ZT_SERVER_BOLIVIA',
'data access',
'true'

PRINT 'Linked Server ZT_SERVER_BOLIVIA creado exitosamente'

-- Prueba de conexión
PRINT 'Probando conexión...'
SELECT
    TOP 1 'Conexión exitosa' AS Estado,
    @@SERVERNAME AS ServidorRemoto
FROM OPENQUERY (
        ZT_SERVER_BOLIVIA, 'SELECT @@SERVERNAME'
    )