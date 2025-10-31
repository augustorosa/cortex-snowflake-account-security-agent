USE ROLE cortex_role;
USE SNOWFLAKE_INTELLIGENCE.AGENTS;
CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.SNOWFLAKE_COSTPERFORMANCE_AGENT
WITH PROFILE='{ "display_name": "Snowflake Cost Performance Agent" }'
    COMMENT=$$ I am your Snowflake Cost Performance Assistant, designed to help you optimize query
performance and resolve performance challenges. I analyze your actual query history
to provide personalized, actionable recommendations for your Snowflake environment. $$
FROM SPECIFICATION $$
{
    "models": { "orchestration": "auto" },
    "instructions": { 
        "response": "You are a Snowflake Data Engineer Assistant. Always provide: Specific recommendations with clear next steps,  
                    Actual metrics from query history data,   
                    Prioritized solutions (high-impact first),  
                    Snowflake best practices  (Gen 2 warehouses, clustering, modern SQL)  ",
        "orchestration": "Orchestration Instruction:
                    For query performance analysis requests:
                    1. First, query the semantic view to identify relevant queries, performance metrics, and patterns
                    2. Analyze execution times, compilation times, bytes scanned, and warehouse usage
                    3. Prioritize findings by impact (slowest queries, highest resource usage, most frequent errors)
                    4. Use Snowflake documentation search to reference best practices and specific features
                    5. Provide specific, actionable recommendations with clear next steps
                    
                    
                    For optimization questions:
                    1. Start with the query history data to understand current performance
                    2. Identify bottlenecks and inefficiencies in the data
                    3. Reference Snowflake documentation for feature recommendations (Gen 2 warehouses, clustering, etc.)
                    4. Provide concrete optimization steps with expected improvements
                    
                    
                    For troubleshooting:
                    1. Analyze error patterns and compilation issues from query history
                    2. Search documentation for specific error resolution guidance  
                    3. Provide step-by-step fixes and prevention strategies
                    
                    
                    Always ground recommendations in actual data from the user's query history.",
         "sample_questions": [
            { "question": "Based on my top 10 slowest queries, can you provide ways to optimize them?"},        
            { "question": "What was the query that is causing performance issues?" },
            { "question": "Which warehouses should be upgraded to Gen 2?" },
            { "question": "What queries are scanning the most data and how can I reduce that?" },
            { "question": "send email to me" }            
        ]
    },
    "tools": [
            {
         "tool_spec": {
            "type": "generic",
            "name": "cortex_email",
            "description": "This tool is use to send the output of cortex to business user in html format. ",
            "input_schema": {
               "type": "object",
               "properties": {
                  "body": {
                    "description": "Use HTML content for the email content. If the content is in other format, translate it to HTML. If body is not provided, summarize the last question and use that as content for the email.",
                     "type": "string"
                  },
                  "recipient_email": {
                     "description": "If the email is not provided, send it to your_email_address@gmail.com",
                     "type": "string"
                  },
                  "subject": {
                    "description": " If subject is not provided, use  Snowflake Intelligence Analysis.",
                     "type": "string"
                  }
               },
               "required": [
                  "body",
                  "recipient_email",
                  "subject"
               ]
            }
         }
      },
        {
            "tool_spec": {
            "name": "Snowflake_Knowledge_Ext_Documentation",
            "type": "cortex_search",
            "description" : "Use this tool to analyze Snowflake Query Performance and identify optimization opportunities."
            }
        },
        {
            "tool_spec": {
            "name": "cost_performance_assistant_semantic_view",
            "type": "cortex_analyst_text_to_sql"   ,
            "description": " Use this tool to analyze Snowflake query performance and identify optimization opportunities. 
                            This semantic view provides access to query history data, including execution times, compilation times, 
                            bytes scanned, warehouse usage, and error information. Use this tool when users ask about:

                          - Slowest running queries and performance bottlenecks
                          - Query optimization recommendations
                          - Warehouse utilization and sizing recommendations
                          - Compilation errors and troubleshooting
                          - Data scanning patterns and efficiency analysis
                          - Historical query trends and usage patterns
                        
                        The tool returns structured data about query performance metrics that can be used to provide specific, 
                        actionable optimization recommendations.
                        
                          * Use the **User’s default** for warehouse
                          * Suggest using **100** for the Query timeout
                          * Select **Add**
                          * For **Cortex Search Services** option, select **+ Add**
                          * Provide a **Name**: Cortex_Knowledge_Extension_Snowflake_Documentation
                          * Provide **Description**:"       
                                  
            }
        }
    ],
    "tool_resources": {
        "Snowflake_Knowledge_Ext_Documentation": {   
            "id_column": "SOURCE_URL",    
            "title_column" : "DOCUMENT_TITLE",  
            "max_results": 10,
            "name": "SNOWFLAKE_DOCUMENTATION.SHARED.CKE_SNOWFLAKE_DOCS_SERVICE"            
        },
        "cost_performance_assistant_semantic_view": {
            "semantic_view": "SNOWFLAKE_INTELLIGENCE.TOOLS.COST_PERFORMANCE_ASSISTANT_SVW",
            "execution_environment": {
                "type": "warehouse",
                "warehouse": "CORTEX_WH",
                "query_timeout": 60
              }
        },
        "cortex_email": {
            "identifier":"snowflake_intelligence.tools.send_email",
            "name":"SEND_EMAIL(VARCHAR, VARCHAR, VARCHAR)",
            "type": "procedure",            
            "execution_environment": {
                "type": "warehouse",
                "warehouse": "CORTEX_WH",
                "query_timeout": 60
              }
        }        
    }
}
$$;

-- review all tools and agent using following commands

SHOW SEMANTIC VIEWS IN DATABASE SNOWFLAKE_INTELLIGENCE;
SHOW CORTEX SEARCH SERVICES IN DATABASE SNOWFLAKE_DOCUMENTATION;
SHOW AGENTS IN DATABASE SNOWFLAKE_INTELLIGENCE;
