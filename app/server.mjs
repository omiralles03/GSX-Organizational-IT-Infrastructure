import http from 'node:http';
import 'dotenv/config';

const PORT = process.env.PORT || 3000;
let requestCount = 0;

const server = http.createServer((req, res) => {
    if (req.url === '/metrics') {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end(`# HELP http_requests_total Total de peticiones HTTP\n# TYPE http_requests_total counter\nhttp_requests_total ${requestCount}\n`);
        return;
    }

    requestCount++;
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('Hello from container\n');
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT}`);
});