#!/usr/bin/env bash
# Starts the devdb postgresql local server
set -e
set -x

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
dbdir="/tmp/devdb"

if [[ -z $PGDATABASE ]]; then
    echo "PGDATABASE is required with the database name"
    exit 1
fi

if [[ -z $PGPORT ]]; then
    echo "PGPORT is required with the database port"
    exit 1
fi

if [[ -z $(find "$dbdir" -maxdepth 0 -empty) ]]; then
    echo "Directory is not empty, skipping db initalization."
else
    echo "Initializing db"
    pg_ctl init -D "$dbdir"
fi

if [[ ! -d "/run/postgresql" ]]; then
    sudo mkdir /run/postgresql
    sudo chmod o+rwx /run/postgresql
fi

pg_ctl start -D "$dbdir" -l "$dbdir/server_log.log" -o "-p $PGPORT"

if psql -lqt | cut -d \| -f 1 | grep -qw $PGDATABASE; then
    echo "Database exists"
else
    echo "Database does not exist. Creating."
    createdb $PGDATABASE

    # Create default user and password
    echo "create user test with password 'test'" | psql
    echo "alter user test with superuser" | psql
    echo "grant all privileges on schema public to test" | psql
fi


echo "Server log is at $dbdir/server_log.log"

