import re

from setuptools import find_packages, setup


with open("requirements.txt") as f:
    required = f.read().splitlines()

with open("requirements_dev.txt") as f:
    tests = f.read().splitlines()

install_requires = required
docs_require = ["sphinx>=1.4.0"]


with open("README.md") as fh:
    long_description = re.sub(
        "^.. start-no-pypi.*^.. end-no-pypi", "", fh.read(), flags=re.M | re.S
    )

setup(
    name="commercetools_token_refresher",
    version="0.3.2",
    description="commercetools token secrets manager refresher",
    long_description=long_description,
    author="Lab Digital B.V.",
    url="https://github.com/labd/terraform-commercetools-token-refresher",
    install_requires=install_requires,
    extras_require={"docs": docs_require, "test": tests},
    entry_points={},
    package_dir={"": "src"},
    packages=find_packages("src"),
    include_package_data=True,
    classifiers=[
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: Implementation :: CPython",
    ],
    zip_safe=False,
)
