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

case "$1" in
    shell)
        exec /bin/bash --login
        ;;
    start)
        ##start_rsyslogd
        echo "Hello"
        copy_config_from_mount
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
