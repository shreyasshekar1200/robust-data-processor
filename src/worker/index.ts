import { DynamoDBClient, PutItemCommand } from "@aws-sdk/client-dynamodb";
import { SQSHandler } from "aws-lambda";
// DO NOT IMPORT UUID HERE

const dynamo = new DynamoDBClient({});
const TABLE_NAME = process.env.TABLE_NAME || "ProcessedLogs";

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

export const handler: SQSHandler = async (event) => {
  for (const record of event.Records) {
    try {
      const body = JSON.parse(record.body);
      const { tenant_id, log_id, text, source } = body;

      console.log(`Processing log ${log_id} for tenant ${tenant_id}`);

      // Sleep 0.05s per character (capped at 10s)
      const sleepTime = Math.min(text.length * 50, 10000);
      await sleep(sleepTime);

      const modifiedData = text.replace(/\d{3}-\d{4}/g, "[REDACTED]");

      await dynamo.send(
        new PutItemCommand({
          TableName: TABLE_NAME,
          Item: {
            tenant_id: { S: tenant_id },
            log_id: { S: log_id },
            source: { S: source },
            original_text: { S: text },
            modified_data: { S: modifiedData },
            processed_at: { S: new Date().toISOString() },
            processing_time_ms: { N: sleepTime.toString() },
          },
        }),
      );
      console.log(`Successfully processed ${log_id}`);
    } catch (error) {
      console.error("Worker Error:", error);
      throw error;
    }
  }
};
