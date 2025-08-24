const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

// Import configuration
const { config, validateConfig, getProviderConfig, isProviderAvailable, getAvailableProviders } = require('./config');

// Rate limiting storage
const requestCounts = new Map();

// Validate configuration on startup
try {
    validateConfig();
    console.log('✓ Configuration validated successfully');
} catch (error) {
    console.error('✗ Configuration validation failed:', error.message);
    process.exit(1);
}

// Log available providers
const availableProviders = getAvailableProviders();
console.log(`✓ Available AI providers: ${availableProviders.join(', ')}`);

// Rate limiting middleware
function checkRateLimit(clientIP) {
    const now = Date.now();
    const windowStart = now - config.rateLimit.windowMs;
    
    if (!requestCounts.has(clientIP)) {
        requestCounts.set(clientIP, []);
    }
    
    const clientRequests = requestCounts.get(clientIP);
    
    // Remove old requests outside the window
    const validRequests = clientRequests.filter(timestamp => timestamp > windowStart);
    requestCounts.set(clientIP, validRequests);
    
    if (validRequests.length >= config.rateLimit.maxRequests) {
        return false; // Rate limit exceeded
    }
    
    // Add current request
    validRequests.push(now);
    return true; // Request allowed
}

// Get client IP from request
function getClientIP(req) {
    return req.headers['x-forwarded-for'] || 
           req.connection.remoteAddress || 
           req.socket.remoteAddress || 
           'unknown';
}

// Logging function
function log(level, message, data = null) {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] [${level.toUpperCase()}] ${message}`;
    
    if (data && config.logging.enableDebug) {
        console.log(logMessage, data);
    } else {
        console.log(logMessage);
    }
}

// Create HTTP server
const server = http.createServer((req, res) => {
    const clientIP = getClientIP(req);
    
    // Add CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    
    // Handle preflight requests
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }
    
    // Check rate limit
    if (!checkRateLimit(clientIP)) {
        log('warn', `Rate limit exceeded for IP: ${clientIP}`);
        res.writeHead(429, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
            error: 'Rate limit exceeded', 
            message: 'Too many requests, please try again later' 
        }));
        return;
    }
    
    // Handle proxy requests
    if (req.method === 'POST' && req.url === '/proxy') {
        let body = '';
        req.on('data', chunk => {
            body += chunk.toString();
        });

        req.on('end', async () => {
            try {
                const requestData = JSON.parse(body);
                const provider = requestData.provider;
                
                // Validate provider
                if (!provider || !isProviderAvailable(provider)) {
                    const available = getAvailableProviders();
                    log('error', `Invalid or unavailable provider: ${provider}`, { available });
                    res.writeHead(400, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ 
                        error: 'Invalid provider', 
                        message: `Provider '${provider}' is not available. Available providers: ${available.join(', ')}` 
                    }));
                    return;
                }
                
                const providerConfig = getProviderConfig(provider);
                log('info', `Processing request for provider: ${provider}`, { clientIP });
                
                // Remove provider from payload before sending to AI API
                delete requestData.provider;
                const aiApiPayload = JSON.stringify(requestData);

                const options = {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': `Bearer ${providerConfig.apiKey}`,
                        'Content-Length': Buffer.byteLength(aiApiPayload)
                    },
                    timeout: config.requestTimeout
                };

                const proxyReq = https.request(providerConfig.apiUrl, options, (aiRes) => {
                    let aiResponseBody = '';
                    aiRes.on('data', chunk => {
                        aiResponseBody += chunk.toString();
                    });
                    
                    aiRes.on('end', () => {
                        log('info', `AI API response received`, { 
                            provider, 
                            statusCode: aiRes.statusCode,
                            contentLength: aiResponseBody.length 
                        });
                        
                        res.writeHead(aiRes.statusCode, { 'Content-Type': 'application/json' });
                        res.end(aiResponseBody);
                    });
                });

                proxyReq.on('error', (e) => {
                    log('error', `Error calling AI API`, { provider, error: e.message });
                    res.writeHead(500, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ 
                        error: 'AI API request failed', 
                        details: e.message,
                        provider 
                    }));
                });

                proxyReq.on('timeout', () => {
                    log('error', `AI API request timeout`, { provider });
                    proxyReq.destroy();
                    res.writeHead(408, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ 
                        error: 'Request timeout', 
                        message: 'AI API request timed out',
                        provider 
                    }));
                });

                proxyReq.write(aiApiPayload);
                proxyReq.end();

            } catch (e) {
                log('error', `Error parsing request`, { error: e.message, body });
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ 
                    error: 'Invalid request', 
                    message: 'Failed to parse request body',
                    details: e.message 
                }));
            }
        });
    } else if (req.method === 'GET' && req.url === '/status') {
        // Status endpoint
        const status = {
            status: 'running',
            timestamp: new Date().toISOString(),
            uptime: process.uptime(),
            availableProviders: getAvailableProviders(),
            config: {
                port: config.port,
                host: config.host,
                rateLimit: config.rateLimit,
                requestTimeout: config.requestTimeout
            }
        };
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(status, null, 2));
    } else {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
            error: 'Not Found', 
            message: 'Endpoint not found. Available endpoints: /proxy (POST), /status (GET)' 
        }));
    }
});

// Start server
server.listen(config.port, config.host, () => {
    const pid = process.pid;
    
    // Save PID to file
    fs.writeFile(config.pidFile, pid.toString(), (err) => {
        if (err) {
            log('error', `Failed to write PID file: ${err.message}`);
        } else {
            log('info', `PID ${pid} saved to ${config.pidFile}`);
        }
    });
    
    log('info', `AI Chat Proxy started on ${config.host}:${config.port} with PID ${pid}`);
    log('info', `Available providers: ${availableProviders.join(', ')}`);
    log('info', 'Waiting for OpenKore requests...');
});

// Graceful shutdown handling
function gracefulShutdown(signal) {
    log('info', `Received ${signal}, shutting down gracefully...`);
    
    server.close(() => {
        log('info', 'HTTP server closed');
        
        // Remove PID file
        if (fs.existsSync(config.pidFile)) {
            fs.unlinkSync(config.pidFile);
            log('info', `PID file ${config.pidFile} removed`);
        }
        
        log('info', 'Graceful shutdown completed');
        process.exit(0);
    });
    
    // Force exit after timeout
    setTimeout(() => {
        log('error', 'Forced shutdown after timeout');
        process.exit(1);
    }, 10000);
}

// Handle shutdown signals
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('exit', (code) => {
    log('info', `Process exiting with code ${code}`);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
    log('error', `Uncaught exception: ${error.message}`, error.stack);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    log('error', `Unhandled rejection at ${promise}: ${reason}`);
    process.exit(1);
}); 