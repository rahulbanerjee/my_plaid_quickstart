# Local Modifications

## Port Configuration (8008 & 3003)

This quickstart has been modified to use non-default ports to avoid conflicts with other services:

- **Backend (Node.js)**: Port 8008 (instead of 8000)
- **Frontend (React)**: Port 3003 (instead of 3000)

## Files Modified

### 1. Root `.env`
Added port configuration as a single source of truth:
```
APP_PORT=8008
FRONTEND_PORT=3003
FRONTEND_HOST=0.0.0.0
```

The `FRONTEND_HOST=0.0.0.0` setting makes the frontend accessible from remote machines (e.g., `vm-dev:3003`), equivalent to Flask's `host='0.0.0.0'`.

### 2. `Makefile`
Updated to use environment variables instead of hardcoded ports:
- Changed `REACT_APP_API_HOST=http://$(language):8000` → `http://$(language):${APP_PORT}`
- Updated success message to use `$(FRONTEND_PORT)` instead of hardcoded 3000
- Added `FRONTEND_PORT ?= 3003` for Makefile-level defaults

### 3. `docker-compose.yml`
Applied DRY principle by using environment variable substitution:
- Added `APP_PORT` and `FRONTEND_PORT` to the shared environment defaults
- Changed all service port mappings from `["8000:8000"]` → `["${APP_PORT}:8000"]` (go, java, node, python, ruby services)
- Changed frontend port mapping from `["3000:3000"]` → `["${FRONTEND_PORT}:${FRONTEND_PORT}"]`
- Added `HOST=${FRONTEND_HOST}` to frontend environment so Create React App listens on all interfaces

### 4. `frontend/.env` (New file)
Created local configuration for frontend development:
```
PORT=3003
HOST=0.0.0.0
REACT_APP_API_HOST=http://localhost:8008
```

This allows `npm start` in the frontend directory to work correctly without manual environment setup.

## Running the Services

For step-by-step setup instructions, see [CUSTOM_SETUP.md](./CUSTOM_SETUP.md).

## Remote Access
When running over SSH on a remote machine (e.g., `vm-dev`), you can access:
- Frontend: `http://vm-dev:3003`
- Backend API: `http://vm-dev:8008`

The frontend is configured to listen on `0.0.0.0` (all network interfaces) rather than just `localhost`.

## Customization
To use different ports, modify the root `.env` file:
```bash
APP_PORT=9000
FRONTEND_PORT=4000
FRONTEND_HOST=0.0.0.0
```

Or override temporarily:
```bash
APP_PORT=9000 FRONTEND_PORT=4000 make up
```
