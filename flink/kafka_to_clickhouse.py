from pyflink.datastream import StreamExecutionEnvironment
from pyflink.datastream.connectors import KafkaSource, KafkaOffsetsInitializer
from pyflink.common.typeinfo import Types
from pyflink.common.serialization import SimpleStringSchema
import json
import clickhouse_connect

# -----------------------------
# 1. ClickHouse connection setup
# -----------------------------
ch_client = clickhouse_connect.Client(
    host='localhost',  # or 'real_time_etl-clickhouse-1'
    port=8123,
    username='default',
    password=''
)
CLICKHOUSE_DB = 'demo'
CLICKHOUSE_TABLE = 'customers'

# -----------------------------
# 2. Transform Kafka JSON -> ClickHouse Row
# -----------------------------
def parse_kafka_record(record_str):
    record = json.loads(record_str)
    after = record.get('after')
    if after:
        return {
            'id': after['id'],
            'name': after.get('name', ''),
            'email': after.get('email', ''),
            'created_at': after.get('created_at', None)
        }
    return None

def insert_into_clickhouse(record):
    if record:
        # Map keys to ClickHouse columns
        query = f"""
            INSERT INTO {CLICKHOUSE_DB}.{CLICKHOUSE_TABLE} (id, name, email, created_at)
            VALUES
        """
        values = f"({record['id']}, '{record['name']}', '{record['email']}', toDateTime({int(record['created_at']/1000000)}))"
        ch_client.command(query + values)

# -----------------------------
# 3. Flink environment
# -----------------------------
env = StreamExecutionEnvironment.get_execution_environment()
env.set_parallelism(1)

# Kafka source
kafka_source = KafkaSource.builder() \
    .set_bootstrap_servers("localhost:29092") \
    .set_topics("dbserver1.public.customers") \
    .set_group_id("flink-cdc") \
    .set_starting_offsets(KafkaOffsetsInitializer.earliest()) \
    .set_value_only_deserializer(SimpleStringSchema()) \
    .build()

ds = env.from_source(
    source=kafka_source,
    watermark_strategy=None,
    source_name="Kafka CDC Source"
)

# -----------------------------
# 4. Process stream
# -----------------------------
ds.map(lambda x: parse_kafka_record(x), output_type=Types.PICKLED_BYTE_ARRAY()) \
  .filter(lambda x: x is not None) \
  .map(lambda x: insert_into_clickhouse(x))

# -----------------------------
# 5. Execute
# -----------------------------
env.execute("Kafka CDC → ClickHouse ETL")
