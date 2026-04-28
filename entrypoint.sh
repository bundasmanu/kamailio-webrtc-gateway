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

case "$1" in
    shell)
        exec /bin/bash --login
        ;;
    start)
        ##start_rsyslogd
        /usr/sbin/kamailio -DD -P ${TMP_FILE_LOCATION}/kamailio.pid -u $STARTER_KAM_USER -g $STARTER_KAM_GROUP -f $CONFIGS_FOLDER/$CFGFILE -m $SHM_MEMORY -M $PKG_MEMORY
        ;;
    test-config)
        /usr/sbin/kamailio -c -DD -P ${TMP_FILE_LOCATION}/kamailio.pid -u $STARTER_KAM_USER -g $STARTER_KAM_GROUP -f $CONFIGS_FOLDER/$CFGFILE -m $SHM_MEMORY -M $PKG_MEMORY
        ;;
    test-version)
        /usr/sbin/kamailio -v
        ;;
    *)
        echo "Executing custom command"
        exec "$@"
        ;;
esac
