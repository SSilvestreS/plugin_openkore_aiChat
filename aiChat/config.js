const fs = require('fs');
const path = require('path');

// Load environment variables from .env file if it exists
try {
    if (fs.existsSync(path.join(__dirname, '.env'))) {
        require('dotenv').config();
    }
} catch (error) {
    console.warn('Warning: Could not load .env file:', error.message);
}

// Configuration object with defaults and environment overrides
const config = {
    // Server settings
    port: process.env.PORT || 3000,
    host: process.env.HOST || 'localhost',
    
    // API Keys
    deepseek: {
        apiKey: process.env.DEEPSEEK_API_KEY || '',
        apiUrl: 'https://api.deepseek.com/chat/completions',
        defaultModel: 'deepseek-chat'
    },
    
    openai: {
        apiKey: process.env.OPENAI_API_KEY || '',
        apiUrl: 'https://api.openai.com/v1/chat/completions',
        defaultModel: 'gpt-3.5-turbo'
    },
    
    // Logging
    logging: {
        level: process.env.LOG_LEVEL || 'info',
        enableDebug: process.env.ENABLE_DEBUG === 'true' || false
    },
    
    // Rate limiting
    rateLimit: {
        windowMs: parseInt(process.env.RATE_LIMIT_WINDOW) || 60000, // 1 minute
        maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100
    },
    
    // Request timeout
    requestTimeout: parseInt(process.env.REQUEST_TIMEOUT) || 30000, // 30 seconds
    
    // File paths
    pidFile: 'proxy_pid.txt'
};

// Validation function
function validateConfig() {
    const errors = [];
    
    // Check if at least one API key is provided
    if (!config.deepseek.apiKey && !config.openai.apiKey) {
        errors.push('At least one API key must be provided (DEEPSEEK_API_KEY or OPENAI_API_KEY)');
    }
    
    // Validate port
    if (config.port < 1 || config.port > 65535) {
        errors.push('Port must be between 1 and 65535');
    }
    
    // Validate rate limit settings
    if (config.rateLimit.windowMs < 1000) {
        errors.push('Rate limit window must be at least 1000ms');
    }
    
    if (config.rateLimit.maxRequests < 1) {
        errors.push('Rate limit max requests must be at least 1');
    }
    
    if (errors.length > 0) {
        throw new Error('Configuration validation failed:\n' + errors.join('\n'));
    }
    
    return true;
}

// Get provider configuration
function getProviderConfig(provider) {
    if (provider === 'deepseek') {
        return config.deepseek;
    } else if (provider === 'openai') {
        return config.openai;
    }
    throw new Error(`Unsupported provider: ${provider}`);
}

// Check if provider is available
function isProviderAvailable(provider) {
    try {
        const providerConfig = getProviderConfig(provider);
        return !!providerConfig.apiKey;
    } catch (error) {
        return false;
    }
}

// Get available providers
function getAvailableProviders() {
    const providers = [];
    if (config.deepseek.apiKey) providers.push('deepseek');
    if (config.openai.apiKey) providers.push('openai');
    return providers;
}

module.exports = {
    config,
    validateConfig,
    getProviderConfig,
    isProviderAvailable,
    getAvailableProviders
};
