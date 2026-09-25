# Vakil

Legal consultation platform: clients chat and call verified lawyers, paid per minute from a wallet.

| Folder | What it is |
| --- | --- |
| `vakil/` | User App (Flutter) — find lawyers, chat, voice calls, wallet |
| `vakil/server/` | Backend (Node.js, Express, Socket.IO, MongoDB) |
| `partner/` | Partner App for lawyers (Flutter) — requests, chats, calls, earnings |
| `admin/` | Admin Panel (React + Vite) |

## Setup

1. **Backend:** copy `vakil/server/.env.example` to `vakil/server/.env` and fill in the values, then run `npm install` and `npm start` in `vakil/server`.
2. **Admin Panel:** copy `admin/.env.example` to `admin/.env`, then run `npm install` and `npm run dev` in `admin`.
3. **Apps:** add your Firebase `google-services.json` to `vakil/android/app/` and `partner/android/app/`, then `flutter run` in each folder.

On Windows, `start-vakil-local.ps1` starts the backend for phone testing over USB, and `keep-phones-linked.ps1` keeps connected phones linked to it.

Secrets (`.env`, Firebase keys, keystores) and local data are not committed; see `.gitignore`.
