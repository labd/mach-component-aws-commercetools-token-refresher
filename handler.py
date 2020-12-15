"""
If you ever get PutSecretValue cannot be used with ClientRequestToken because it already exists; delete the AWSPENDING value:

aws secretsmanager update-secret-version-stage --secret-id <arn> --version-stage AWSPENDING --remove-from-version-id <AWSPENDING value id>

Make sure you use the correct secret value, you can use the following command to see if there is a separate AWSPENDING stage:

aws secretsmanager list-secrets
"""

import logging
import os

import sentry_sdk
from sentry_sdk.integrations.aws_lambda import AwsLambdaIntegration

from commercetools_token_refresher.rotator import TokenRotator
from commercetools_token_refresher.utils import set_sentry_scope

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sentry_sdk.init(dsn=os.environ.get("SENTRY_DSN"), integrations=[AwsLambdaIntegration()])


def handle(event, context):
    """Secrets Manager commercetools Bearer Token Handler

    This handler uses the master-user rotation scheme to rotate a bearer token of a commercetools client.

    Expects the following environment variables:

    API_URL: commercetools API base url
    AUTH_URL: commercetools oauth2 base url

    The Secret PlaintextString is expected to be a JSON string with the following format:
    {
        'access_token': ,
    }

    And the following tag:

    - sm_client_arn: ARN of the secret which contains client id and secret

    Args:
        event (dict): Lambda dictionary of event parameters. These keys must include the following:
            - SecretId: The secret ARN or identifier
            - ClientRequestToken: The ClientRequestToken of the secret version
            - Step: The rotation step (one of createSecret, setSecret, testSecret, or finishSecret)

        context (LambdaContext): The Lambda runtime information

    Raises:
        ResourceNotFoundException: If the secret with the specified arn and stage does not exist

        ValueError: If the secret is not properly configured for rotation or missing the correct tags

        KeyError: If the secret json does not contain the expected keys
    """
    arn = event["SecretId"]
    token = event["ClientRequestToken"]
    step = event["Step"]
    logger.info("Got step: %s", step)

    set_sentry_scope(arn)

    oauth2_token_url = os.environ["AUTH_URL"] + "/oauth/token"
    oauth2_api_url = os.environ["API_URL"]

    rotator = TokenRotator(oauth2_token_url, oauth2_api_url, arn, token)

    if step == "createSecret":
        rotator.create_secret()
    elif step == "setSecret":
        rotator.set_secret()
    elif step == "testSecret":
        rotator.test_secret()
    elif step == "finishSecret":
        rotator.finish_secret()
    else:
        logger.error(
            "lambda_handler: Invalid step parameter %s for secret %s", step, arn
        )
        raise ValueError("Invalid step parameter %s for secret %s" % (step, arn))
