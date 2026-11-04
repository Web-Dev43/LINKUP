# LINKUP

**Connect. Chat. Play.** A mobile-first, iMessage-inspired chat app built with GitHub Pages and Supabase.

## Current MVP

- Guest sign-in (Supabase anonymous auth)
- Editable guest display names
- Private/group conversation records and invite links
- Realtime text messages
- Private image and voice-message storage
- WebRTC one-to-one voice/video call prototype
- Realtime Tic Tac Toe board

## Stack

- Static HTML/CSS/JavaScript hosted on GitHub Pages
- Supabase Auth, Postgres, Realtime and Storage
- WebRTC for peer-to-peer calling

No paid API key is required. WebRTC uses public STUN servers for initial connectivity. Some networks require a TURN relay; reliable TURN service is not guaranteed to be free. Calls should be tested on separate devices and networks.

## Required Supabase setup

1. Open the LINKUP project in Supabase.
2. Go to **Authentication → Providers** (or Sign-in methods) and enable **Anonymous Sign-Ins**.
3. Confirm the `chat-media` private Storage bucket exists.
4. The database schema and row-level security policies are in `supabase/schema.sql` and have been applied to the connected project.
5. In **Project Settings → API**, use the project URL and publishable key in `index.html`. Never place a service-role/secret key in browser code.

## Publish with GitHub Pages

1. Open this repository's **Settings → Pages**.
2. Under **Build and deployment**, select **Deploy from a branch**.
3. Choose branch **main**, folder **/(root)**, then save.
4. Wait for GitHub Pages to publish the site.

## Important notes

- Guest accounts are anonymous Supabase Auth users. They are associated with the browser's stored auth session. Clearing browser data or switching devices can make a guest account inaccessible.
- Invite links grant access to whoever has the link. Share them privately.
- This is an MVP, not an audited production messaging service. Do not use it for sensitive conversations.
- Voice/video calls use browser microphone/camera permissions and STUN-only ICE configuration. Some network combinations will fail until a TURN relay is configured.
- Browser media features require HTTPS; GitHub Pages provides HTTPS.

## Local preview

Serve the repository root with any static HTTP server. Do not open index.html as a file URL because browser media and module behavior require a secure context.
