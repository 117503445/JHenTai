#!/usr/bin/env bash

docker build -t builder .
docker run -v $(pwd):/workspace --network none builder build-in-docker.sh