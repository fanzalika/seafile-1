#!/bin/bash
#

[ "${autoconf}" == 'true' ] && exit 0
#[ "${restore_prog}" == 'true' ] && exit 0
#[ "${restore_data}" == 'true' ] && exit 0
[ "${restore_latest}" == 'true' ] && exit 0
#[ "${restore_sql}" == 'true' ] && exit 0

. /etc/container_environment.sh

mysql_host=$(echo ${MYSQL_CONTAINER_NAME} | cut -f3 -d/)
date=$(date '+%d%m%Y-%H:%M')
bkpdir=${SEAFILE_DATA}-backup
prog=${date}/prog.cpio
sql=${date}/sql
data=${date}/data
dbs="ccnet seafile seahub"
dbs=$(mysql -h ${mysql_host} -u$MYSQL_USER -p$MYSQL_PASSWORD -Ns -e "show databases" | grep -v information_schema)
sf=/opt/seafile

if df -t fuse.s3ql /data >/dev/null 2>&1 ; then
	mkdir -p ${bkpdir}/$date ${bkpdir}/$sql
        exec 1> ${bkpdir}/$date/backup.log 2>&1

        echo "Backing up seafile prog: /etc/nginx/certs/$CCNET_IP $sf/ccnet $sf/conf $sf/logs $sf/pids $sf/seafile-*server* $sf/seahub* $sf/nginx/${CCNET_IP}"
	find /etc/nginx/certs/$CCNET_IP $sf/ccnet $sf/conf $sf/logs $sf/pids $sf/seafile-*server* $sf/seahub* $sf/nginx/${CCNET_IP} | cpio -o | gzip > ${bkpdir}/$prog

        echo "Backing up seafile data : ${SEAFILE_DATA}"
	s3qlcp ${SEAFILE_DATA} ${bkpdir}/$data

        echo -n "Backing up databases: "
        for db in $dbs; do
                echo -n "$db "
                mysqldump -h $mysql_host -u$MYSQL_USER -p$MYSQL_PASSWORD --opt $db > ${bkpdir}/${sql}/$db.sql
        done
        echo

        echo "Creating latest link"
	rm -f ${bkpdir}/latest
	ln -s ${bkpdir}/${date} ${bkpdir}/latest

	# Clean old backups
	keep=$(ls -1tra ${bkpdir}/ | grep -v latest | tail -25)
	for i in $(ls -1tra ${bkpdir}/ | grep -v latest) ; do
		if echo "$keep" | grep $i >/dev/null ; then
			continue
		fi
		s3qlrm "$bkpdir/$i"
	done
        echo "backup complete"
else
	echo NOT ABLE TO BACKUP 
fi
