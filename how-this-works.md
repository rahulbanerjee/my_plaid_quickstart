# Plaid Quickstart: How It Works

## Executive Summary

The Plaid quickstart is a full-stack demo showing how to integrate Plaid APIs for banking data access. The **core flow** for transaction fetching is:

1. **OAuth Link** → User connects bank via Plaid Link UI
2. **Public Token Exchange** → Backend trades public_token for access_token
3. **Transaction Sync** → Backend polls Plaid API with access_token to fetch transactions
4. **Display** → Frontend shows the data

For your use case (nightly cron jobs pulling transactions), you only need **steps 2-3** after the initial OAuth setup.

---

## Architecture Overview

### Tech Stack
- **Backend:** Express.js (Node.js) + Plaid SDK
- **Frontend:** React + TypeScript + react-plaid-link
- **Configuration:** Environment variables (.env)
- **API:** REST endpoints (POST for tokens, GET for data)

### The Flow Diagram
```
[Browser]
    ↓ "Connect Bank" button
[Plaid Link Modal] (User enters bank credentials)
    ↓ OAuth flow
[Backend: POST /api/set_access_token] (exchanges public_token)
    ↓ stores access_token in memory
[Backend: GET /api/transactions] (uses access_token)
    ↓ calls Plaid API
[Plaid servers] (returns transaction data)
    ↓
[Frontend] (displays transactions)
```

---

## Part 1: Initial Setup (OAuth Flow)

### What the Frontend Does

**File:** `frontend/src/App.tsx:15-117`

On app load, the frontend:

1. Calls `POST /api/info` to check backend connectivity
2. Calls `POST /api/create_link_token` to get a link_token from Plaid
3. Stores link_token in localStorage
4. Renders the Plaid Link button (via react-plaid-link component)

### What Happens When User Clicks "Connect Bank"

The react-plaid-link component handles the Plaid Link UI:
- User logs into their bank
- User approves access to Plaid
- Plaid returns a `public_token` to a callback handler
- Frontend calls `POST /api/set_access_token` with the public_token

### Backend Exchange (Critical Step)

**File:** `node/index.js:246-264`

```javascript
app.post('/api/set_access_token', function (request, response, next) {
  PUBLIC_TOKEN = request.body.public_token;
  Promise.resolve()
    .then(async function () {
      const tokenResponse = await client.itemPublicTokenExchange({
        public_token: PUBLIC_TOKEN,  // ← comes from frontend
      });
      ACCESS_TOKEN = tokenResponse.data.access_token;  // ← STORE THIS
      ITEM_ID = tokenResponse.data.item_id;
      response.json({
        access_token: ACCESS_TOKEN,
        item_id: ITEM_ID,
        error: null,
      });
    })
    .catch(next);
});
```

**Key Point:** After this exchange, the backend has an `access_token` which is the credential needed for all future API calls. In production, you'd store this securely (database, encrypted config, etc.). The quickstart stores it in memory (volatile).

---

## Part 2: Pulling Transaction History

### The Transaction Endpoint

**File:** `node/index.js:282-329`

```javascript
app.get('/api/transactions', function (request, response, next) {
  Promise.resolve()
    .then(async function () {
      let cursor = null;
      let added = [];
      let modified = [];
      let removed = [];
      let hasMore = true;

      // SYNC LOOP: Fetch all transactions with pagination
      while (hasMore) {
        const request = {
          access_token: ACCESS_TOKEN,  // ← uses stored access_token
          cursor: cursor,
        };
        const response = await client.transactionsSync(request);
        const data = response.data;

        cursor = data.next_cursor;
        if (cursor === "") {
          await sleep(2000);  // ← wait 2 seconds if no new data
          continue;
        }

        added = added.concat(data.added);
        modified = modified.concat(data.modified);
        removed = removed.concat(data.removed);
        hasMore = data.has_more;
      }

      // Return the 8 most recent transactions
      const recently_added = [...added].sort(compareTxnsByDateAscending).slice(-8);
      response.json({ latest_transactions: recently_added });
    })
    .catch(next);
});
```

### Why This Design?

The `transactionsSync()` API is designed for **incremental updates**:
- **First call:** cursor = null → returns all historical transactions
- **Subsequent calls:** cursor = previous_next_cursor → returns only new/modified transactions since last call
- **Polling:** If cursor is empty string, it means "check again later" (no new data yet)

This is optimized for webhooks in production, but the quickstart polls manually.

---

## Part 3: Key Entities & Their Meanings

### access_token (THE GOLDEN TICKET)
- Credential that proves authorization to access a specific bank account
- Returned after user authenticates via Plaid Link
- Must be stored securely (never share, never hardcode)
- Tied to one bank connection (one item_id)
- Does NOT expire automatically

### public_token (TEMPORARY)
- Returned by Plaid Link after user authenticates
- Valid for ~30 minutes
- Exchanged for access_token via `itemPublicTokenExchange()`
- Client-side only (frontend gets it from Plaid modal)

### item_id
- Unique identifier for the bank connection
- One per bank account linked
- Used for metadata/institution lookups
- Not sensitive (can be logged)

### Plaid Products
- Feature flags in `/api/create_link_token` config
- Determines what data you can request
- Common ones: `transactions`, `auth`, `balance`, `identity`
- Configured in `.env` as `PLAID_PRODUCTS=transactions,auth`

---

## Configuration (`.env`)

### Required Variables
```bash
PLAID_CLIENT_ID=your_id_here          # From Plaid dashboard
PLAID_SECRET=your_secret_here         # From Plaid dashboard
PLAID_ENV=sandbox                     # sandbox | production
```

### Optional Variables
```bash
PLAID_PRODUCTS=transactions           # Comma-separated: auth,balance,etc
PLAID_COUNTRY_CODES=US                # Bank search countries
PLAID_REDIRECT_URI=http://localhost:3000  # For OAuth flow
APP_PORT=8000                         # Backend port (custom: 8008 in this repo)
FRONTEND_PORT=3000                    # Frontend port (custom: 3003 in this repo)
```

**Note:** This repo uses custom ports (8008/3003). See [local-modifications.md](./local-modifications.md) for details.

---

## Building Your Minimal Standalone Server

### What You Need
1. **access_token** (stored from initial OAuth - one time setup)
2. **item_id** (optional, for metadata)
3. Express.js server with Plaid SDK
4. Database to track cursor position (for incremental syncs)

### Minimal Code Example
```javascript
const { PlaidApi, Configuration, PlaidEnvironments } = require('plaid');
require('dotenv').config();

const client = new PlaidApi(new Configuration({
  basePath: PlaidEnvironments[process.env.PLAID_ENV],
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
      'PLAID-SECRET': process.env.PLAID_SECRET,
      'Plaid-Version': '2020-09-14',
    },
  },
}));

const ACCESS_TOKEN = process.env.PLAID_ACCESS_TOKEN;  // Stored from OAuth setup

async function fetchTransactions() {
  const response = await client.transactionsSync({
    access_token: ACCESS_TOKEN,
    cursor: null,  // Start fresh or load from DB
  });

  console.log('Transactions:', response.data.added);
  // Store cursor in DB for next run
  // return response.data.next_cursor;
}

fetchTransactions().catch(console.error);
```

### To Run Via Cron (Nightly)
```bash
# 1. Set up one-time OAuth to get access_token
npm run start

# 2. Copy access_token to .env as PLAID_ACCESS_TOKEN

# 3. Create a standalone script (e.g., sync-transactions.js)

# 4. Add to crontab
0 2 * * * cd /path/to/server && node sync-transactions.js >> transactions.log 2>&1
```

---

## Mapping Quickstart Endpoints to Your Needs

| Endpoint | Use Case | Status |
|----------|----------|--------|
| `POST /api/create_link_token` | OAuth setup (one-time) | ✓ Keep |
| `POST /api/set_access_token` | Store access_token (one-time) | ✓ Keep |
| `GET /api/transactions` | Fetch transactions | ✓ Keep (refactor to standalone) |
| `POST /api/info` | Health check | ✓ Optional |
| `GET /api/balance` | Account balances | ✓ Keep if needed |
| `GET /api/accounts` | Account list | ✓ Keep if needed |
| Others (auth, identity, liabilities, etc.) | Not needed | ✗ Remove |

---

## Important Notes for Your Use Case

### 1. Access Token Persistence
The quickstart stores tokens in **memory** (volatile):
```javascript
let ACCESS_TOKEN = null;  // ← Lost on restart!
```

For your nightly job, store it in:
- Environment file (.env)
- Database
- AWS Secrets Manager / similar
- Encrypted config file

### 2. Cursor Management
The transactionsSync() API uses pagination via cursor:
- **First sync:** cursor = null → fetches all history
- **Subsequent syncs:** cursor = previous result's next_cursor

Your database should track:
```javascript
{
  access_token: "...",
  item_id: "...",
  cursor: "...",  // ← Last cursor from previous sync
  last_sync: "2025-10-26T02:00:00Z"
}
```

### 3. Sandbox vs Production
- **Sandbox:** Test credentials (user_good / pass_good)
- **Production:** Real bank connections, requires Plaid production credentials

### 4. OAuth Only Required Once
After getting the access_token from the first OAuth flow, you never need the Link UI again. The access_token grants permanent access (until revoked by user).

### 5. Transaction History
- First `transactionsSync()` call returns **all historical transactions** (typically 2+ years)
- Subsequent calls return only **new/modified transactions** since last cursor
- This is why cursor tracking is important

---

## Frontend State Management (Context)

**File:** `frontend/src/Context/index.tsx`

The frontend uses React Context (not Redux) to track:
```typescript
{
  linkSuccess: boolean,          // ← User clicked "Link" and OAuth succeeded
  isItemAccess: boolean,         // ← access_token obtained
  linkToken: string | null,      // ← Current Link token
  accessToken: string | null,    // ← Should be null (never sent to frontend in prod!)
  itemId: string | null,         // ← Bank connection ID
  products: string[],            // ← Enabled products from backend
  // ... errors, flags, etc.
}
```

**Security Note:** The quickstart sends `access_token` to frontend (seen in `/api/info` response). This is for **demo purposes only**. In production, the backend should **never** send the access_token to the frontend.

---

## Summary: Three Simple Steps for Your Use Case

### Step 1: OAuth Setup (One-time, Manual)
1. Run the quickstart: `npm install && npm start`
2. Click "Connect Bank" in UI
3. Complete OAuth flow
4. Note the access_token printed in backend logs

### Step 2: Store the Token Securely
Add to `.env`:
```bash
PLAID_ACCESS_TOKEN=access-...
PLAID_ITEM_ID=item-...
PLAID_SYNC_CURSOR=  # Empty on first run
```

### Step 3: Create Minimal Sync Job
```javascript
// sync-transactions.js
const { PlaidApi, Configuration, PlaidEnvironments } = require('plaid');
require('dotenv').config();

const client = new PlaidApi(new Configuration({
  basePath: PlaidEnvironments[process.env.PLAID_ENV],
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
      'PLAID-SECRET': process.env.PLAID_SECRET,
      'Plaid-Version': '2020-09-14',
    },
  },
}));

async function sync() {
  try {
    const response = await client.transactionsSync({
      access_token: process.env.PLAID_ACCESS_TOKEN,
      cursor: process.env.PLAID_SYNC_CURSOR || null,
    });

    const { added, modified, removed, next_cursor, has_more } = response.data;

    // Process transactions
    console.log(`Added: ${added.length}, Modified: ${modified.length}, Removed: ${removed.length}`);

    // Save to your database
    // saveToDatabase(added, modified, removed);

    // Update cursor in .env or DB
    // process.env.PLAID_SYNC_CURSOR = next_cursor;

    // If has_more, call again
    if (has_more) {
      // Recursive call or queue for next iteration
    }

  } catch (error) {
    console.error('Sync failed:', error.message);
    process.exit(1);
  }
}

sync();
```

Then add to crontab:
```bash
0 2 * * * cd /path && node sync-transactions.js
```

---

## Files You Can Ignore (For Your Use Case)

These are optional features in the quickstart you won't need:
- `Components/` - All React components (UI-specific)
- `/api/identity` - User KYC data
- `/api/balance` - Account balances (unless you need them)
- `/api/holdings` - Investment data
- `/api/liabilities` - Credit accounts
- `/api/assets` - Asset reports
- `/api/statements` - PDF statements
- `/api/payment` - Payment initiation (UK/EU only)
- `/api/transfer_*` - ACH transfers
- `/api/signal_evaluate` - Fraud detection
- `/api/cra/*` - Credit report access
- Payment initiation flow entirely
- CRA products entirely
- Multi-language support
- Docker orchestration

---

## Testing in Sandbox

The quickstart comes with test credentials:
- **Username:** `user_good`
- **Password:** `pass_good`
- **2FA Code:** `1234`

After linking a sandbox account, you can test the `/api/transactions` endpoint without running a full UI.

---

## Production Considerations (Beyond Scope)

For a production version of your standalone server:
1. Store access_token in secure vault (AWS Secrets, Vault, etc.)
2. Implement database for cursor tracking
3. Add error handling & logging
4. Monitor rate limits (Plaid has per-minute quotas)
5. Implement webhook listeners (instead of polling)
6. Add data validation & sanitization
7. Encrypt DB connections
8. Implement access controls & audit logging

---

## Q&A

**Q: Do I need the React frontend?**
A: No. After the initial OAuth setup, the backend can run independently. The frontend is just a convenient UI for the OAuth flow.

**Q: Do I need to keep the browser open?**
A: No. After OAuth, the access_token is stored on the backend. You can run cron jobs independently.

**Q: How often can I pull transactions?**
A: Plaid allows ~1000 requests/minute per account. For nightly pulls, this is no issue.

**Q: What if the bank revokes access?**
A: Plaid will return an error on the `transactionsSync()` call. You'll need to re-run the OAuth flow.

**Q: Can I link multiple bank accounts?**
A: Yes. Each bank account gets its own access_token and item_id. Run the OAuth flow once per account.

**Q: How long is transaction history available?**
A: Depends on the bank. Typically 2 years, but some banks provide more. First sync returns all available history.

**Q: Do I need to worry about duplicate transactions?**
A: The cursor-based system handles this. Cursor tracks position; re-running with old cursor returns no new data.

**Q: Can this run offline?**
A: No, it requires API access to Plaid servers (which then access the bank). No local-only option.
