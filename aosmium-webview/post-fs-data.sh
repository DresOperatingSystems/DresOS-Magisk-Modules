#!/system/bin/sh

MODDIR=${0%/*}
mkdir -p "$MODDIR/logs" 2>/dev/null
LOG="$MODDIR/logs/boot.log"
: > "$LOG"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }

log "post-fs-data start"

if [ -f "$MODDIR/boot_pending" ]; then
    log "STALE boot_pending. Previous boot crashed. Disabling module."
    touch "$MODDIR/disable"
    touch "$MODDIR/inert"
    rm -f "$MODDIR/boot_pending"
    exit 0
fi

touch "$MODDIR/boot_pending"

if [ -f "$MODDIR/inert" ]; then
    log "Inert mode active. Skipping."
    exit 0
fi

log "post-fs-data complete"
exit 0
