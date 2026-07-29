# syntax=docker/dockerfile:1

ARG RUST_VERSION=1.97
ARG ALPINE_VERSION=3.24
ARG SUDACHI_VERSION=0.6.11
# small (最小) / core (標準) / full (固有名詞まで全部)
ARG DICT_TYPE=core
ARG DICT_VERSION=20260723

# ---------- build the sudachi CLI (static musl binary) ----------
FROM rust:${RUST_VERSION}-alpine${ALPINE_VERSION} AS build
ARG SUDACHI_VERSION

RUN apk add --no-cache musl-dev

WORKDIR /src
ADD https://github.com/WorksApplications/sudachi.rs/archive/refs/tags/v${SUDACHI_VERSION}.tar.gz /tmp/sudachi.tar.gz
RUN tar xzf /tmp/sudachi.tar.gz --strip-components=1 && rm /tmp/sudachi.tar.gz

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/src/target \
    cargo build --release --locked -p sudachi-cli && \
    cp target/release/sudachi /usr/local/bin/sudachi

# ---------- fetch SudachiDict ----------
FROM alpine:${ALPINE_VERSION} AS dict
ARG DICT_TYPE
ARG DICT_VERSION

RUN apk add --no-cache curl unzip

WORKDIR /dict
RUN curl -fsSL -o dict.zip \
      "https://d2ej7fkh96fzlu.cloudfront.net/sudachidict/sudachi-dictionary-${DICT_VERSION}-${DICT_TYPE}.zip" && \
    unzip -j dict.zip "*/system_${DICT_TYPE}.dic" -d . && \
    mv "system_${DICT_TYPE}.dic" system.dic && \
    rm dict.zip

# ---------- runtime ----------
FROM alpine:${ALPINE_VERSION}
ARG SUDACHI_VERSION
ARG DICT_VERSION
ARG DICT_TYPE

LABEL org.opencontainers.image.title="sudachi" \
      org.opencontainers.image.description="Japanese tokenizer: sudachi.rs ${SUDACHI_VERSION} + SudachiDict ${DICT_VERSION}-${DICT_TYPE}" \
      org.opencontainers.image.source="https://github.com/5ym/sudachi" \
      org.opencontainers.image.licenses="Apache-2.0"

COPY --from=build /usr/local/bin/sudachi /usr/local/bin/sudachi
COPY --from=build /src/resources/char.def /src/resources/unk.def /src/resources/rewrite.def /opt/sudachi/
COPY --from=dict /dict/system.dic /opt/sudachi/system.dic
COPY sudachi.json /opt/sudachi/sudachi.json

# 辞書やユーザー辞書を差し替えたいときは /opt/sudachi をマウントで上書きする
ENTRYPOINT ["sudachi", "-r", "/opt/sudachi/sudachi.json"]
