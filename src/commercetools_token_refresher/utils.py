import json
import os
from typing import Tuple, Optional

import requests
import sentry_sdk
from requests.adapters import HTTPAdapter
from urllib3 import Retry


def get_secret_dict(service_client, arn: str, stage: str, token: str = None):
    """Gets the secret dictionary corresponding for the secret arn, stage, and token

    This helper function gets credentials for the arn and stage passed in and returns the dictionary by parsing the JSON string

    Args:
        service_client (client): The secrets manager service client

        arn (string): The secret ARN or other identifier

        token (string): The ClientRequestToken associated with the secret version, or None if no validation is desired

        stage (string): The stage identifying the secret version

    Returns:
        SecretDictionary: Secret dictionary

    Raises:
        ResourceNotFoundException: If the secret with the specified arn and stage does not exist

        ValueError: If the secret is not valid JSON

    """
    # Only do VersionId validation against the stage if a token is passed in
    if token:
        secret = service_client.get_secret_value(
            SecretId=arn, VersionId=token, VersionStage=stage
        )
    else:
        secret = service_client.get_secret_value(SecretId=arn, VersionStage=stage)
    plaintext = secret["SecretString"]

    return json.loads(plaintext)


def requests_retry_session(
    retries: int = 3,
    backoff_factor: float = 0.3,
    status_forcelist: Tuple[int, ...] = (500, 502, 504),
    session: Optional[requests.Session] = None,
) -> requests.Session:
    session = session or requests.Session()
    retry = Retry(
        total=retries,
        read=retries,
        connect=retries,
        backoff_factor=backoff_factor,
        status_forcelist=status_forcelist,
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("http://", adapter)
    session.mount("https://", adapter)

    return session


def set_sentry_scope(secret_arn: str):
    with sentry_sdk.configure_scope() as scope:
        scope.set_tag("lambda", os.environ.get("AWS_LAMBDA_FUNCTION_NAME"))
        scope.set_tag("version", os.environ.get("AWS_LAMBDA_FUNCTION_VERSION"))
        scope.set_tag("memory_size", os.environ.get("AWS_LAMBDA_FUNCTION_MEMORY_SIZE"))
        scope.set_tag("log_group", os.environ.get("AWS_LAMBDA_LOG_GROUP_NAME"))
        scope.set_tag("log_stream", os.environ.get("AWS_LAMBDA_LOG_STREAM_NAME"))
        scope.set_tag("secret_arn", secret_arn)
        scope.set_tag("region", os.environ.get("AWS_REGION"))
