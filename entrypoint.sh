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

# Replace every occurrence of $1 with $2 in config.cfg and PROM_STATS_LISTEN.
substitute_in_kamailio_config() {

    local tok="$1" val="$2"
    local cfg="${CONFIGS_FOLDER}/config.cfg"
    [[ -f "$cfg" ]] || { echo "[ERROR] Expected ${cfg} after copy_config_from_mount" >&2; exit 1; }

    sed "s|${tok}|${val}|g" "$cfg" >"${cfg}.new" && mv "${cfg}.new" "$cfg"
    if [[ -n "${PROM_STATS_LISTEN:-}" ]]; then
        export PROM_STATS_LISTEN="${PROM_STATS_LISTEN//${tok}/${val}}"
    fi

}

substitute_kamailio_fqdn_placeholders() {

    [[ -n "${POD_NAME:-}" && -n "${POD_NAMESPACE:-}" && -n "${INSTANCE_NAME:-}" ]] || {
        echo "[ERROR] POD_NAME, POD_NAMESPACE, and INSTANCE_NAME must be set for DNS substitution" >&2
        exit 1
    }

    local pod_fqdn inst_fqdn
    pod_fqdn="${POD_NAME}.${INSTANCE_NAME}.${POD_NAMESPACE}.svc.cluster.local"
    inst_fqdn="${INSTANCE_NAME}.${POD_NAMESPACE}.svc.cluster.local"
    export LISTEN_FQDN="$pod_fqdn"

    LISTEN_IP=$(getent hosts "$pod_fqdn" | awk '{print $1}')
    export LISTEN_IP="$LISTEN_IP"

    export INST_FQDN="$inst_fqdn"

    substitute_in_kamailio_config "__KAMAILIO_LISTEN_POD_SET_FQDN__" "$pod_fqdn"
    substitute_in_kamailio_config "__KAMAILIO_LISTEN_INSTANCE_FQDN__" "$inst_fqdn"
}

case "$1" in
    shell)
        exec /bin/bash --login
        ;;
    start)
        ##start_rsyslogd
        echo "Hello"
        copy_config_from_mount
        substitute_kamailio_fqdn_placeholders
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
