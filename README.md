# BFF GraphQL Scaffold Generator

A production-ready GraphQL BFF (Backend for Frontend) server template with Redis caching, structured logging, and modern tooling.

## 🚀 Getting Started

### Prerequisites
- Node.js v18+
- npm v9+
- Redis (optional)

### Quick Start

Make the setup script executable and run
```bash
chmod +x setup.sh && ./setup.sh
```
Follow prompts (default project name: bff-graphql-server)
After setup completes:
```bash
cd your-project-name

# for development
pnpm dev

#for production
pnpm run build && pnpm start 
```

## ✨ Features
- 🚀 Apollo Server 4 with Express middleware
- 🔒 Environment-based configuration (dotenv)
- 📦 ESM Modules with esbuild bundling
- 📊 Structured logging with Winston
- 🧩 Redis caching with lazy connection
- 🔄 Development/production ready workflows
- 🛡️ Request validation & error handling
- 📈 Health checks & proper shutdown handling

## 📁 Project Structure

```
├── src/
│   ├── graphql/
│   │   ├── schemas/       # GraphQL type definitions
│   │   └── resolvers/     # Data fetching logic
│   ├── utils/
│   │   └── cache.js       # Redis/Memory caching implementation
│   ├── middleware/
│   │   └── validation.js  # Request validation middleware
│   ├── config/
│   │   └── index.js       # Environment configuration loader
│   └── server.js          # Main application entry point
├── tests/
│   └── graphql/           # Integration/unit tests
├── dist/                  # Production build (generated)
├── logs/                  # Runtime logs (not committed)
├── .env.example           # Environment template
├── esbuild.config.js      # Build configuration
└── package.json           # Project dependencies & scripts
```

## ⚙️ Environment Variables
```env
PORT=4000                 # Server port
NODE_ENV=development      # Runtime environment
ENABLE_REDIS=false        # Toggle Redis caching
REDIS_URL=redis://localhost:6379  # Redis connection URL
```

## 📜 Scripts
```json
"scripts": {
  "dev": "nodemon src/server.js",    // Development with hot reload
  "build": "rm -rf dist && node esbuild.config.js",  // Production build
  "start": "NODE_ENV=production node dist/server.js"  // Start production server
}
```

## 🔧 Best Practices Included
- ✅ PNPM for fast, efficient dependency management
- ✅ Environment-specific configuration
- ✅ Structured JSON logging with Winston
- ✅ Redis cache abstraction with lazy initialization
- ✅ Proper SIGINT handling for clean shutdowns
- ✅ ESM modules with esbuild for modern bundling
- ✅ Request validation middleware
- ✅ Centralized error handling

## 🛠 Development Practices
1. **Linting**: Pre-configured ESLint (add your rules)
2. **Testing**: Jest test framework setup (add your tests)
3. **Logging**: 
   - Errors logged to `logs/error.log`
   - Combined logs in `logs/combined.log`
4. **Caching**:
   - Toggle Redis with `ENABLE_REDIS` flag
   - Automatic fallback to memory when disabled

## 🚨 Redis Configuration
```env
# Enable in .env
ENABLE_REDIS=true

# Requires Redis server running at:
REDIS_URL=redis://localhost:6379
```

## 🚀 Production Deployment
1. Build artifacts:
   ```bash
   pnpm run build
   ```
2. Start production server:
   ```bash
   pnpm start
   ```
3. Recommended:
   - Use process manager (PM2, systemd)
   - Monitor log files
   - Enable Redis for production caching

## 📚 Credits
- [Apollo Server](https://www.apollographql.com/docs/apollo-server/)
- [Express](https://expressjs.com/)
- [esbuild](https://esbuild.github.io/)
- [Winston](https://github.com/winstonjs/winston)
