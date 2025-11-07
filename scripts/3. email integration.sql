CREATE OR REPLACE NOTIFICATION INTEGRATION email_integration
  TYPE=EMAIL
  ENABLED=TRUE
  DEFAULT_SUBJECT = 'snowflake intelligence'
;

CREATE OR REPLACE PROCEDURE SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_EMAIL(
    recipient_email VARCHAR,
    subject VARCHAR,
    body VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.12'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'send_email'
AS
$$
def send_email(session, recipient_email, subject, body):
    try:
        # Properly escape single quotes in all user-provided parameters to prevent SQL injection
        escaped_recipient = recipient_email.replace("'", "''")
        escaped_subject = subject.replace("'", "''")
        escaped_body = body.replace("'", "''")
        
        # Execute the system procedure call with properly escaped parameters
        session.sql(f"""
            CALL SYSTEM$SEND_EMAIL(
                'email_integration',
                '{escaped_recipient}',
                '{escaped_subject}',
                '{escaped_body}',
                'text/html'
            )
        """).collect()
        
        return "Email sent successfully"
    except Exception as e:
        return f"Error sending email: {str(e)}"
$$;

CALL SNOWFLAKE_INTELLIGENCE.TOOLS.SEND_EMAIL(
  'your_email_address',
  'Cortex Email',
  'This is testing of email from Snowflake');