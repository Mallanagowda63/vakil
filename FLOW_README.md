# Vakil connected consultation flow

## Architecture

- `vakil/`: Flutter customer app. `RequestConsultationScreen` creates, watches, and cancels a request.
- `partner/`: Flutter lawyer app. `PartnerConsultationService` receives `new_request`, lists pending work, and performs accept/reject/start/complete transitions.
- `admin/`: React/Vite portal in the LegalDash design (`src/pages/*`, shared `src/ui.jsx`): dashboard, lawyers (verification workspace), pricing, customers, live view, billing, payments, wallets, payouts, commission, consultation history with transcripts, call logs, complaints, refunds, reviews, reports. Settings are stored in `settings` (+ `settings_audit`); money pages read `payments`, `wallet_transactions`, `payouts`, `refunds`, which stay empty until the apps charge.
- `vakil/server/`: Express, MongoDB, Socket.IO, JWT and optional Firebase Admin.

MongoDB collections are `users`, `lawyers`, `consultation_requests`, `request_status_logs`, `sessions`, `payments`, `reviews`, and `notifications`. Request writes use compare-and-set transitions so two accept/reject calls cannot both win. Every successful transition creates a status log.

## API and events

`POST /api/consultations`, `GET /api/consultations`, `GET /api/consultations/:id`, and `POST /api/consultations/:id/{accept|reject|cancel|start|complete|review}` implement the lifecycle. Presence and device tokens use `PATCH /api/lawyers/me/presence` and `POST /api/devices`. Admin endpoints (role `admin`, phone numbers included): `/api/admin/dashboard`, `/api/admin/live`, `/api/admin/requests` (filters `status`, `trial`, `from`, `to`, `lawyerId`, `userId`, search `q`, `page`), `/api/admin/requests/:id` (timeline, transcript, calls), `/api/admin/calls`, `/api/admin/lawyers` (PATCH approve/block), `/api/admin/users` (PATCH block), and CSV exports `/api/admin/requests.csv`, `/api/admin/requests/:id/transcript.csv`, `/api/admin/calls.csv`. Blocking signs the account out at once.

Sockets authenticate with `{ auth: { token: JWT } }`. Rooms are per identity. Events are `new_request`, `request_accepted`, `request_rejected`, `request_expired`, and `status_updated`. Reconnecting clients must always fetch the REST list again; sockets are an acceleration channel, not the source of truth.

## Free trial and per-minute billing

The user's first chat ever is a free 1-minute trial (`isTrial: true`): it counts down from the lawyer's accept (`endsAt`), and at 0:00 the server ends the chat and any call (`endReason: time_over`). The trial is consumed only when the trial chat completes.

Every later chat is paid per minute from the user's wallet at the lawyer's `ratePerMinute`, locked when the request is made. Creating a request (or starting a call) needs at least one minute of balance, otherwise 402 "Insufficient balance". Minute 1 is charged when the lawyer accepts and each further minute at its start by a one-second server sweep; the billing state (`billedMinutes`, `totalAmount`, `nextChargeAt`) is stored on the request, so a restart never skips or repeats a minute. Each charge is a wallet debit (`reason` chat or call) and emits `chat_billing`; when the balance cannot cover the next minute both apps get `low_balance` (the lawyer never sees the client's balance). If a minute cannot be paid, the chat and any call end (`endedBy: system`, `endReason: balance_over`). The session stores `totalAmount`, which is also the lawyer's earning. Either side can end earlier with End Chat.

Wallet: `GET /api/wallet`, `POST /api/wallet/order` (the server fixes the amount), `POST /api/wallet/verify` (Razorpay signature checked on the server, credited once), `POST /api/wallet/cancel`. Keys go in `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET`; until then a development server can use `WALLET_TEST_RECHARGE=true`.

## Voice calls

Either side of an ongoing chat can call from the chat's phone icon (audio only, ZEGOCLOUD). `POST /api/consultations/:id/call/start` creates the call (`ringing`) and returns the caller's ZEGO room credentials (a one-hour token04; `ZEGO_SERVER_SECRET` never leaves the server). The receiver's phone rings on the native full-screen call UI (`flutter_callkit_incoming`): from the socket `incoming_call` event while the app is open, and from an FCM data push while it is in the background, closed or locked. The ringing phone reports `POST /api/calls/:id/ringing` (the caller then sees "Ringing…" instead of "Calling…"); Accept calls `/answer` and gets its own credentials, Decline calls `/reject` (it works even when the app is closed). Either side ends with `/end`. Unanswered calls become missed after `CALL_RING_SECONDS` (default 30). Every final status emits `call_answered` / `call_rejected` / `call_missed` / `call_ended`, pushes `call_ended` to a phone that is still ringing, and adds a "Voice call • m:ss" or "Missed voice call" entry to the chat. Call payloads carry `remainingSeconds`: a call ends with its chat.

Needs `ZEGO_APP_ID` and `ZEGO_SERVER_SECRET` in `vakil/server/.env` (otherwise starting a call returns 503). Ringing while an app is closed also needs Firebase (below) in that app.

## Run locally

1. Copy `vakil/server/.env.example` to `.env`, set MongoDB and JWT values, then run `npm install` and `npm run dev` in `vakil/server`.
2. Run `npm install` and `npm run dev` in `admin`. Set `VITE_API_URL` if the API is not on port 4000.
3. Run `flutter pub get` and `flutter run` in each Flutter directory. Android emulator builds should configure the service base URL as `http://10.0.2.2:4000`; a USB device can use `adb reverse tcp:4000 tcp:4000`.
4. Login once in each app. Partner login must send `role: lawyer`. Admin login sends `role: admin`; production must set `ADMIN_LOGIN_CODE` and replace the temporary development login with real OTP/SSO.

For push, place platform Firebase configuration in each Flutter app, request notification permission, obtain the FCM token, and send it to `POST /api/devices`. Put the Firebase service-account JSON in `FIREBASE_SERVICE_ACCOUNT`. Without it, in-app sockets work and notification records are retained, but remote pushes are skipped.

## End-to-end test

Create/approve a lawyer document with `online: true` and a matching `categories` value. Login as that lawyer and as a user. Create a request from the customer screen: it appears immediately in the partner socket and admin history. Accept, start, and complete it; verify both apps update and the admin detail timeline contains all four timestamps. Repeat with reject, customer cancel, and a 60-second no-response expiry. Finally submit a review and download `/api/admin/requests.csv` with an admin JWT.

Production deployments should run expiry through a durable queue (BullMQ/Cloud Tasks) instead of the included one-second database sweeper, store JWT secrets in a secret manager, and add a provider-specific chat/video implementation after the request reaches `ACCEPTED`.
