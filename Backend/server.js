const express = require('express');
const cors = require('cors');
const path = require('path');
const connectMongoDB = require('./mongo_database');

const app = express();
 
app.use(express.json());
app.use(cors());

app.use(express.static(path.join(__dirname, 'public')));

// Importar las rutas modulares y el middleware de enrutamiento dinámico
const routingMiddleware = require('./middleware');
const spRoutes = require('./stored_procedures');
const vistasRoutes = require('./vistas');
const mongoRoutes = require('./mongo_routes');

// Iniciar conexión a MongoDB
connectMongoDB();

// Usar las rutas con el middleware aplicado
app.use('/api', routingMiddleware);
app.use('/api', spRoutes);
app.use('/api', vistasRoutes);
app.use('/api', mongoRoutes);

const http = require('http');
const { Server } = require('socket.io');

const server = http.createServer(app);
const io = new Server(server, {
    cors: { origin: "*" }
});

// Guardar io en app para poder usarlo en las rutas
app.set('io', io);

io.on('connection', (socket) => {
    console.log('🔌 Nuevo usuario conectado via WebSocket');
    socket.on('disconnect', () => {
        console.log('🔌 Usuario desconectado');
    });
});

const PORT = 3000;
server.listen(PORT, () => console.log(`🚀 Servidor modular corriendo en puerto ${PORT}`));