const { poolBolivia, poolPeru } = require('./database');

module.exports = (req, res, next) => {
    // Leer el país del header 'x-pais' o del query parameter 'pais'
    const pais = req.headers['x-pais'] || req.query.pais || 'bolivia';

    if (pais.toLowerCase() === 'peru') {
        req.dbPool = poolPeru;
    } else {
        req.dbPool = poolBolivia; // Por defecto la Central (Bolivia)
    }
    
    next();
};
