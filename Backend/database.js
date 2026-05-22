const sql = require('mssql');

const dbConfig = {
    user: 'Admin', 
    password: 'admin',
    server: 'LAPTOP-GGCKNFU6', 
    database: 'BD2_tienda',
    options: { encrypt: false, trustServerCertificate: true }
};

const poolPromise = new sql.ConnectionPool(dbConfig)
    .connect()
    .then(pool => {
        console.log('✅ Conectado a SQL Server');
        return pool;
    })
    .catch(err => console.log('❌ Error en la conexión: ', err));

module.exports = { sql, poolPromise };