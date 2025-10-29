# Custom Setup Guide

This guide walks through setting up the Plaid quickstart with custom ports and obtaining Plaid credentials for use in downstream applications (like `personal-finance`).

## Prerequisites

- Node.js >= 14.0.0
- npm
- Plaid API credentials (`PLAID_CLIENT_ID` and `PLAID_SECRET`) in `.env`

## Overview

This repo has been customized to use non-standard ports. See [local-modifications.md](./local-modifications.md) for details on port configuration.

For a technical deep dive into how Plaid OAuth and token exchange work, see [how-this-works.md](./how-this-works.md).

## Step-by-Step Setup

### 0. Initialize `.env` File

If you're starting fresh, copy the example file and fill in your credentials:

```bash
cp .env.example .env
```

Then edit `.env` and fill in `PLAID_CLIENT_ID` and `PLAID_SECRET` with your Plaid API keys from https://dashboard.plaid.com/team/keys.

### 1. Verify Root `.env` Configuration

Verify the root `.env` file contains your Plaid credentials:

```bash
cat .env | grep PLAID_
```

You should see:
```
PLAID_CLIENT_ID=your_client_id
PLAID_SECRET=your_secret
```

If not, add them to `.env` before proceeding.

### 2. Start the Node Backend

Open a terminal and navigate to the `node/` directory:

```bash
cd node
npm install
npm start
```

You should see output like:
```
plaid-quickstart server listening on port 8008
```

Keep this terminal open—you'll need to watch for the access token output later.

### 3. Start the React Frontend

Open **another terminal** and navigate to the `frontend/` directory:

```bash
cd frontend
npm install
npm start
```

The React app should automatically open in your browser at `http://localhost:3003`.

If it doesn't open automatically, navigate to `http://localhost:3003` manually.

### 4. Complete the Plaid Auth Flow

1. In the frontend app, click the **"Link Account"** button
2. Select a financial institution (e.g., "Sandbox Bank")
3. Use the Plaid sandbox credentials:
   - **Username**: `user_good`
   - **Password**: `pass_good`
4. Complete the multi-factor authentication flow (if prompted)
5. Grant permissions for transactions and account access

### 5. Retrieve Access Token and Item ID

After completing the auth flow, **watch the Node server terminal** for output like:

```json
{
  expiration: '2025-10-29T09:57:31Z',
  link_token: '-----',
  request_id: '-----'
}
{
  access_token: 'access-sandbox-12345...',
  item_id: 'item-12345...',
  request_id: '-----'
}
```

**Copy the `access_token` and `item_id` values** — you'll need these next.

### 6. Configure Downstream Application (e.g., personal-finance)

If you're using these credentials in another application (like `personal-finance`), add them to that application's `.env` file:

```bash
# In personal-finance/.env
PLAID_ACCESS_TOKEN=access-sandbox-12345...
PLAID_ITEM_ID=item-12345...
```

Now you can run scripts in the downstream application to pull transactions directly from Plaid without relying on this quickstart running.

## Troubleshooting

### Frontend won't start on port 3003
- Verify `frontend/.env` contains `PORT=3003`
- Check if another process is using port 3003: `lsof -i :3003`

### Backend won't start on port 8008
- Check if another process is using port 8008: `lsof -i :8008`
- Verify `node/.env` (symlink to root `.env`) contains valid Plaid credentials

### Auth flow not completing
- Ensure both frontend and backend are running
- Check browser console for CORS or network errors
- Verify the backend is accessible at `http://localhost:8008`

### No tokens appearing in Node server output
- Ensure you completed the full auth flow (all steps including MFA if required)
- Check the browser's network tab in DevTools for errors
- Look for error messages in the Node server terminal

## Stopping the Services

Press `Ctrl+C` in each terminal to stop the frontend and backend servers.

## Remote Access

If running on a remote machine (e.g., `vm-dev`), access the frontend via:
```
http://vm-dev:3003
```

The frontend is configured to listen on all network interfaces (`0.0.0.0`).
