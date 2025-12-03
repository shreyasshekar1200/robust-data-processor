import { SQSClient, SendMessageCommand } from "@aws-sdk/client-sqs";
import { APIGatewayProxyHandler } from "aws-lambda";
import { randomUUID } from "crypto";

// Initialize SQS Client
// Region is picked up from environment variables provided by Lambda
const sqs = new SQSClient({});

// The queue URL you generated in Terraform
// We will pass this as an environment variable later in Terraform
const QUEUE_URL = process.env.QUEUE_URL;

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    // 1. Basic Validation
    if (!QUEUE_URL) {
      throw new Error("QUEUE_URL environment variable is missing");
    }

    const contentType =
      event.headers["content-type"] || event.headers["Content-Type"] || "";
    let tenantId = "";
    let logId = "";
    let textContent = "";
    let source = "";

    // 2. Normalization Logic (JSON vs Text)
    if (contentType.includes("application/json")) {
      // SCENARIO 1: Structured JSON
      const body = JSON.parse(event.body || "{}");
      tenantId = body.tenant_id;
      logId = body.log_id || randomUUID(); // Generate ID if missing
      textContent = body.text;
      source = "json_upload";
    } else if (contentType.includes("text/plain")) {
      // SCENARIO 2: Unstructured Text
      // Tenant ID must come from headers
      tenantId =
        event.headers["x-tenant-id"] || event.headers["X-Tenant-ID"] || "";
      logId = randomUUID(); // Generate a random ID for raw text files
      textContent = event.body || "";
      source = "text_upload";
    } else {
      return { statusCode: 400, body: "Unsupported Content-Type" };
    }

    // 3. Validation
    if (!tenantId || !textContent) {
      return { statusCode: 400, body: "Missing tenant_id or text content" };
    }

    // 4. Send to SQS (The "Buffer")
    const messageBody = {
      tenant_id: tenantId,
      log_id: logId,
      text: textContent,
      source: source,
      ingested_at: new Date().toISOString(),
    };

    await sqs.send(
      new SendMessageCommand({
        QueueUrl: QUEUE_URL,
        MessageBody: JSON.stringify(messageBody),
      }),
    );

    // 5. Return Success (202 Accepted)
    // Non-blocking response: We accepted the work, but haven't finished it yet.
    return {
      statusCode: 202,
      body: JSON.stringify({ message: "Accepted", log_id: logId }),
    };
  } catch (error) {
    console.error("API Error:", error);
    return { statusCode: 500, body: "Internal Server Error" };
  }
};
