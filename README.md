# PropFlow

Fractional Real Estate Tokenization on the Arc Blockchain (Circle's L1).

PropFlow allows investors to purchase fractional ownership of yield-generating UAE properties on-chain using USDC, with rental income automatically distributed back to token holders in proportion to their stake.

---

## Architecture Overview

```mermaid
graph TD
    subgraph Client [Investor (Flutter App)]
        A[Login / Auth Gate] --> B[KYC Verification]
        B --> C[Property Explorer]
        C --> D[Buy Shares]
        D --> E[Portfolio & Yield Tracker]
    end

    subgraph Backend [Firebase Suite]
        F[Firestore Database]
        G[Cloud Functions]
        H[Firebase Auth]
    end

    subgraph Blockchain [Arc L1 Testnet]
        I[PropertyRegistry Contract]
        J[PropToken Contract]
        K[RentDistributor Contract]
        L[KYCRegistry Contract]
    end

    Client -->|User Sign-In| H
    Client -->|Store User Profile / Tx History| F
    Client -->|Proxy Circle Wallet Requests| G
    G -->|Create Embedded Wallet / Webhooks| CircleAPI[Circle Wallets API]
    Client -->|Read/Write Blockchain State| Blockchain
```

---

## Directory Structure

*   **`contracts/`**: Core Solidity smart contracts representing KYC compliance, property tokens, and yield distribution mechanisms.
*   **`flutter_app/`**: Cross-platform Flutter mobile client featuring modern glassmorphism UI, wallet connection, and portfoilo management.
*   **`functions/`**: Node.js Firebase Cloud Functions managing proxy requests for Circle Programmable Wallets API and webhook triggers.

---

## Getting Started

### 1. Prerequisites
- Flutter SDK (v3.29+)
- Node.js (v18+)
- Firebase CLI (`npm install -g firebase-tools`)

### 2. Environment Setup
Create a `.env` file from the provided template inside the `functions` directory:
```bash
cp functions/.env.example functions/.env
```
Fill in the configuration keys:
- `CIRCLE_API_KEY`: Circle Developer Console API key.
- `ADMIN_PRIVATE_KEY`: Private key of the administrator/distributor account.

### 3. Deploy Smart Contracts
Deploy the contracts to the Arc Testnet using Remix IDE or your preferred Ethereum tooling in this order:
1. `KYCRegistry.sol`
2. `PropToken.sol`
3. `RentDistributor.sol`
4. `PropertyRegistry.sol`

Update [constants.dart](flutter_app/lib/utils/constants.dart) and `functions/.env` with your newly deployed contract addresses.

### 4. Run the Mobile App
Get Flutter dependencies and run the app:
```bash
cd flutter_app
flutter pub get
flutter run
```

### 5. Start Firebase Emulator (For Local Testing)
```bash
cd functions
npm install
firebase emulators:start
```
