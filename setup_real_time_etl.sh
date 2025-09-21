#!/bin/bash
# setup_real_time_etl.sh
# This script sets up PostgreSQL, Kafka, Debezium, and creates tables with CDC.

# -----------------------------
# 1. Start Docker containers
# -----------------------------
echo "Starting Docker containers..."
docker compose up -d

# Wait a few seconds for containers to be ready
echo "Waiting for services to start..."
sleep 15

# -----------------------------
# 2. PostgreSQL setup
# -----------------------------
echo "Creating PostgreSQL tables..."
docker exec -i real_time_etl-postgres-1 psql -U postgres -d demo <<EOF
-- Create customers table
CREATE TABLE IF NOT EXISTS customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(150),
    created_at TIMESTAMP DEFAULT now()
);

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(id),
    total DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT now()
);

-- Insert initial data
INSERT INTO customers (name, email) VALUES
('Alice', 'alice@example.com'),
('Bob', 'bob@example.com');

INSERT INTO orders (customer_id, total) VALUES
(1, 199.99),
(2, 59.49);

-- Configure logical replication
ALTER SYSTEM SET wal_level = 'logical';
ALTER SYSTEM SET max_replication_slots = 5;
ALTER SYSTEM SET max_wal_senders = 5;

-- Create publication for Debezium
DO
\$do\$
BEGIN
   IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'dbserver1_pub') THEN
       CREATE PUBLICATION dbserver1_pub FOR TABLE customers, orders;
   END IF;
END
\$do\$;
EOF

echo "PostgreSQL tables and publication created."

# -----------------------------
# 3. Debezium connector setup
# -----------------------------
echo "Setting up Debezium Postgres connector..."

# Wait for Kafka Connect to be ready
sleep 10

# Register connector
curl -X POST -H "Content-Type: application/json" \
  --data @postgres-connector.json \
  http://localhost:8083/connectors || echo "Connector setup may have failed. Check Kafka Connect logs."

echo "Setup script completed. Check Kafka topic dbserver1.public.customers to verify CDC."

# -----------------------------
# 4. Consume CDC events from Kafka
# -----------------------------
echo "Streaming CDC events from Kafka topic dbserver1.public.customers..."
docker exec -it real_time_etl-kafka-1 kafka-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic dbserver1.public.customers \
  --from-beginning
