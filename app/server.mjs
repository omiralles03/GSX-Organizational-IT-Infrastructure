import http from 'node:http';
import 'dotenv/config';

const PORT = process.env.PORT || 3000;

const server = http.createServer((_, res) => {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end('Hello from container\n');
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on port ${PORT}`);
});
