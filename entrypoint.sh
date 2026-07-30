if [ "${RCON_PASSWORD}" = "changeme" ]; then
  echo "[entrypoint] WARNING: RCON_PASSWORD is still the default 'changeme'."
  echo "             Set a long random password in your .env before exposing the server."
fi
if [ "${SSH_KEY}" = "changeme" ]; then
  echo "[entrypoint] WARNING: SSH_KEY is still the default 'changeme'."
  echo "             Set path to ssh_key in your .env before exposing the server."
fi

# ---------- Patch server.properties from env (idempotent) ----------
set_prop() {
  local key="$1" val="$2"
  if grep -q "^${key}=" server.properties; then
    sed -i "s|^${key}=.*|${key}=${val}|" server.properties
  else
    echo "${key}=${val}" >> server.properties
  fi
}
set_prop enable-rcon        true
set_prop rcon.port          "${RCON_PORT}"
set_prop rcon.password      "${RCON_PASSWORD}"
set_prop broadcast-rcon-to-ops true
set_prop server-port        "${MC_PORT}"

# ---------- JVM flags ----------
# Aikar's well-known G1GC tuning for Minecraft (big win for heavy modpacks).
AIKAR=(
  -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200
  -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch
  -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M
  -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4
  -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90
  -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32
  -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1
  -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true
)
JVM=( "-Xms${MEMORY}" "-Xmx${MEMORY}" "${AIKAR[@]}" )

# ---------- Console FIFO ----------
# A named pipe lets us (a) forward `docker attach` keystrokes to the server,
# and (b) write "stop" into the server's stdin on SIGTERM for a clean save.
CONSOLE=/tmp/mc-console
rm -f "$CONSOLE"; mkfifo "$CONSOLE"

service cron start

echo "[entrypoint] Starting Forge with ${MEMORY} heap..."
java "${JVM[@]}" "@${ARGS_FILE}" nogui < "$CONSOLE" &
SERVER_PID=$!

# Hold the write end open so the server never receives EOF on stdin,
# then forward our own stdin (docker attach) into the pipe.
exec 3>"$CONSOLE"
cat >&3 &
CAT_PID=$!

graceful_stop() {
  echo "[entrypoint] Stop signal received — saving world and shutting down..."
  echo "stop" >&3 || true
  ./backup.sh 
  wait "$SERVER_PID" 2>/dev/null || true
}
trap graceful_stop SIGTERM SIGINT

wait "$SERVER_PID"
kill "$CAT_PID" 2>/dev/null || true
exec 3>&- || true
echo "[entrypoint] Server process exited."
