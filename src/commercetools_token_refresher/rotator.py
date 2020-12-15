import contextlib
import json
import logging
import os
from typing import Dict

import boto3
from requests.auth import HTTPBasicAuth

from commercetools_token_refresher.utils import get_secret_dict, requests_retry_session

logger = logging.getLogger(__name__)


class TokenRotator:
    def __init__(
        self,
        oauth2_token_url: str,
        oauth2_api_url: str,
        secret_arn: str,
        client_request_token: str,
    ):
        self.service_client = boto3.client(
            "secretsmanager", region_name=os.environ["AWS_DEFAULT_REGION"]
        )
        self.oauth2_token_url = oauth2_token_url
        self.oauth2_api_url = oauth2_api_url
        self.secret_arn = secret_arn
        self.client_request_token = client_request_token
        # Make sure the metadata is correct
        self.metadata = self._validate_secret_metadata()

    def _validate_secret_metadata(self) -> Dict:
        """Do some validations on the secret to make sure it has the right data."""
        arn = self.secret_arn

        metadata = self.service_client.describe_secret(SecretId=arn)
        if not metadata["Tags"]:
            logger.error("Secret %s has no tags", arn)
            raise ValueError("Secret %s has no tags" % arn)

        tags = [tag["Key"] for tag in metadata["Tags"]]
        if "sm_client_arn" not in tags:
            logger.error("Secret %s is missing required 'sm_client_arn' tag", arn)
            raise ValueError("Secret %s is missing required 'sm_client_arn' tag" % arn)

        if not metadata["RotationEnabled"]:
            logger.error("Secret %s is not enabled for rotation", arn)
            raise ValueError("Secret %s is not enabled for rotation" % arn)

        versions = metadata["VersionIdsToStages"]
        token = self.client_request_token
        if token not in versions:
            logger.error(
                "Secret version %s has no stage for rotation of secret %s.", token, arn
            )
            raise ValueError(
                "Secret version %s has no stage for rotation of secret %s.", token, arn
            )

        if "AWSPENDING" not in versions[token]:
            logger.error(
                "Secret version %s not set as AWSPENDING for rotation of secret %s.",
                token,
                arn,
            )
            raise ValueError(
                "Secret version %s not set as AWSPENDING for rotation of secret %s.",
                token,
                arn,
            )

        return metadata

    def _get_secret(self, stage: str, token: str = None):
        return get_secret_dict(self.service_client, self.secret_arn, stage, token)

    def _set_pending_secret_value(self, new_access_token: str):
        response = self.service_client.list_secret_version_ids(SecretId=self.secret_arn)
        logger.info("Current secret version ids: %s", response)

        with contextlib.suppress(
            self.service_client.exceptions.ResourceNotFoundException
        ):
            pending_secret_dict = self._get_secret(
                "AWSPENDING", self.client_request_token,
            )
            logger.info("AWSPENDING stage exists with data: %s", pending_secret_dict)
            return

        new_secret_data = {"access_token": new_access_token}

        response = self.service_client.put_secret_value(
            SecretId=self.secret_arn,
            ClientRequestToken=self.client_request_token,
            SecretString=json.dumps(new_secret_data),
            VersionStages=["AWSPENDING"],
        )
        logger.info("Update AWSPENDING stage result: %s", response)

    def set_secret(self):
        """Skip for now, secret is already created in create_secret step."""
        return

    def test_secret(self):
        """Skip for now, just assume the generated token is correct."""
        return

    def finish_secret(self):
        """Move label AWSCURRENT to AWSPENDING, then delete the current AWSPENDING secret value."""
        # First describe the secret to get the current version
        current_version = None
        marked_current = False
        pending_version = None
        for version in self.metadata["VersionIdsToStages"]:
            if "AWSPENDING" in self.metadata["VersionIdsToStages"][version]:
                pending_version = version
            if "AWSCURRENT" in self.metadata["VersionIdsToStages"][version]:
                if version == self.client_request_token:
                    # The correct version is already marked as current, return
                    logger.info(
                        "finishSecret: Version %s already marked as AWSCURRENT for %s",
                        version,
                        self.secret_arn,
                    )
                    marked_current = True
                current_version = version

        if not marked_current:
            # Finalize by staging the secret version current
            self.service_client.update_secret_version_stage(
                SecretId=self.secret_arn,
                VersionStage="AWSCURRENT",
                MoveToVersionId=self.client_request_token,
                RemoveFromVersionId=current_version,
            )
            logger.info(
                "finishSecret: Successfully set AWSCURRENT stage to version %s for secret %s.",
                current_version,
                self.secret_arn,
            )

        if pending_version:
            response = self.service_client.update_secret_version_stage(
                SecretId=self.secret_arn,
                VersionStage="AWSPENDING",
                RemoveFromVersionId=pending_version,
            )
            logger.info(
                "finishSecret: Removed AWSPENDING stage from version %s response: %s",
                self.secret_arn,
                response,
            )

    def get_tag(self, tag_name: str) -> str:
        for tag in self.metadata.get("Tags", []):
            if tag["Key"] == tag_name:
                return tag["Value"]
        raise ValueError(f"Tag {tag_name} not found")

    def create_secret(self):
        """Request a new token, not it takes ~10 minutes before a new token can be requested.

        If a secret version with AWSPENDING stage exists, updates it with the newly retrieved bearer token and if
        the AWSPENDING stage does not exist, creates a new version of the secret with that stage label.
        """
        # Make sure the current secret exists and try to get the master arn from the secret
        client_credentials_secret_arn = self.get_tag("sm_client_arn")

        client_data = get_secret_dict(
            self.service_client, client_credentials_secret_arn, "AWSCURRENT"
        )
        ct_client_id = client_data["client_id"]
        ct_client_secret = client_data["client_secret"]
        client_scopes = client_data["client_scopes"]

        logger.info(
            "Creating new token with scopes %s for client id %s",
            client_scopes,
            ct_client_id,
        )

        params = {"grant_type": "client_credentials", "scope": client_scopes}
        session = requests_retry_session()
        response = session.post(
            auth=HTTPBasicAuth(ct_client_id, ct_client_secret),
            url=self.oauth2_token_url,
            params=params,
            timeout=10,
        )
        if response.status_code != 200:
            logger.error(
                "Failed to ask for new access token, got response: %s",
                response.__dict__,
            )
        response_data = response.json()
        logger.info("Got response from oauth token create_secret: %s", response_data)
        min_expiry_time = 60 * 60 * 40
        if response_data["expires_in"] <= min_expiry_time:
            logger.error(
                "Cannot safely use this access token since rotation can worst"
                " case take ~40 hours and the token has less time than that."
            )
            raise RuntimeError("Access token has not enough time left")

        new_access_token = response_data["access_token"]

        self._set_pending_secret_value(new_access_token)
