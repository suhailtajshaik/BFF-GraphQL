#!/bin/bash

# Prompt for project name
read -p "Enter your project name: " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-bff-graphql-server} # Default if empty

# Check if pnpm is installed, install if missing
if ! command -v pnpm &> /dev/null; then
  echo "🔧 Installing pnpm..."
  npm install -g pnpm
fi

# Create main project directory
mkdir -p $PROJECT_NAME && cd $PROJECT_NAME

echo "🚀 Creating project structure for $PROJECT_NAME..."

# Create folders
mkdir -p src/graphql/{schemas,resolvers} \
         src/utils \
         src/middleware \
         src/config \
         tests/graphql \
         logs \
         dist

# Remove any existing package.json before initializing
rm -f package.json

# Manually create package.json with ESM support and updated build system
echo "📦 Creating package.json..."
cat <<EOL > package.json
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "nodemon src/server.js",
    "build": "rm -rf dist && node esbuild.config.js",
    "start": "NODE_ENV=production node dist/server.js"
  }
}
EOL

# Verify package.json was created properly
if [ ! -f package.json ]; then
  echo "❌ Failed to create package.json. Exiting..."
  exit 1
fi

echo "🔧 Installing dependencies with pnpm..."
pnpm add express @apollo/server graphql graphql-tag dotenv morgan winston @graphql-tools/schema rediss encoding
pnpm add -D nodemon eslint prettier jest supertest esbuild

echo "✅ Dependencies installed!"

# Writing esbuild.config.js
echo "🔄 Creating esbuild configuration..."
cat <<EOL > esbuild.config.js
import { build } from 'esbuild';

await build({
  entryPoints: ['src/server.js'],
  bundle: true,
  platform: 'node',
  format: 'esm',
  outdir: 'dist',
  packages: 'external',
  mainFields: ['module', 'main'],
  external: [
    'encoding',
    'async_hooks',
    'fs',
    'crypto'
  ],
  plugins: [{
    name: 'cjs-shims',
    setup(build) {
      build.onResolve({ filter: /.*/ }, async (args) => {
        if (args.kind === 'require-call') {
          return { path: args.path, external: true }
        }
      });
    }
  }]
});
EOL

# Writing .gitignore
cat <<EOL > .gitignore
node_modules
logs
.env
dist
EOL

# Writing .env file with ENABLE_REDIS=false by default
cat <<EOL > .env
PORT=4000
NODE_ENV=development
ENABLE_REDIS=false
REDIS_URL=redis://localhost:6379
EOL

# Writing config/index.js
cat <<EOL > src/config/index.js
import dotenv from 'dotenv';
dotenv.config();

export default {
  port: process.env.PORT || 4000,
  enableRedis: process.env.ENABLE_REDIS === 'true',
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379'
};
EOL

# Writing Redis cache utility using rediss
cat <<EOL > src/utils/cache.js
import Redis from 'rediss';
import config from '../config/index.js';

let redis = null;

const initRedis = async () => {
  if (config.enableRedis) {
    redis = new Redis(config.redisUrl, { lazyConnect: true });
    await redis.connect();
    console.log('✅ Redis enabled and connected.');
  } else {
    console.log('🚫 Redis is disabled.');
  }
};

await initRedis();

export const cache = {
  async set(key, value, ttl = 3600) {
    if (!redis) return;
    await redis.set(key, JSON.stringify(value), 'EX', ttl);
  },
  async get(key) {
    if (!redis) return null;
    const data = await redis.get(key);
    return data ? JSON.parse(data) : null;
  },
  async del(key) {
    if (!redis) return;
    await redis.del(key);
  }
};

export default redis;
EOL

# Writing GraphQL Schema
cat <<EOL > src/graphql/schemas/user.js
import { gql } from 'graphql-tag';

export default gql\`
  type User {
    id: ID!
    name: String!
    email: String!
  }

  type Query {
    getUser(id: ID!): User
  }
\`;
EOL

# Writing GraphQL Resolver for User
cat <<EOL > src/graphql/resolvers/user.js
import { cache } from '../../utils/cache.js';

const users = [
  { id: '1', name: 'John Doe', email: 'john@example.com' },
  { id: '2', name: 'Jane Doe', email: 'jane@example.com' }
];

export default {
  Query: {
    getUser: async (_, { id }) => {
      const cachedUser = await cache.get(\`user:\${id}\`);
      if (cachedUser) return cachedUser;

      const user = users.find(user => user.id === id);
      if (user) await cache.set(\`user:\${id}\`, user);
      return user;
    }
  }
};
EOL

# Writing GraphQL Entry Point
cat <<EOL > src/graphql/index.js
import { ApolloServer } from '@apollo/server';
import { expressMiddleware } from '@apollo/server/express4';
import { makeExecutableSchema } from '@graphql-tools/schema';
import typeDefs from './schemas/user.js';
import resolvers from './resolvers/user.js';
import express from 'express';
import morgan from 'morgan';
import winston from 'winston';

// Configure Winston logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
  ],
});

// Error handling middleware
const errorHandler = (err, req, res, next) => {
  logger.error({
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });
  
  res.status(400).json({
    error: {
      message: 'Invalid request',
      details: err instanceof SyntaxError ? 'Malformed JSON' : 'Bad request'
    }
  });
};

// Request validation middleware
const validateRequest = (req, res, next) => {
  if (req.method === 'POST' && !req.is('application/json')) {
    logger.warn(\`Invalid content-type: \${req.get('Content-Type')}\`);
    return res.status(415).json({ error: 'Unsupported Media Type' });
  }
  next();
};

const schema = makeExecutableSchema({ typeDefs: [typeDefs], resolvers });

const createApolloServer = async () => {
  const server = new ApolloServer({ schema });
  await server.start();

  const app = express();
  
  // Middleware setup
  app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) }}));
  app.use(express.json());
  app.use(validateRequest);
  app.use('/graphql', expressMiddleware(server));
  app.use((req, res) => {
    logger.warn(\`404: \${req.method} \${req.originalUrl}\`);
    res.status(404).json({ error: 'Not found' });
  });
  app.use(errorHandler);

  return app;
};

export default createApolloServer;
EOL

# Writing Server File
cat <<EOL > src/server.js
import createApolloServer from './graphql/index.js';
import config from './config/index.js';

const startServer = async () => {
  const app = await createApolloServer();
  const server = app.listen(config.port, () => {
    console.log(\`🚀 Server running at http://localhost:\${config.port}/graphql\`);
  });

  process.on('SIGINT', () => {
    server.close(() => {
      console.log('\nServer closed');
      process.exit(0);
    });
  });
};

startServer();
EOL

echo "🚀 Project setup complete! Run 'pnpm run dev' for development or 'pnpm run build && pnpm start' for production."
