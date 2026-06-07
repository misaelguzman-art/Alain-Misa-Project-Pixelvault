const mongoose = require('mongoose');

// URI de conexión a la base de datos local de MongoDB (por defecto en el puerto 27017)
const MONGO_URI = 'mongodb://localhost:27017/BD2_tienda_mongo'; 

const connectMongoDB = async () => {
    try {
        await mongoose.connect(MONGO_URI);
        console.log('✅ Conectado a la Base de Datos MongoDB (Comentarios y Playlists)');
    } catch (err) {
        console.error('❌ Error conectando a MongoDB: ', err);
        // Opcional: process.exit(1) si quieres que el server falle sin MongoDB, 
        // pero lo dejamos sin exit para que SQL Server pueda seguir funcionando.
    }
};

module.exports = connectMongoDB;
