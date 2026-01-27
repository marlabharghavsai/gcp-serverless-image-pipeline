import json
import os
import uuid
import base64
import boto3

s3 = boto3.client("s3")
sqs = boto3.client("sqs")

UPLOADS_BUCKET = os.environ["UPLOADS_BUCKET"]
REQUESTS_QUEUE_URL = os.environ["REQUESTS_QUEUE_URL"]


def lambda_handler(event, context):
    try:
        # API Gateway sends base64-encoded body
        if event.get("isBase64Encoded"):
            body = base64.b64decode(event["body"])
        else:
            return response(400, "Expected base64 encoded body")

        # Generate unique filename
        image_id = str(uuid.uuid4())
        object_key = f"{image_id}.jpg"

        # Upload to S3
        s3.put_object(
            Bucket=UPLOADS_BUCKET,
            Key=object_key,
            Body=body,
            ContentType="image/jpeg"
        )

        # Send message to SQS
        message = {
            "bucket": UPLOADS_BUCKET,
            "key": object_key,
            "image_id": image_id
        }

        sqs.send_message(
            QueueUrl=REQUESTS_QUEUE_URL,
            MessageBody=json.dumps(message)
        )

        return response(202, {
            "message": "Image accepted for processing",
            "image_id": image_id
        })

    except Exception as e:
        return response(500, str(e))


def response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body)
    }
