import os

import pytest


# moto workaround
os.environ.setdefault("AWS_ACCESS_KEY_ID", "foobar_key")
os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "foobar_secret")


@pytest.fixture(autouse=True)
def lambda_env(monkeypatch):
    monkeypatch.setenv("AWS_DEFAULT_REGION", "eu-west-1")
    monkeypatch.setenv("API_URL", "https://localhost")
    monkeypatch.setenv("AUTH_URL", "https://localhost")
