#!/system/bin/sh
##############################################################################
#  DresOS AOSmium WebView: post-fs-data.sh
#
#  Bootloop sentinel. Runs blocking, before zygote, before Magisk mounts
#  modules. The logic:
#
#    1. If boot_pending exists from a previous boot, the previous boot did
#       not reach service.sh, which means it crashed before boot complete.
#       Auto disable the module and mark it inert. Do nothing else.
#
#    2. Otherwise, drop a boot_pending marker. service.sh will remove it
#       once the device successfully reaches boot complete and the
#       activation logic ran to its conclusion.
#
#    3. If an inert marker exists, log it and exit silently. The module's
#       files are already mounted by Magisk (which happens before this
#       script runs), but no activation will be attempted in service.sh.
#
#  This script never touches the WebView selection itself. All activation
#  is deferred to service.sh, which runs after boot complete when the
#  framework is fully up.
##############################################################################

MODDIR=${0%/*}
LOG_DIR="$MODDIR/logs"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG="$LOG_DIR/boot.log"

# Truncate boot log on each fresh sentinel cycle so it only holds the latest
# boot, not the entire history. We keep the long history in service.log.
: > "$LOG"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $1" >> "$LOG"; }

log "post-fs-data start"
log "API: $(getprop ro.build.version.sdk)"
log "ABI: $(getprop ro.product.cpu.abi)"
log "Device: $(getprop ro.product.manufacturer) $(getprop ro.product.model)"

##############################################################################
#  Bootloop detection.
##############################################################################

if [ -f "$MODDIR/boot_pending" ]; then
    log "STALE boot_pending detected. Previous boot did not finish."
    log "Engaging bootloop fallback."

    # Hard switch: Magisk recognises this file and skips the module entirely
    # on subsequent boots until the user toggles it back on in the Magisk app.
    touch "$MODDIR/disable"

    # Soft switch: even if the user re enables the module without deleting
    # the inert marker, service.sh will still take the safe path.
    touch "$MODDIR/inert"

    # Clear the pending marker so the next boot can be assessed cleanly.
    rm -f "$MODDIR/boot_pending"

    log "Module disabled. Reboot to recover."
    log "Re enable from the Magisk app once the device is stable."
    exit 0
fi

##############################################################################
#  Mark the boot pending.
##############################################################################

touch "$MODDIR/boot_pending"
log "boot_pending marker set"

##############################################################################
#  Inert mode check.
##############################################################################

if [ -f "$MODDIR/inert" ]; then
    log "Inert mode flag is set. Skipping any further action this boot."
    log "Module files remain bind mounted by Magisk but will not be activated."
    exit 0
fi

log "post-fs-data complete. Awaiting boot complete for activation."
exit 0
