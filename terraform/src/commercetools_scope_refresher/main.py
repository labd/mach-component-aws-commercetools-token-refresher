import boto3
import sys
import logging
import traceback
import json


logger = logging.getLogger()
logger.setLevel(logging.INFO)

client = boto3.client("secretsmanager")


def handle(event, context):
    """Rotate access token when scope changes

    Sample event
    {
        "version": "0",
        "id": "6886abbc-2f46-a604-2640-9b2c028984a7",
        "detail-type": "Tag Change on Resource",
        "source": "aws.tag",
        "account": "123456789012",
        "time": "2018-09-25T00:46:47Z",
        "region": "us-east-1",
        "resources": ["arn:aws:secretsmanager:us-east-1:123456789012:secret:example/example"],
        "detail": {
            "changed-tag-keys": ["scope_hash"],
            "service": "secretsmanager",
            "resource-type": "secret",
            "version": 1,
            "tags": {
            "scope_hash": "hash"
            }
        }
    }
    """
    logger.info(f'event: {event}')

    for resource in event["resources"]:
        logger.info(f"rotating resource: {resource}")

        try:
            response = client.rotate_secret(SecretId=resource)
        except Exception as exp:
            exception_type, exception_value, exception_traceback = sys.exc_info()
            traceback_string = traceback.format_exception(exception_type, exception_value, exception_traceback)
            err_msg = json.dumps({
                "errorType": exception_type.__name__,
                "errorMessage": str(exception_value),
                "stackTrace": traceback_string
            })
            logger.error(err_msg)
            return

        logger.info(f"rotated: {resource}")
