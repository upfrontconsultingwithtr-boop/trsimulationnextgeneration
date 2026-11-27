# NextGen Life

An original 3D life simulation that runs in the browser, with a shared online neighborhood. It's 100% free and open source: Three.js + Vite on the client and a tiny Node WebSocket server.

## Play now
```bash
npm install
npm start            # builds and serves on http://localhost:8787 (solo + online)
# dev mode with hot reload: `npm run server` in one terminal and `npm run dev` in another
```

## What's in v0.1
- **Character creator:** skin, 6 hair styles, colours, height, build, and 3 of 12 traits.
- **Needs and mood:** hunger, energy, hygiene, bladder, fun, social.
- **Vibes (original mechanic):** each sim has an emotional state that glows as a ring under them. Strong vibes are contagious, so a happy or angry sim spreads that vibe to people nearby.
- **Free will:** NPCs and your sim pick what to do using a utility AI that weighs needs, traits, distance and money.
- **Social system:** 10 interactions, from chat to partner. Friendship and romance meters, and success odds that depend on mood, charisma, traits and vibe.
- **Skills and money:** cooking, fitness, creativity, logic, charisma and music. Earn through freelance gigs, painting and livestreaming. Streaming grows your follower count.
- **Daily goals** that refresh each in-game day and pay out rewards.
- **Neighborhood feed:** life moments post themselves automatically ("X and Y are now friends 🤝").
- **Build mode:** 15 items made from code, with colour picker, rotate (R) and sell.
- **Town:** 8 lots, a plaza with a fountain, food truck and DJ booth, a day/night cycle with bloom, wall cutaway (C), and photo mode (P, then S to save a PNG).
- **Online:** auto-sharded neighborhoods of 8 lots. Each player owns a lot that persists, and you get presence, chat, socials with real players, a shared feed and synced building.
- **Solo saves** go to browser storage automatically.

**Controls:** left-click to act or move · right-drag to rotate · scroll to zoom · middle-drag or WASD to pan · B build · F follow · 0–3 game speed · Esc cancel.

## Hosting for $0
- **Client + server together:** deploy this repo to any free Node host (Render, Koyeb, Fly.io free allowances) with build `npm install && npm run build` and start `node server/server.js`. It uses `PORT` automatically.
- **Static client only (solo):** run `npm run build` and upload `dist/` to GitHub Pages, Netlify or Cloudflare Pages.
- **Static client + server elsewhere:** open `https://your-site/?server=wss://your-server/ws`.

## Roadmap (suggested next steps)
1. Rigged glTF characters from free CC0 assets (Quaternius, Kenney) with real animations.
2. Wall and floor drawing tools, plus multi-story homes.
3. Life stages and aging, families and households.
4. Careers that send sims off-lot, a city map, and more venues.
5. Accounts and moderation for the public server (profanity filter, report and block).
6. Mobile touch UI polish and a PWA install option.
7. Optional AI-driven NPC conversations using a free local model.

## Code map
`src/config.js` tuning · `src/world.js` grid, lots, houses, furniture, A* pathfinding · `src/sim.js` avatars, needs, vibes, AI, socials · `src/main.js` rendering, UI, game loop, save, online · `src/net.js` client · `server/server.js` rooms and persistence.
