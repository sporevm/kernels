FROM ubuntu:22.04@sha256:0e0a0fc6d18feda9db1590da249ac93e8d5abfea8f4c3c0c849ce512b5ef8982

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bc=1.07.1-3build1 \
        binutils=2.38-4ubuntu2.12 \
        binutils-aarch64-linux-gnu=2.38-4ubuntu2.12 \
        bison=2:3.8.2+dfsg-1build1 \
        build-essential=12.9ubuntu3 \
        ca-certificates=20260601~22.04.1 \
        curl=7.81.0-1ubuntu1.25 \
        flex=2.6.4-8build2 \
        g++=4:11.2.0-1ubuntu1 \
        g++-11=11.4.0-1ubuntu1~22.04.3 \
        gcc=4:11.2.0-1ubuntu1 \
        gcc-11=11.4.0-1ubuntu1~22.04.3 \
        gcc-aarch64-linux-gnu=4:11.2.0-1ubuntu1 \
        gcc-11-aarch64-linux-gnu=11.4.0-1ubuntu1~22.04.3cross1 \
        libelf-dev=0.186-1ubuntu0.1 \
        libssl-dev=3.0.2-0ubuntu1.25 \
        make=4.3-4.1build1 \
        xz-utils=5.2.5-2ubuntu1.1 \
    && rm -rf /var/lib/apt/lists/*
