---
name: analyze-logs-and-plan-fix
description: Analyze CloudWatch alarm errors, investigate logs, find root cause in codebase, and plan fixes
user_invocable: true
---

# Analyze CloudWatch Logs and Plan Fix

You are given a CloudWatch alarm notification. Your job is to investigate the error, find the root cause in the codebase, and either plan a fix or inform the user if it's an infrastructure/edge-case issue.

## Input

The user provides a CloudWatch alarm message containing some or all of:

- **Namespace** (e.g. `lambdaProcessError`)
- **Metric** (e.g. `rocr-es-bulk-consumer`) — this is the Lambda function name
- **Timestamp** (e.g. `Tue, 24 Mar 2026 06:08:15 UTC`)
- **Alarm Description**
- **Alarm State**
- **Metric Alarm Name**

## Step 1: Parse the alarm

Extract:

- `function_name`: the Lambda function name from the Metric field
- `alarm_time`: the timestamp (convert to ISO 8601 UTC)
- `log_group`: construct as `/aws/lambda/{function_name}`

## Step 2: Fetch error logs from CloudWatch

Use the `cw-mcp-server` MCP tools. Region is `ap-northeast-1`.

1. **Verify the log group exists** using `list_log_groups` with the function name as prefix.

2. **Search for errors** around the alarm timestamp. Create a time window of -10min to +5min around the alarm time:

   ```
   search_logs:
     log_group_name: /aws/lambda/{function_name}
     query: "fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 30"
     start_time: {alarm_time - 10min}
     end_time: {alarm_time + 5min}
   ```

3. **Get full error details** — the ERROR log lines are often truncated. Use `filter_log_events` with filter pattern `"BulkIndexError"` or the specific exception class name to get full stack traces. Also try filtering by request IDs found in step 2.

4. **Find error patterns** using `find_error_patterns` for the same time window to get a statistical overview.

Present the error logs to the user in a readable format before proceeding.

## Step 3: Analyze the codebase

Map the Lambda function name to its handler in the codebase:

| Function pattern        | Handler location                         |
| ----------------------- | ---------------------------------------- |
| `rocr-api-*`            | `backend/cmd/api/app.py`                 |
| `rocr-batch-*`          | `backend/cmd/batch/*/app.py`             |
| `rocr-es-bulk-consumer` | `backend/cmd/stream/es_bulk_task/app.py` |
| `rocr-s3trigger-*`      | `backend/cmd/s3trigger/app.py`           |
| `rocr-*-cognito-*`      | `backend/cmd/cognito/*/app.py`           |
| `rocr-*-job-*`          | `backend/cmd/job/*/app.py`               |

Read the handler code and trace the error path. Follow imports into `backend/mypackages/` to understand the full call chain.

## Step 4: Classify and respond

### If it's a **code bug** (logic error, unhandled exception, wrong API usage):

1. Identify the exact file and line causing the issue
2. Explain the root cause clearly
3. Enter plan mode and propose a fix with:
   - What to change
   - Why the fix is correct
   - What edge cases to consider
   - Whether tests need updating
