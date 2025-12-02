# Robust Data Processor

A scalable, multi-tenant backend system designed to ingest high-throughput logging streams, process them asynchronously, and store them securely with strict tenant isolation. Built on AWS Serverless architecture using Terraform.

## 🚀 Overview

This project implements a "Unified Ingestion Gateway" capable of handling chaotic data streams. It normalizes JSON and Raw Text inputs into a unified format, processes them using a simulated CPU-bound worker, and persists them to a NoSQL database.

**Key Features:**
* [cite_start]**High Throughput:** Handles 1,000+ RPM via non-blocking Async I/O[cite: 24].
* [cite_start]**Multi-Tenancy:** Strict data isolation between tenants (e.g., `acme` vs `beta_inc`)[cite: 42].
* [cite_start]**Resilience:** Decoupled architecture using Message Queues to survive worker crashes[cite: 14].
* [cite_start]**Infrastructure as Code:** Fully deployed via Terraform.

## 🏗 Architecture

**Data Flow:**
[cite_start]`[Source: JSON/TXT]` -> `(API Gateway + Lambda)` -> `[SQS Queue]` -> `(Worker Lambda)` -> `[DynamoDB]` [cite: 20]

1.  **Ingestion API (Component A):** A public `POST /ingest` endpoint that accepts `application/json` or `text/plain`. It normalizes data and pushes it to SQS.
2.  **Message Broker:** AWS SQS (Simple Queue Service) acts as the buffer to handle traffic spikes.
3.  **Worker (Component B):** A Lambda function triggered by SQS. [cite_start]It simulates heavy processing (0.05s sleep per character)[cite: 39].
4.  [cite_start]**Storage (Component C):** AWS DynamoDB with a partition key strategy ensuring tenant isolation (`tenants/{tenant_id}/processed_logs/...`)[cite: 44].

[cite_start]*(See `docs/diagrams/architecture.png` for the visual workflow)* [cite: 83]

## 🛠 Tech Stack

* **Cloud Provider:** AWS (Free Tier)
* **Compute:** AWS Lambda (Node.js/TypeScript)
* **Queue:** AWS SQS
* **Database:** Amazon DynamoDB
* **IaC:** Terraform

## 🔌 API Reference

### POST /ingest

[cite_start]**Endpoint:** `<YOUR_API_GATEWAY_URL>/ingest` [cite: 23]

#### [cite_start]Scenario 1: Structured JSON [cite: 26]
* **Headers:** `Content-Type: application/json`
* **Payload:**
    ```json
    {
      "tenant_id": "acme",
      "log_id": "123",
      "text": "User 555-0199..."
    }
    ```

#### [cite_start]Scenario 2: Unstructured Text [cite: 30]
* **Headers:**
    * `Content-Type: text/plain`
    * [cite_start]`X-Tenant-ID: acme` [cite: 32]
* **Payload:** Raw text string (e.g., log file dump).

## 💥 Chaos & Recovery Strategy

[cite_start]**Requirement:** The system must recover gracefully if the worker crashes mid-process[cite: 14].

**Implementation:**
* **Dead Letter Queues (DLQ):** If the Worker fails to process a message (simulated crash), the message is returned to the queue. After max retries, it is moved to a DLQ for inspection.
* **Stateless Compute:** The Worker is stateless; crashing one instance does not affect the queue or other processing streams.

## 📦 Deployment (Terraform)

Prerequisites: AWS CLI configured, Terraform installed.

1.  **Initialize Terraform:**
    ```bash
    cd terraform
    terraform init
    ```
2.  **Deploy Resources:**
    ```bash
    terraform apply
    ```
3.  **Output:** Terraform will output the `api_gateway_url` which serves as the entry point.

## 🎥 Deliverables

* [cite_start]**Live URL:** [Insert URL here] [cite: 74]
* [cite_start]**Video Walkthrough:** [Insert Link to Video] [cite: 75]
    * Walkthrough of AWS Console (SQS/DynamoDB).
    * Demonstration of API requests and DB ingestion.
    * Explanation of Multi-Tenant architecture.
