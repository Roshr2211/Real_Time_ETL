#!/bin/bash
# resilient_host_cdc_to_clickhouse.sh
# Continuous, idempotent CDC ingestion from Kafka to ClickHouse

KAFKA_BROKER="kafka:9092"      # Use kafka:9092 inside container
KAFKA_TOPIC="dbserver1.public.customers"
CLICKHOUSE_CONTAINER="real_time_etl-clickhouse-1"
CLICKHOUSE_DB="demo"
CLICKHOUSE_TABLE="customers"

# Check jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed."
    exit 1
fi

echo "Starting resilient, idempotent CDC ingestion..."

while true; do
    echo "Starting Kafka consumer..."
    docker exec -i real_time_etl-kafka-1 kafka-console-consumer \
        --bootstrap-server $KAFKA_BROKER \
        --topic $KAFKA_TOPIC \
        --from-beginning \
        --timeout-ms 5000 \
    | jq -c '.after' \
    | while read record; do
        if [ "$record" != "null" ]; then
            # Extract fields from Kafka JSON
            id=$(echo $record | jq '.id')
            name=$(echo $record | jq -r '.name')
            email=$(echo $record | jq -r '.email // ""')
            created_at_epoch=$(echo $record | jq '.created_at')
            created_at=$(date -d @"$((created_at_epoch/1000000))" +"%Y-%m-%d %H:%M:%S")  # convert microseconds
            version=$(echo $record | jq '.id')  # You can also use LSN from Kafka source

            # Insert into ClickHouse
            docker exec -i $CLICKHOUSE_CONTAINER clickhouse-client --query="
                INSERT INTO $CLICKHOUSE_DB.$CLICKHOUSE_TABLE
                (id, name, email, created_at, version)
                FORMAT CSV
            " <<< "$id,$name,$email,$created_at,$version"

            echo "Inserted/Updated record: id=$id, name=$name"
        fi
    done

    echo "Kafka consumer stopped. Retrying in 5 seconds..."
    sleep 5
done
