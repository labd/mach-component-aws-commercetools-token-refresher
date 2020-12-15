import os
import uuid

import boto3
import moto
import pytest

from commercetools_token_refresher.rotator import TokenRotator


@moto.mock_secretsmanager
def test_rotator_not_enabled_rotation():
    """Super basic test, should be expanded."""
    secret_name = "mock/ct-access-token"
    secrets_manager = boto3.client(
        "secretsmanager", region_name=os.environ["AWS_DEFAULT_REGION"]
    )
    # rotation not support in moto 1.3.14, so test that it errors out on that.
    secrets_manager.create_secret(
        Name=secret_name,
        SecretString="{}",
        Tags=[{"Key": "sm_client_arn", "Value": "some arn"}],
    )

    client_request_token = str(uuid.uuid4())
    with pytest.raises(ValueError):
        TokenRotator(
            "http://localhost/oauth/token",
            "http://localhost",
            secret_name,
            client_request_token,
        )
