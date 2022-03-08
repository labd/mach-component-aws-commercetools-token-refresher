#!/bin/bash

VERSION=$(git rev-parse --short HEAD 2>/dev/null || echo "dev" )
TAGS=$(git describe --tags --abbrev=0 --exact-match 2> /dev/null)
BASENAME=commercetools_token_refresher

BUCKETS=("public-mach-components-eu-central-1" "public-mach-components-us-east-1")

artifact () {
    echo "${BASENAME}-$1.zip"
}

ARTIFACT_NAME=$(artifact $VERSION)

package () {
    python3 setup.py sdist bdist_wheel
    python3 -m pip install dist/*.whl -t ./build
    cp handler.py ./build
    clean
    cd build && zip -9 -r $ARTIFACT_NAME .
}

upload () {
    src="build/${ARTIFACT_NAME}"
    for BUCKET in ${BUCKETS[@]}
    do
        echo "Uploading assets to ${BUCKET}..."
        echo "  - ${ARTIFACT_NAME}"
        aws s3 cp --acl public-read $src s3://$BUCKET/$ARTIFACT_NAME
        for TAG in $TAGS
        do
            echo "  - $(artifact $TAG)"
            aws s3 cp --acl public-read $src s3://$BUCKET/$(artifact $TAG)
        done
    done
}

version () {
    echo "Version: '${VERSION}'"
    echo "Artifact name: '${ARTIFACT_NAME}'"
    for TAG in $TAGS
    do
        echo " - $(artifact $TAG)"
    done
}

clean () {
    find . -name '*.pyc' -delete
    find . -name '__pycache__' -delete
    find . -name '*.egg-info' | xargs rm -rf
}

case $1 in
    package)
        package $2 $3
    ;;
    upload)
        upload $2
    ;;
    version)
        version
    ;;
    clean)
        clean
    ;;
esac
