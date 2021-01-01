FROM golang:1.15

ARG VERSION

COPY . /go/src/github.com/stefanprodan/mgob

WORKDIR /go/src/github.com/stefanprodan/mgob

RUN CGO_ENABLED=0 GOOS=linux \
      go build \
        -ldflags "-X main.version=$VERSION" \
        -a -installsuffix cgo \
        -o mgob github.com/stefanprodan/mgob/cmd/mgob

FROM ubuntu:20.04

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Belgrade

ENV MONGO_TOOLS_VERSION=4.4
ENV GOOGLE_CLOUD_SDK_VERSION 316.0.0
ENV AZURE_CLI_VERSION 2.17.0
ENV AWS_CLI_VERSION 1.18.159
ENV PATH /root/google-cloud-sdk/bin:$PATH

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="backup" \
      org.label-schema.description="MongoDB backup automation tool" \
      org.label-schema.url="https://github.com/seavus/mongo-backup" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/seavus/mongo-backup" \
      org.label-schema.vendor="seavus.com" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"


RUN apt update && apt upgrade -y 
RUN apt install  -y --no-install-recommends gnupg \
        ca-certificates \
        tzdata \
        sudo \
        wget \
        systemctl \
        curl \
        python3 \
        python3-pip \
        bash \
        openssh-client \
        git \
        gcc \
        libffi-dev \
        musl-dev \
        libssl-dev \
        python3-dev \
        unzip \
        make
#libc6:i386 \

RUN wget -qO - https://www.mongodb.org/static/pgp/server-$MONGO_TOOLS_VERSION.asc | apt-key add -
RUN echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/$MONGO_TOOLS_VERSION multiverse" | tee /etc/apt/sources.list.d/mongodb-org-$MONGO_TOOLS_VERSION.list

RUN apt update && apt install -y mongodb-database-tools mongodb-org-database-tools-extra  mongodb-org-shell mongodb-org-tools

ADD https://dl.minio.io/client/mc/release/linux-amd64/mc /usr/bin
RUN chmod u+x /usr/bin/mc

ADD https://downloads.rclone.org/rclone-current-linux-amd64.zip /tmp
RUN cd /tmp \
  && unzip rclone-current-linux-amd64.zip \
  && cp rclone-*-linux-amd64/rclone /usr/bin/ \
  && chmod u+x /usr/bin/rclone

WORKDIR /root/

#install gcloud
# https://github.com/GoogleCloudPlatform/cloud-sdk-docker/blob/69b7b0031d877600a9146c1111e43bc66b536de7/alpine/Dockerfile
RUN pip3 --no-cache-dir install --upgrade pip && \
    pip --no-cache-dir install wheel && \
    pip --no-cache-dir install crcmod && \
    curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GOOGLE_CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    tar xzf google-cloud-sdk-${GOOGLE_CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    rm google-cloud-sdk-${GOOGLE_CLOUD_SDK_VERSION}-linux-x86_64.tar.gz && \
    ln -s /lib /lib64 && \
    gcloud config set core/disable_usage_reporting true && \
    gcloud config set component_manager/disable_update_check true && \
    gcloud config set metrics/environment github_docker_image && \
    gcloud --version

# install azure-cli and aws-cli
RUN pip --no-cache-dir install cffi && \
    pip --no-cache-dir --use-feature=2020-resolver install azure-cli==${AZURE_CLI_VERSION} && \
    pip --no-cache-dir install awscli==${AWS_CLI_VERSION} 

COPY --from=0 /go/src/github.com/stefanprodan/mgob/mgob .

VOLUME ["/config", "/storage", "/tmp", "/data"]

ENTRYPOINT [ "./mgob" ]
