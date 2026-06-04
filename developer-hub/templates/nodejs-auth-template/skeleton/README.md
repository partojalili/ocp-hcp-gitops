# ${{ values.name }}

${{ values.description }}

## Features

- ✅ Express.js REST API
- ✅ JWT Authentication
- ✅ MongoDB Integration
- ✅ Keycloak Support
- ✅ Google OAuth Integration
- ✅ Docker Support

## Getting Started

### Prerequisites

- Node.js 18+
- MongoDB 4.4+
- Docker (optional)

### Installation

```bash
# Install dependencies
npm install

# Copy environment template
cp env .env

# Edit .env with your configuration
nano .env

# Start the application
npm run dev
```

### Using Docker

```bash
# Build the image
docker build -t ${{ values.name }} .

# Run with MongoDB
docker-compose up -d
```

## Environment Variables

Configure the following in your `.env` file:

- `DB` - MongoDB database name (default: ${{ values.databaseName }})
- `HOSTDB` - MongoDB host
- `DBPORT` - MongoDB port
- `PORT` - Application port
- `SESS_NAME` - Session name
- `SESS_LIFETIME` - Session lifetime
- `CLIENT_ID` - Google OAuth client ID
- `CLIENT_SECRET` - Google OAuth client secret

## API Endpoints

### Authentication

- `POST /api/auth/signup` - Register new user
- `POST /api/auth/signin` - Login user
- `POST /api/auth/signout` - Logout user

### User Management

- `GET /api/users` - Get all users (admin only)
- `GET /api/users/:id` - Get user by ID

## Development

```bash
# Run in development mode with auto-reload
npm run dev

# Run tests
npm test
```

## License

ISC

## Owner

${{ values.owner }}
