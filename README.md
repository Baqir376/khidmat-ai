# Khidmat AI 🇵🇰 — Agentic AI Service Orchestrator

[![Hackathon Project](https://img.shields.io/badge/Google_AI_Seekho-Hackathon_Challenge_2-blueviolet.svg)](#)
[![Stack](https://img.shields.io/badge/Stack-FastAPI_|_Flutter_|_Supabase_|_Gemini-blue.svg)](#)
[![Status](https://img.shields.io/badge/Status-Deploy_Ready-success.svg)](#)

**Khidmat AI** is an Agentic AI marketplace service orchestrator built for the **Google AI Seekho Hackathon (Challenge 2)**. It automates the lifecycle of informal home-service requests (plumbers, electricians, tutors, beauticians) in Pakistan—transforming fragmented off-platform transactions into a structured, automated, and trust-backed system using a **7-agent orchestration pipeline** powered by Google Gemini.

This README documents the **exact implementation details** of the system, including what is running in production, what is simulated for demonstration, and how the fallback configurations operate.

---

## 📖 Table of Contents
1. [🌟 Features & Real vs. Simulated Status](#-features--real-vs-simulated-status)
2. [🤖 The 7-Agent Pipeline](#-the-7-agent-pipeline)
3. [🏗️ Project Architecture](#️-project-architecture)
4. [⚙️ Environment Configuration (.env)](#-environment-configuration-env)
5. [🚀 How to Run Locally](#-how-to-run-locally)
6. [☁️ How to Deploy to Render](#️-how-to-deploy-to-render)
7. [📲 Wireless Mobile App Installation (APK)](#-wireless-mobile-app-installation-apk)

---

## 🌟 Features & Real vs. Simulated Status

To guarantee absolute transparency for evaluation, here is the status of every feature in the codebase:

| Component / Feature | Implementation Status | Technical Details |
| :--- | :--- | :--- |
| **Agentic NLP Engine** | **100% Real** | Core orchestrator utilizes **Google Gemini 2.0 Flash** (`google-generativeai`) to parse natural language requests, extract categories, match providers, and output JSON schemas. |
| **Database Storage** | **100% Real** | All collections (`providers`, `bookings`, `messages`, `agentTraces`, `serviceTypes`) run on a production **Supabase REST database client** over async HTTP calls. |
| **Womens Safety Mode** | **100% Real** | Dynamic filter matches user parameters to verified female-only service providers. |
| **Geofencing & Distance** | **100% Real** | Uses the **Haversine formula** to calculate real coordinate distances (in kilometers) between citizens and providers. |
| **Blockchain Receipts** | **Hybrid / Real** | Uses **Web3.py** to write cryptographic booking hashes (`SHA-256`) onto the **Polygon Amoy Testnet** (returns explorer links). Falls back to mock hash generation if RPC/keys are omitted. |
| **WhatsApp & SMS** | **Hybrid / Real** | Messages are dispatched using **Twilio API**. It includes a **Telegram Bot API fallback** (sends to a testing chat) and console logs to prevent billing blockers. |
| **Voice Call Agent** | **Simulated** | Triggers mock voice call responses to console outputs. |
| **Payment & Escrow** | **Simulated Sandbox** | Simulates mock transactions representing **JazzCash** / **EasyPaisa** sandbox integrations and locks virtual escrow status. |

---

## 🤖 The 7-Agent Pipeline
Orchestrated by the `CoordinatorAgent`, the system runs a unified 7-stage pipeline:
1. **IntentAgent:** Uses Gemini 2.0 Flash to translate voice, text, or photo inputs into structured JSON parameters (service type, area, time, urgency).
2. **DiscoveryAgent:** Queries the Supabase provider pool and flags weather warnings based on real-time coordinates.
3. **MatchingAgent:** Ranks providers based on Distance (30%), Availability (25%), Trust Score (20%), Price Fit (15%), and Response Time (10%).
4. **NegotiationAgent:** Calculates fair market rates and suggests counter-quotes on behalf of the customer.
5. **BookingAgent:** Writes bookings to the database, initiates escrow hold, and submits receipt metadata to the Polygon blockchain.
6. **FollowUpAgent:** Dispatches alerts (via Twilio/Telegram) and processes arrival verification steps.
7. **DemandPredictionAgent:** Generates weekly forecast heatmaps using historical databases.

---

## 🏗️ Project Architecture

```
   ┌──────────────────────────────────────────────┐
   │                 INPUT LAYER                  │
   │   Flutter Mobile App  │  Web Dashboard       │
   └──────────────────────┬───────────────────────┘
                          ↓
   ┌──────────────────────────────────────────────┐
   │             FASTAPI BACKEND CORE             │
   │  7-Agent Orchestrator Pipeline (Gemini)      │
   └──────────────────────┬───────────────────────┘
                          ↓
   ┌──────────────────────────────────────────────┐
   │                 DATA LAYER                   │
   │   Supabase REST Client (Database Storage)    │
   │   Polygon Amoy Testnet (Blockchain Receipts) │
   │   JazzCash Sandbox (Payment Gateway Mock)    │
   └──────────────────────────────────────────────┘
```

---

## ⚙️ Environment Configuration (.env)

The backend configuration is managed via environment variables in `khidmat-ai/backend/.env`.

### Step-by-Step `.env` Setup:
1. Navigate to the backend directory: `/khidmat-ai/backend`.
2. Copy `.env.example` and rename it to `.env`.
3. Add the following keys (fill in dummy values for optional integrations to use the automatic fallbacks):

```env
# Google Gemini API (Required)
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-2.0-flash

# Supabase Configurations (Required)
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_KEY=your-anon-public-key

# Google Maps API (Optional - Falls back to internal math)
GOOGLE_MAPS_API_KEY=your_maps_api_key

# Twilio (Optional - Falls back to Telegram bot channel or Console logging)
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_WHATSAPP_NUMBER=
TWILIO_PHONE_NUMBER=

# Polygon Amoy Testnet (Optional - Falls back to mock hashing)
POLYGON_RPC_URL=https://rpc-amoy.polygon.technology
WALLET_PRIVATE_KEY=
```

---

## 🚀 How to Run Locally

### 1. Run the FastAPI Backend
Ensure you have Python 3.11 installed.
```powershell
# Navigate to the backend directory
cd khidmat-ai/backend

# Create a virtual environment
python -m venv venv
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run the FastAPI server
python main.py
```
*The API runs at `http://localhost:8000`. You can visit `http://localhost:8000/docs` to test endpoints via Swagger UI.*

### 2. Run the Flutter Mobile App
Ensure you have Flutter SDK installed and a device/emulator connected.
```powershell
# Navigate to the frontend directory
cd frontend

# Resolve dependencies
flutter pub get

# Run the application
flutter run
```

### 3. Run the Web Dashboard
```powershell
# Navigate to the web folder
cd web

# Install Node modules
npm install

# Start the dev server
npm run dev
```

---

## ☁️ How to Deploy to Render
We have added a custom `Dockerfile` and `.dockerignore` to the `khidmat-ai/backend` directory so you can run the backend continuously in the cloud for free.

1. Push your project files to a **GitHub Repository**.
2. Log into the **[Render Dashboard](https://dashboard.render.com)**.
3. Click **New +** -> **Web Service**.
4. Link your GitHub repository.
5. Apply the following settings:
   * **Name:** `khidmat-ai-backend`
   * **Region:** `Singapore` (Recommended for low latency)
   * **Branch:** `main`
   * **Root Directory:** `khidmat-ai/backend` *(Make sure this is set!)*
   * **Runtime:** `Docker`
   * **Instance Type:** `Free`
6. Click **Advanced** -> **Add Environment Variable** and insert all the key-value pairs from your local `.env` file.
7. Click **Create Web Service**. 
8. Once Render shows your deployment as "Live", copy your public URL (e.g., `https://khidmat-ai-backend.onrender.com`).
9. Update `fallbackUrl` in `frontend/lib/services/api_service.dart` with your Render URL, then rebuild your Flutter App.

---

## 📲 Wireless Mobile App Installation (APK)
You can transfer and install the app release build onto your phone **wirelessly** without any USB cables.

### Transfer via WhatsApp Web:
1. Open **[WhatsApp Web](https://web.whatsapp.com)** or the WhatsApp Desktop app on your PC.
2. Open a chat with yourself or a friend.
3. Click the **+** (Attach) icon -> Select **Document**.
4. Browse to the following folder and choose `app-release.apk`:
   `D:\Google_AI_Seekho_Antigravity\frontend\build\app\outputs\flutter-apk\app-release.apk`
5. Press **Send**.
6. Open WhatsApp on your phone, download the file, and tap it to install! *(Allow "Unknown Source Installations" when prompted by Android settings)*.
