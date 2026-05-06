#!/bin/bash

set -e

trap "Ok received Exit" HUP INT QUIT TERM

start_rsyslogd() {
    sed -i "s|\${LOG_FILE_DIR}|$LOG_FILE_DIR|g" /etc/rsyslog.d/kamailio.conf
    sed -i "s|\${LOG_FILE_DIR}|$LOG_FILE_DIR|g" /etc/logrotate.d/kamailio
    sed -i "s|\${LOG_FILE_NAME}|$LOG_FILE_NAME|g" /etc/rsyslog.d/kamailio.conf
    sed -i "s|\${LOG_FILE_NAME}|$LOG_FILE_NAME|g" /etc/logrotate.d/kamailio
    rsyslogd -n &
}

copy_config_from_mount() {
    if [ -f /tmp/config/config.cfg ]; then
        cp /tmp/config/config.cfg ${CONFIGS_FOLDER}/config.cfg
        echo "[INFO] Copied config.cfg from /tmp/config to ${CONFIGS_FOLDER}/config.cfg"
    else
        echo "[WARN] config.cfg not found in /tmp/config, using existing file if present"
        exit 1
    fi
}

# Replace __KAMAILIO_LISTEN_ADDR__ with pod DNS (${POD_NAME}.${INSTANCE_NAME}.${POD_NAMESPACE}.svc.cluster.local).
substitute_kamailio_listen_addr() {
    local tok="__KAMAILIO_LISTEN_ADDR__" cfg="${CONFIGS_FOLDER}/config.cfg"
    [[ -f "$cfg" ]] || { echo "[ERROR] Expected ${cfg} after copy_config_from_mount" >&2; exit 1; }

    local need_cfg=false need_env=false
    # Avoid `cmd && var=true` under `set -e`: a failed grep or failed [[ aborts the script.
    if grep -q "$tok" "$cfg" 2>/dev/null; then need_cfg=true; fi
    if [[ -n "${PROM_STATS_LISTEN:-}" && "${PROM_STATS_LISTEN}" == *"$tok"* ]]; then need_env=true; fi
    if ! $need_cfg && ! $need_env; then
        echo "[INFO] No ${tok} in ${cfg} or PROM_STATS_LISTEN; skipping substitution"
        return 0
    fi

    [[ -n "${POD_NAME:-}" && -n "${POD_NAMESPACE:-}" && -n "${INSTANCE_NAME:-}" ]] || {
        echo "[ERROR] POD_NAME, POD_NAMESPACE, and INSTANCE_NAME must be set to replace ${tok}" >&2
        exit 1
    }
    local fqdn="${POD_NAME}.${INSTANCE_NAME}.${POD_NAMESPACE}.svc.cluster.local"
    export LISTEN_FQDN="$fqdn"

    $need_cfg && { sed "s|${tok}|${fqdn}|g" "$cfg" >"${cfg}.new" && mv "${cfg}.new" "$cfg"; }
    $need_env && export PROM_STATS_LISTEN="${PROM_STATS_LISTEN//${tok}/${fqdn}}"

    if grep -q "$tok" "$cfg" || [[ "${PROM_STATS_LISTEN:-}" == *"$tok"* ]]; then
        echo "[ERROR] ${tok} still present after substitution (config or PROM_STATS_LISTEN)" >&2
        exit 1
    fi
    echo "[INFO] Replaced ${tok} with ${fqdn} (DNS name; Kamailio resolves at startup)"
}

case "$1" in
    shell)
        exec /bin/bash --login
        ;;
    start)
        ##start_rsyslogd
        echo "Hello"
        copy_config_from_mount
        substitute_kamailio_listen_addr
        /usr/sbin/kamailio -c -DDD -u $STARTER_KAM_USER -g $STARTER_KAM_GROUP -f $CONFIGS_FOLDER/$CFGFILE -m $SHM_MEMORY -M $PKG_MEMORY
        /usr/sbin/kamailio -DD -u $STARTER_KAM_USER -g $STARTER_KAM_GROUP -f $CONFIGS_FOLDER/$CFGFILE -m $SHM_MEMORY -M $PKG_MEMORY
        ;;
    test-config)
        /usr/sbin/kamailio -c -DD -u $STARTER_KAM_USER -g $STARTER_KAM_GROUP -f $CONFIGS_FOLDER/$CFGFILE -m $SHM_MEMORY -M $PKG_MEMORY
        ;;
    test-version)
        /usr/sbin/kamailio -v
        ;;
    *)
        echo "Executing custom command"
        exec "$@"
        ;;
esac
