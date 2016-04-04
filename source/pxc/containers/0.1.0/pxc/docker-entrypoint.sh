#!/bin/bash
set -eo pipefail

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
fi

if [ "$1" = 'mysqld' ]; then
	# Get config
	DATADIR="$(mysqld --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"

	if [ ! -d "$DATADIR/mysql" ] && [ ! -f "/opt/rancher/configured" ]; then
		if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
			echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
			echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
			exit 1
		fi

		mkdir -p "$DATADIR"
		chown -R mysql:mysql "$DATADIR"

		echo 'Initializing database'
		mysql_install_db --datadir=${DATADIR} >/dev/null 2>&1
		echo 'Database initialized'

		cat > /tmp/init.sql <<-EOSQL
			-- What's done in this file shouldn't be replicated
			--  or products like mysql-fabric won't work
			SET @@SESSION.SQL_LOG_BIN=0;

			DELETE FROM mysql.user ;
			CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
			GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
			UPDATE mysql.user set Password=PASSWORD('${MYSQL_ROOT_PASSWORD}') where user='root' ;
			DROP DATABASE IF EXISTS test ;
			DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%' ;
			CREATE USER 'sstuser'@'%' IDENTIFIED BY '${PXC_SST_PASSWORD}' ;
			GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'sstuser'@'%' ;
			GRANT PROCESS ON *.* TO 'clustercheckuser'@'localhost' IDENTIFIED BY 'clustercheckpassword!' ;
			FLUSH PRIVILEGES ;
		EOSQL

		if [ "$MYSQL_DATABASE" ]; then
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" > /tmp/init.sql
		fi

		if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
			echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" > /tmp/init.sql

			if [ "$MYSQL_DATABASE" ]; then
				echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;" > /tmp/init.sql
			fi

			echo 'FLUSH PRIVILEGES ;' > /tmp/init.sql
		fi

		echo
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh)  echo "$0: running $f"; . "$f" ;;
				*.sql) echo "$0: running $f"; cat "$f" >> /tmp/init.sql && echo ;;
				*)     echo "$0: ignoring $f" ;;
			esac
			echo
		done

		echo
		echo 'MySQL init process done. Ready for start up.'
		echo
	fi

	chown -R mysql:mysql "$DATADIR"

	/etc/init.d/xinetd start
fi

exec "$@"