-- Cost & Performance Semantic View
-- Focused on query performance, cost analysis, and warehouse optimization
-- This is the "working" semantic view with proven QUERY_HISTORY metrics

USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.TOOLS;

CREATE OR REPLACE SEMANTIC VIEW 
    SNOWFLAKE_INTELLIGENCE.TOOLS.COST_PERFORMANCE_SVW
TABLES (
  SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY,
  SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY
)
FACTS (
  -- ===== QUERY HISTORY FACTS =====
  QUERY_HISTORY.BYTES_READ_FROM_RESULT AS BYTES_READ_FROM_RESULT COMMENT='The total number of bytes read from the query results.',
  QUERY_HISTORY.BYTES_SCANNED AS BYTES_SCANNED COMMENT='The total number of bytes scanned by the query.',
  QUERY_HISTORY.BYTES_SENT_OVER_THE_NETWORK AS BYTES_SENT_OVER_THE_NETWORK COMMENT='The total amount of data transmitted over the network during the execution of a query, measured in bytes.',
  QUERY_HISTORY.BYTES_SPILLED_TO_LOCAL_STORAGE AS BYTES_SPILLED_TO_LOCAL_STORAGE COMMENT='The total amount of data, in bytes, that was spilled to local storage during query execution.',
  QUERY_HISTORY.BYTES_SPILLED_TO_REMOTE_STORAGE AS BYTES_SPILLED_TO_REMOTE_STORAGE COMMENT='The total amount of data (in bytes) that was spilled to remote storage during query execution.',
  QUERY_HISTORY.BYTES_WRITTEN AS BYTES_WRITTEN COMMENT='The total number of bytes written to storage as a result of a query.',
  QUERY_HISTORY.BYTES_WRITTEN_TO_RESULT AS BYTES_WRITTEN_TO_RESULT COMMENT='The total number of bytes written to the result set of a query.',
  QUERY_HISTORY.CHILD_QUERIES_WAIT_TIME AS CHILD_QUERIES_WAIT_TIME COMMENT='The total wait time for child queries in a query execution plan.',
  QUERY_HISTORY.CLUSTER_NUMBER AS CLUSTER_NUMBER COMMENT='The cluster number assigned to a query.',
  QUERY_HISTORY.COMPILATION_TIME AS COMPILATION_TIME COMMENT='The time taken to compile a query, measured in milliseconds.',
  QUERY_HISTORY.CREDITS_USED_CLOUD_SERVICES AS CREDITS_USED_CLOUD_SERVICES COMMENT='The total amount of credits used by cloud services for a query.',
  QUERY_HISTORY.DATABASE_ID AS DATABASE_ID COMMENT='Unique identifier for the database where the query was executed.',
  QUERY_HISTORY.EXECUTION_TIME AS EXECUTION_TIME COMMENT='The time taken to execute a query, measured in seconds.',
  QUERY_HISTORY.EXTERNAL_FUNCTION_TOTAL_INVOCATIONS AS EXTERNAL_FUNCTION_TOTAL_INVOCATIONS COMMENT='Total number of times an external function was invoked during query execution.',
  QUERY_HISTORY.EXTERNAL_FUNCTION_TOTAL_RECEIVED_BYTES AS EXTERNAL_FUNCTION_TOTAL_RECEIVED_BYTES COMMENT='Total number of bytes received by external functions during query execution.',
  QUERY_HISTORY.EXTERNAL_FUNCTION_TOTAL_RECEIVED_ROWS AS EXTERNAL_FUNCTION_TOTAL_RECEIVED_ROWS COMMENT='Total number of rows received by the external function.',
  QUERY_HISTORY.EXTERNAL_FUNCTION_TOTAL_SENT_BYTES AS EXTERNAL_FUNCTION_TOTAL_SENT_BYTES COMMENT='Total number of bytes sent by external functions during query execution.',
  QUERY_HISTORY.EXTERNAL_FUNCTION_TOTAL_SENT_ROWS AS EXTERNAL_FUNCTION_TOTAL_SENT_ROWS COMMENT='Total number of rows sent to external functions for processing.',
  QUERY_HISTORY.INBOUND_DATA_TRANSFER_BYTES AS INBOUND_DATA_TRANSFER_BYTES COMMENT='The total number of bytes transferred into the system from an external source.',
  QUERY_HISTORY.LIST_EXTERNAL_FILES_TIME AS LIST_EXTERNAL_FILES_TIME COMMENT='The time it takes to list external files.',
  QUERY_HISTORY.OUTBOUND_DATA_TRANSFER_BYTES AS OUTBOUND_DATA_TRANSFER_BYTES COMMENT='The total number of bytes transferred out of the system during a query.',
  QUERY_HISTORY.PARTITIONS_SCANNED AS PARTITIONS_SCANNED COMMENT='The number of partitions scanned by the query.',
  QUERY_HISTORY.PARTITIONS_TOTAL AS PARTITIONS_TOTAL COMMENT='Total number of partitions in the system.',
  QUERY_HISTORY.PERCENTAGE_SCANNED_FROM_CACHE AS PERCENTAGE_SCANNED_FROM_CACHE COMMENT='The percentage of data that was retrieved from the cache.',
  QUERY_HISTORY.QUERY_ACCELERATION_BYTES_SCANNED AS QUERY_ACCELERATION_BYTES_SCANNED COMMENT='The total amount of data scanned from the query acceleration cache.',
  QUERY_HISTORY.QUERY_ACCELERATION_PARTITIONS_SCANNED AS QUERY_ACCELERATION_PARTITIONS_SCANNED COMMENT='The number of partitions scanned by the query accelerator.',
  QUERY_HISTORY.QUERY_ACCELERATION_UPPER_LIMIT_SCALE_FACTOR AS QUERY_ACCELERATION_UPPER_LIMIT_SCALE_FACTOR COMMENT='The factor by which the query acceleration upper limit is scaled.',
  QUERY_HISTORY.QUERY_HASH_VERSION AS QUERY_HASH_VERSION COMMENT='A unique identifier for a query version.',
  QUERY_HISTORY.QUERY_LOAD_PERCENT AS QUERY_LOAD_PERCENT COMMENT='The percentage of the system''s load currently being used to process queries.',
  QUERY_HISTORY.QUERY_PARAMETERIZED_HASH_VERSION AS QUERY_PARAMETERIZED_HASH_VERSION COMMENT='A unique identifier for a parameterized query version.',
  QUERY_HISTORY.QUERY_RETRY_TIME AS QUERY_RETRY_TIME COMMENT='The amount of time spent retrying a query due to errors or failures.',
  QUERY_HISTORY.QUEUED_OVERLOAD_TIME AS QUEUED_OVERLOAD_TIME COMMENT='The time spent waiting in the queue due to overload, in milliseconds.',
  QUERY_HISTORY.QUEUED_PROVISIONING_TIME AS QUEUED_PROVISIONING_TIME COMMENT='The time that a query spent in the queue waiting for resources.',
  QUERY_HISTORY.QUEUED_REPAIR_TIME AS QUEUED_REPAIR_TIME COMMENT='The time a repair query spent in the queue before being executed.',
  QUERY_HISTORY.ROWS_DELETED AS ROWS_DELETED COMMENT='The number of rows deleted as a result of a query execution.',
  QUERY_HISTORY.ROWS_INSERTED AS ROWS_INSERTED COMMENT='The total number of rows inserted into a table as a result of a query execution.',
  QUERY_HISTORY.ROWS_PRODUCED AS ROWS_PRODUCED COMMENT='The total number of rows returned by a query.',
  QUERY_HISTORY.ROWS_UNLOADED AS ROWS_UNLOADED COMMENT='The number of rows that were unloaded from a table.',
  QUERY_HISTORY.ROWS_UPDATED AS ROWS_UPDATED COMMENT='The total number of rows updated by a query.',
  QUERY_HISTORY.ROWS_WRITTEN_TO_RESULT AS ROWS_WRITTEN_TO_RESULT COMMENT='The number of rows written to the result set of a query.',
  QUERY_HISTORY.SCHEMA_ID AS SCHEMA_ID COMMENT='Unique identifier for the schema in which the query was executed.',
  QUERY_HISTORY.SESSION_ID AS SESSION_ID COMMENT='Unique identifier for a query session.',
  QUERY_HISTORY.TOTAL_ELAPSED_TIME AS TOTAL_ELAPSED_TIME COMMENT='The total time taken to execute a query, from start to finish, measured in milliseconds.',
  QUERY_HISTORY.TRANSACTION_BLOCKED_TIME AS TRANSACTION_BLOCKED_TIME COMMENT='The time spent waiting for a transaction to be blocked.',
  QUERY_HISTORY.TRANSACTION_ID AS TRANSACTION_ID COMMENT='Unique identifier for a specific database transaction.',
  QUERY_HISTORY.USER_DATABASE_ID AS USER_DATABASE_ID COMMENT='Unique identifier for the database that the query was executed against.',
  QUERY_HISTORY.USER_SCHEMA_ID AS USER_SCHEMA_ID COMMENT='Unique identifier for the schema that the user belongs to.',
  QUERY_HISTORY.WAREHOUSE_ID AS WAREHOUSE_ID COMMENT='Unique identifier for the warehouse associated with the query.',
  
  -- ===== QUERY ATTRIBUTION FACTS =====
  QUERY_ATTRIBUTION_HISTORY.CREDITS_ATTRIBUTED_COMPUTE AS CREDITS_ATTRIBUTED_COMPUTE COMMENT='The percentage of compute resources utilized that are attributed to the user or organization.',
  QUERY_ATTRIBUTION_HISTORY.CREDITS_USED_QUERY_ACCELERATION AS CREDITS_USED_QUERY_ACCELERATION COMMENT='The total amount of credits used for query acceleration.',
  QUERY_ATTRIBUTION_HISTORY.WAREHOUSE_ID AS WAREHOUSE_ID COMMENT='Unique identifier for the warehouse in attribution history.'
)
DIMENSIONS (
  -- ===== QUERY HISTORY DIMENSIONS =====
  QUERY_HISTORY.DATABASE_NAME AS DATABASE_NAME COMMENT='The name of the database where the query was executed.',
  QUERY_HISTORY.END_TIME AS END_TIME COMMENT='The date and time when each query was completed.',
  QUERY_HISTORY.ERROR_CODE AS ERROR_CODE COMMENT='Error codes associated with query execution.',
  QUERY_HISTORY.ERROR_MESSAGE AS ERROR_MESSAGE COMMENT='The error message returned when a query fails to execute.',
  QUERY_HISTORY.EXECUTION_STATUS AS EXECUTION_STATUS COMMENT='The status of a query''s execution.',
  QUERY_HISTORY.INBOUND_DATA_TRANSFER_CLOUD AS INBOUND_DATA_TRANSFER_CLOUD COMMENT='The cloud source of inbound data transfer.',
  QUERY_HISTORY.INBOUND_DATA_TRANSFER_REGION AS INBOUND_DATA_TRANSFER_REGION COMMENT='The region where the data was transferred from.',
  QUERY_HISTORY.IS_CLIENT_GENERATED_STATEMENT AS IS_CLIENT_GENERATED_STATEMENT COMMENT='Indicates whether the query was generated by a client application.',
  QUERY_HISTORY.OUTBOUND_DATA_TRANSFER_CLOUD AS OUTBOUND_DATA_TRANSFER_CLOUD COMMENT='The cloud platform used for outbound data transfers.',
  QUERY_HISTORY.OUTBOUND_DATA_TRANSFER_REGION AS OUTBOUND_DATA_TRANSFER_REGION COMMENT='The region where the data was transferred to.',
  QUERY_HISTORY.QUERY_HASH AS QUERY_HASH COMMENT='Unique identifier for a query.',
  QUERY_HISTORY.QUERY_ID AS QUERY_ID COMMENT='Unique identifier for a query executed in the system.',
  QUERY_HISTORY.QUERY_PARAMETERIZED_HASH AS QUERY_PARAMETERIZED_HASH COMMENT='A unique hash value representing a parameterized query.',
  QUERY_HISTORY.QUERY_RETRY_CAUSE AS QUERY_RETRY_CAUSE COMMENT='The reason why a query was retried.',
  QUERY_HISTORY.QUERY_TAG AS QUERY_TAG COMMENT='A tag used to identify and categorize queries.',
  QUERY_HISTORY.QUERY_TEXT AS QUERY_TEXT COMMENT='The text of the query executed by the user.',
  QUERY_HISTORY.QUERY_TYPE AS QUERY_TYPE COMMENT='The type of query executed.',
  QUERY_HISTORY.RELEASE_VERSION AS RELEASE_VERSION COMMENT='The version of the software release that executed the query.',
  QUERY_HISTORY.ROLE_NAME AS ROLE_NAME COMMENT='The role of the user who executed the query.',
  QUERY_HISTORY.ROLE_TYPE AS ROLE_TYPE COMMENT='The type of role that executed the query.',
  QUERY_HISTORY.SCHEMA_NAME AS SCHEMA_NAME COMMENT='The name of the database schema where the query was executed.',
  QUERY_HISTORY.SECONDARY_ROLE_STATS AS SECONDARY_ROLE_STATS COMMENT='Secondary role statistics for a query.',
  QUERY_HISTORY.START_TIME AS START_TIME COMMENT='The date and time when each query was initiated.',
  QUERY_HISTORY.USER_DATABASE_NAME AS USER_DATABASE_NAME COMMENT='The name of the database that the user was connected to.',
  QUERY_HISTORY.USER_NAME AS USER_NAME COMMENT='The user who executed the query.',
  QUERY_HISTORY.USER_SCHEMA_NAME AS USER_SCHEMA_NAME COMMENT='The name of the schema that the user belongs to.',
  QUERY_HISTORY.USER_TYPE AS USER_TYPE COMMENT='The type of user who executed the query.',
  QUERY_HISTORY.WAREHOUSE_NAME AS WAREHOUSE_NAME COMMENT='The name of the warehouse where the query was executed.',
  QUERY_HISTORY.WAREHOUSE_SIZE AS WAREHOUSE_SIZE COMMENT='The size of the warehouse.',
  QUERY_HISTORY.WAREHOUSE_TYPE AS WAREHOUSE_TYPE COMMENT='The type of warehouse used to execute the query.',
  
  -- ===== QUERY ATTRIBUTION DIMENSIONS =====
  QUERY_ATTRIBUTION_HISTORY.END_TIME AS END_TIME COMMENT='The date and time when the attribution event ended.',
  QUERY_ATTRIBUTION_HISTORY.PARENT_QUERY_ID AS PARENT_QUERY_ID COMMENT='Unique identifier of the parent query.',
  QUERY_ATTRIBUTION_HISTORY.QUERY_HASH AS QUERY_HASH COMMENT='Unique identifier for a query in attribution history.',
  QUERY_ATTRIBUTION_HISTORY.QUERY_ID AS QUERY_ID COMMENT='Unique identifier for a query in attribution history.',
  QUERY_ATTRIBUTION_HISTORY.QUERY_PARAMETERIZED_HASH AS QUERY_PARAMETERIZED_HASH COMMENT='A unique identifier for a parameterized query in attribution history.',
  QUERY_ATTRIBUTION_HISTORY.QUERY_TAG AS QUERY_TAG COMMENT='Metadata tags associated with a query in attribution history.',
  QUERY_ATTRIBUTION_HISTORY.ROOT_QUERY_ID AS ROOT_QUERY_ID COMMENT='Unique identifier for the root query.',
  QUERY_ATTRIBUTION_HISTORY.START_TIME AS START_TIME COMMENT='The timestamp when the attribution event started.',
  QUERY_ATTRIBUTION_HISTORY.USER_NAME AS USER_NAME COMMENT='The user in attribution history.',
  QUERY_ATTRIBUTION_HISTORY.WAREHOUSE_NAME AS WAREHOUSE_NAME COMMENT='The warehouse name in attribution history.'
)
COMMENT='Cost and performance semantic view for query optimization and cost analysis. Built on QUERY_HISTORY and QUERY_ATTRIBUTION_HISTORY.'
WITH EXTENSION (CA='{"tables":[
  {"name":"QUERY_HISTORY","description":"Query execution history with 50+ performance metrics and cost data"},
  {"name":"QUERY_ATTRIBUTION_HISTORY","description":"Query credit attribution and warehouse cost tracking"}
],"verified_queries":[
  {
    "name":"Expensive Queries Last Hour",
    "question":"What were the most expensive queries in the last hour?",
    "sql":"SELECT query_id, query_text, user_name, warehouse_name, total_elapsed_time, credits_used_cloud_services FROM query_history WHERE start_time >= DATEADD(hour, -1, CURRENT_TIMESTAMP()) ORDER BY credits_used_cloud_services DESC LIMIT 10"
  },
  {
    "name":"Failed Query Analysis",
    "question":"Show me failed queries with error details",
    "sql":"SELECT query_id, user_name, error_code, error_message, query_text FROM query_history WHERE execution_status = ''FAIL'' AND start_time >= DATEADD(day, -1, CURRENT_TIMESTAMP()) ORDER BY start_time DESC"
  },
  {
    "name":"Query Performance by User",
    "question":"Which users are running the slowest queries?",
    "sql":"SELECT user_name, COUNT(*) as query_count, AVG(total_elapsed_time) as avg_time, MAX(total_elapsed_time) as max_time FROM query_history WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP()) GROUP BY user_name ORDER BY avg_time DESC LIMIT 10"
  },
  {
    "name":"Queries Spilling to Disk",
    "question":"Show me queries that spilled to local or remote storage",
    "sql":"SELECT query_id, user_name, warehouse_name, bytes_spilled_to_local_storage, bytes_spilled_to_remote_storage, total_elapsed_time FROM query_history WHERE (bytes_spilled_to_local_storage > 0 OR bytes_spilled_to_remote_storage > 0) AND start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP()) ORDER BY bytes_spilled_to_remote_storage DESC LIMIT 20"
  },
  {
    "name":"Warehouse Cost Analysis",
    "question":"Which warehouses are consuming the most credits?",
    "sql":"SELECT warehouse_name, COUNT(*) as query_count, SUM(credits_attributed_compute) as total_credits FROM query_attribution_history WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP()) GROUP BY warehouse_name ORDER BY total_credits DESC"
  }
]}');

GRANT SELECT ON VIEW SNOWFLAKE_INTELLIGENCE.TOOLS.COST_PERFORMANCE_SVW TO ROLE PUBLIC;

