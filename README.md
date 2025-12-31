# Real-Time ETL Pipeline (Starter Project)

## Services
- PostgreSQL (CDC source)
- Kafka + Zookeeper + Debezium Connect
- ClickHouse
- MinIO (S3-compatible storage)
- Flink (stream processing)
- Airflow (batch orchestration)

## Quickstart
```bash
docker compose up -d
```

1. Connect Debezium: 
```bash
curl -X POST -H "Content-Type: application/json"   --data @kafka-debezium/connectors/postgres-connector.json   http://localhost:8083/connectors
```

2. Insert into Postgres:
```bash
psql -h localhost -U postgres -d demo -c "INSERT INTO customers(name) VALUES('Charlie');"
```

3. Consume from Kafka:
```bash
docker exec -it realtime-pipeline-kafka-1 kafka-console-consumer --bootstrap-server kafka:9092 --topic dbserver1.public.customers --from-beginning
```
