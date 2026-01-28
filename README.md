# Serverless Image Processing Pipeline (Terraform + AWS)
## Overview
- This project implements a multi-stage, event-driven serverless image processing pipeline using Infrastructure as Code (Terraform) and serverless cloud services.
- Although the original assignment specification referenced Google Cloud Platform (GCP), the instructor granted permission to implement the same architecture using Amazon Web Services (AWS). All architectural goals, security principles, and functional requirements are fully satisfied using AWS equivalents.
- The system allows users to upload images through a secured API Gateway endpoint. The images are processed asynchronously through a decoupled event-driven workflow, converted to grayscale, and stored in a processed bucket. Completion is logged automatically.

## Architecture
High-Level Flow
- Client uploads an image via API Gateway
- Upload Lambda stores the image in S3 and sends an SQS message
- Processing Lambda consumes the message, processes the image, and stores the result
- Notification Lambda logs the processing completion

## AWS Service Mapping (GCP → AWS)
GCP Service	AWS Equivalent
Cloud Functions	AWS Lambda
Cloud Storage (GCS)	Amazon S3
Pub/Sub	Amazon SQS
API Gateway	Amazon API Gateway
IAM Service Account	IAM Role
Secret Manager	API Gateway API Key
Cloud Logging	CloudWatch Logs

## Components
### API Gateway
- Endpoint:
```
POST /prod/v1/images/upload
```
- Security:
  - API Key required
  - Usage plan enforced
- Purpose:
  - Front door to the system
  - Routes requests to the upload Lambda

### Upload Lambda (upload_image)
Trigger: API Gateway (HTTP)
Responsibilities:
- Accepts raw image uploads
- Generates a unique image ID
- Uploads image to S3 uploads bucket
- Sends a message to SQS for processing
- Returns 202 Accepted
Output Example:
```
{
  "message": "Image accepted for processing",
  "image_id": "a932d706-5895-43df-ba24-19084099dad3"
}
```
### Processing Lambda (process_image)
Trigger: SQS (image-processing-requests)
Responsibilities:
- Downloads image from uploads bucket
- Converts image to grayscale using Pillow
- Uploads processed image to processed bucket
- Sends completion message to results queue
Key Notes:
- Uses Lambda Layer for Pillow (not bundled in repo)
- Idempotent design (safe reprocessing)

### Notification Lambda (log_notification)
Trigger: SQS (image-processing-results)
Responsibilities:
- Logs structured JSON messages to CloudWatch
- Confirms successful processing

## Storage (Amazon S3)
Uploads Bucket
- Stores original uploaded images
- Lifecycle rule deletes objects older than 7 days
Processed Bucket
- Stores grayscale images
- No automatic deletion (audit-safe)

## Security & IAM
- Dedicated IAM Role for all Lambda functions
- Least privilege permissions:
  - S3 read/write
  - SQS send/receive
  - CloudWatch logging
- API Key required for all uploads
- No credentials or secrets hardcoded

## Infrastructure as Code (Terraform)
All cloud resources are defined and managed using Terraform.
Managed Resources
- API Gateway
- Lambda functions
- Lambda Layer (Pillow)
- S3 buckets + lifecycle policy
- SQS queues
- IAM roles and policies
- API Gateway usage plan & key

## Terraform Structure
```
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
```

## Repository Structure
```
gcp-serverless-image-pipeline
├── terraform/              # Terraform IaC definitions
├── functions/
│   ├── upload_image/       # Upload Lambda source
│   ├── process_image/      # Processing Lambda source
│   └── log_notification/   # Notification Lambda source
├── submission.json         # API endpoint + API key
├── README.md               # Documentation
├── .gitignore              # Git exclusions
```
-  Lambda zip files, Pillow binaries, Terraform state files, and layers are intentionally excluded from Git.

## Deployment Instructions
Prerequisites
- AWS CLI configured
- Terraform installed
- Python 3.11
- IAM permissions to deploy resources

## Deploy Infrastructure
```
cd terraform
terraform init
terraform apply
```
Terraform will output:
- API Gateway URL
- Resource identifiers

## Test Upload (Recommended)
Using httpie:
```
http POST \
https://<api-id>.execute-api.<region>.amazonaws.com/prod/v1/images/upload \
x-api-key:<YOUR_API_KEY> \
@architecture-diagram.png
```

## Verify Processing
```
aws s3 ls s3://image-pipeline-processed-<account-id>/processed/
```
## View Logs
```
aws logs tail /aws/lambda/image-pipeline-process-image --follow
```

## Cleanup (IMPORTANT)
To avoid unnecessary charges:
```
cd terraform
terraform destroy
```

## submission.json
The submission.json file is populated as required:
```
{
  "api_invoke_url": "https://4hxflm1bxl.execute-api.us-east-1.amazonaws.com/prod/v1/images/upload",
  "api_key": "e2RKoI58oa8m1b0XKZJK68jC8gH8jW5s6zoW8qGy"
}
```
