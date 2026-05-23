const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
 
app.use(express.json());
app.use(cors());

app.use(express.static(path.join(__dirname, 'public')));

// Importar las rutas modulares y el middleware de enrutamiento dinámico
const routingMiddleware = require('./middleware');
const spRoutes = require('./stored_procedures');
const vistasRoutes = require('./vistas');

// Usar las rutas con el middleware aplicado
app.use('/api', routingMiddleware);
app.use('/api', spRoutes);
app.use('/api', vistasRoutes);

const PORT = 3000;
app.listen(PORT, () => console.log(`🚀 Servidor modular corriendo en puerto ${PORT}`));