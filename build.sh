#!/bin/bash
# build.sh – LiveKit Server Deploy
# Verwendung: bash build.sh

set -e

echo "=== LiveKit Server Deploy ==="

# ── .env prüfen ───────────────────────────────────────────────
echo ""
echo "--- Config ---"
if [ ! -f ".env" ]; then
    cp .env.example .env
    echo "  ⚠️  .env erstellt – bitte LIVEKIT_KEYS anpassen und nochmal ausführen!"
    echo "  Öffne: nano .env"
    exit 1
fi

# LIVEKIT_KEYS aus .env lesen
source .env
if [ -z "$LIVEKIT_KEYS" ] || [ "$LIVEKIT_KEYS" = "meinkey:meingeheimespasswort" ]; then
    echo "  ❌ Bitte LIVEKIT_KEYS in .env setzen!"
    echo "  Beispiel: LIVEKIT_KEYS=\"myapikey:mysupersecret\""
    exit 1
fi
echo "  ✅ Config geladen"

# ── Docker Network ────────────────────────────────────────────
echo ""
echo "--- Network ---"
if docker network ls | grep -q livekit-net; then
    echo "  ✅ Network livekit-net existiert bereits"
else
    docker network create livekit-net
    echo "  ✅ Network livekit-net erstellt"
fi

# ── Alten Container stoppen ───────────────────────────────────
echo ""
echo "--- Cleanup ---"
docker stop livekitserver 2>/dev/null || true
docker rm   livekitserver 2>/dev/null || true
echo "  ✅ Alter Container entfernt"

# ── LiveKit starten ───────────────────────────────────────────
echo ""
echo "--- Start ---"
docker run -d \
  --name livekitserver \
  --network livekit-net \
  -p 7880:7880 \
  -p 7881:7881 \
  -p 50000-50020:50000-50020/udp \
  -e LIVEKIT_KEYS="$LIVEKIT_KEYS" \
  -v "$(pwd)/livekit.yaml:/livekit.yaml" \
  --restart unless-stopped \
  livekit/livekit-server:latest \
  --config /livekit.yaml \
  --bind 0.0.0.0

# Netzwerk-Fix (Standard-Bridge entfernen)
docker network disconnect bridge livekitserver 2>/dev/null || true

echo "  ✅ LiveKit gestartet auf Port 7880"

# ── Health Check ─────────────────────────────────────────────
echo ""
echo "--- Health Check ---"
sleep 3
if curl -sf http://localhost:7880 > /dev/null 2>&1; then
    echo "  ✅ LiveKit antwortet"
else
    echo "  ⚠️  Noch nicht bereit – prüfe Logs:"
    echo "     docker logs livekitserver"
fi

echo ""
echo "=== Deploy abgeschlossen: $(date) ==="
echo ""
echo "  Logs:         docker logs -f livekitserver"
echo "  Stoppen:      docker stop livekitserver"
echo "  Neustart:     docker restart livekitserver"
echo ""
echo "  Cloudflare:"
echo "  → livekit.freischule.info → http://<server-ip>:7880"
echo "  → UDP Ports 50000-50020 müssen in der Firewall offen sein!"
echo ""
echo "  PresenceService .env ergänzen:"
echo "  LIVEKIT_URL=wss://livekit.freischule.info"
echo "  LIVEKIT_KEY=<dein-key>"
echo "  LIVEKIT_SECRET=<dein-secret>"
