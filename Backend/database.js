const sql = require('mssql');

// Configuración para el Nodo Central (Bolivia)
const configBolivia = {
    user: 'Admin', 
    password: 'admin',
    server: 'LAPTOP-GGCKNFU6', 
    database: 'BD2_tienda',
    options: { encrypt: false, trustServerCertificate: true }
};

// Configuración para el Nodo Sucursal (Perú - Colega)
const configPeru = {
    user: 'Usuario_admin', 
    password: '123456',
    server: 'DESKTOP-GKFCRF1', 
    database: 'BD2_Peru',
    options: { encrypt: false, trustServerCertificate: true }
};

// Crear Connection Pools
const poolBolivia = new sql.ConnectionPool(configBolivia);
const poolPeru = new sql.ConnectionPool(configPeru);

// Promesas de conexión
const poolBoliviaPromise = poolBolivia.connect()
    .then(pool => {
        console.log('✅ Conectado a la Base de Datos Central (Bolivia)');
        return pool;
    })
    .catch(err => console.log('❌ Error conectando a Central (Bolivia): ', err));

const poolPeruPromise = poolPeru.connect()
    .then(pool => {
        console.log('✅ Conectado a la Base de Datos Sucursal (Perú)');
        return pool;
    })
    .catch(err => console.log('❌ Error conectando a Sucursal (Perú): ', err));

// Mantener compatibilidad exportando poolPromise apuntando a la Central (Bolivia) por defecto
module.exports = { 
    sql, 
    poolPromise: poolBoliviaPromise,
    poolBoliviaPromise,
    poolPeruPromise,
    poolBolivia,
    poolPeru
};