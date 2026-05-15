import http from 'node:http';
import 'dotenv/config';

const PORT = process.env.PORT || 3000;

// Variables para las métricas
let requestCount = 0;
let errorCount = 0;
let totalDurationSeconds = 0;
const startTime = Date.now();

const server = http.createServer((req, res) => {
    // Iniciar cronómetro para medir la latencia
    const start = process.hrtime();

    // Endpoint exclusivo para Prometheus
    if (req.url === '/metrics') {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        
        let metrics = `# HELP http_requests_total Total de peticiones\n`;
        metrics += `# TYPE http_requests_total counter\n`;
        metrics += `http_requests_total ${requestCount}\n\n`;

        metrics += `# HELP http_errors_total Total de errores 5xx\n`;
        metrics += `# TYPE http_errors_total counter\n`;
        metrics += `http_errors_total ${errorCount}\n\n`;

        metrics += `# HELP http_request_duration_seconds_total Duracion total de todas las peticiones\n`;
        metrics += `# TYPE http_request_duration_seconds_total counter\n`;
        metrics += `http_request_duration_seconds_total ${totalDurationSeconds}\n\n`;

        metrics += `# HELP app_uptime_seconds Tiempo desde que arranco el contenedor\n`;
        metrics += `# TYPE app_uptime_seconds gauge\n`;
        metrics += `app_uptime_seconds ${Math.floor((Date.now() - startTime) / 1000)}\n`;

        res.end(metrics);
        return;
    }

    // Lógica de la aplicación: Simulamos un 1% de errores para el "Error Rate"
    if (Math.random() < 0.01) {
        errorCount++;
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('Internal Server Error\n');
    } else {
        requestCount++;
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('Hello from GreenDevCorp\n');
    }

    // Parar cronómetro y sumar la latencia
    const diff = process.hrtime(start);
    const duration = diff[0] + diff[1] / 1e9;
    totalDurationSeconds += duration;
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT}`);
});