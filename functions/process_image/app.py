import json
import os
import boto3
from io import BytesIO
from PIL import Image

s3 = boto3.client("s3")
sqs = boto3.client("sqs")

UPLOADS_BUCKET = os.environ["UPLOADS_BUCKET"]
PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]
RESULTS_QUEUE_URL = os.environ["RESULTS_QUEUE_URL"]


def lambda_handler(event, context):
    for record in event["Records"]:
        message = json.loads(record["body"])

        bucket = message["bucket"]
        key = message["key"]
        image_id = message["image_id"]

        # Download image from S3
        response = s3.get_object(Bucket=bucket, Key=key)
        image_bytes = response["Body"].read()

        # Convert to grayscale
        image = Image.open(BytesIO(image_bytes)).convert("L")

        output_buffer = BytesIO()
        image.save(output_buffer, format="JPEG")
        output_buffer.seek(0)

        processed_key = f"processed-{key}"

        # Upload processed image
        s3.put_object(
            Bucket=PROCESSED_BUCKET,
            Key=processed_key,
            Body=output_buffer,
            ContentType="image/jpeg"
        )

        # Send completion message
        result_message = {
            "image_id": image_id,
            "original": f"s3://{bucket}/{key}",
            "processed": f"s3://{PROCESSED_BUCKET}/{processed_key}",
            "status": "SUCCESS"
        }

        sqs.send_message(
            QueueUrl=RESULTS_QUEUE_URL,
            MessageBody=json.dumps(result_message)
        )

    return {"status": "done"}
