#!/bin/bash
# $1 engine

iterations=${iterations:-3}
threads="$(seq $(($(nproc)*2)))"
scripts="read_only write_only read_write insert delete update_index"

host=$(jq .host .mysql.json | sed 's/"//g')
port=$(jq .port .mysql.json | sed 's/"//g')
user=$(jq .user .mysql.json | sed 's/"//g')
password=$(jq .password .mysql.json | sed 's/"//g')
database=$(jq .database .mysql.json | sed 's/"//g')
echo "Connect to: ${user}:${password}@${host}:${port}/${database}"

datastore_type_id=$(cat .datastore_type_id)

run_sysbench () {
    echo "Clean"
    sysbench \
        lua/oltp_$script.lua cleanup \
        --db-driver="$1" \
        --mysql-host="$host" \
        --mysql-port="${port:-3306}" \
        --mysql-user="$user" \
        --mysql-password="$password" \
        --mysql-db=$database
    echo "Prepare"
    sysbench \
        lua/oltp_$script.lua prepare \
        --db-driver="$1" \
        --mysql-host="$host" \
        --mysql-port="${port:-3306}" \
        --mysql-user="$user" \
        --mysql-password="$password" \
        --mysql-db=$database
    echo "Run"
    sysbench \
        lua/oltp_$script.lua run \
        --db-driver="$1" \
        --mysql-host="$host" \
        --mysql-port="${port:-3306}" \
        --mysql-user="$user" \
        --mysql-password="$password" \
        --mysql-db="$database" \
        --threads="$thread" \
        --time=60 \
        > $script-$thread-$1.txt
    cb-client sysbench_oltp --script $script --datastore-type $datastore_type_id
}

for i in $(seq 1 $iterations) ; do
    for script in $scripts ; do
        for thread in $threads ; do
            echo -e "Run $script ${thread} thread(s) #$i"
            run_sysbench $1
        done
    done
done
