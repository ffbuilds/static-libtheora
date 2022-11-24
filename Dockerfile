# syntax=docker/dockerfile:1

# bump: theora /THEORA_VERSION=([\d.]+)/ https://github.com/xiph/theora.git|*
# bump: theora after ./hashupdate Dockerfile THEORA $LATEST
# bump: theora link "Release notes" https://github.com/xiph/theora/releases/tag/v$LATEST
# bump: theora link "Source diff $CURRENT..$LATEST" https://github.com/xiph/theora/compare/v$CURRENT..v$LATEST
ARG THEORA_VERSION=1.1.1
ARG THEORA_URL="https://downloads.xiph.org/releases/theora/libtheora-$THEORA_VERSION.tar.bz2"
ARG THEORA_SHA256=b6ae1ee2fa3d42ac489287d3ec34c5885730b1296f0801ae577a35193d3affbc

# Must be specified
ARG ALPINE_VERSION

FROM ghcr.io/ffbuilds/static-libogg-alpine_${ALPINE_VERSION}:main as libogg

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG THEORA_URL
ARG THEORA_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O libtheora.tar.bz2 "$THEORA_URL" && \
  echo "$THEORA_SHA256  libtheora.tar.bz2" | sha256sum --status -c - && \
  mkdir theora && \
  tar xf libtheora.tar.bz2 -C theora --strip-components=1 && \
  rm libtheora.tar.bz2 && \
  apk del download

FROM base AS build
COPY --from=download /tmp/theora/ /tmp/theora/
COPY --from=libogg /usr/local/lib/pkgconfig/ogg.pc /usr/local/lib/pkgconfig/ogg.pc
COPY --from=libogg /usr/local/lib/libogg.a /usr/local/lib/libogg.a
COPY --from=libogg /usr/local/include/ogg/ /usr/local/include/ogg/
WORKDIR /tmp/theora
RUN \
  apk add --no-cache --virtual build \
    build-base pkgconf && \
  # --build=$(arch)-unknown-linux-gnu helps with guessing the correct build. For some reason,
  # build script can't guess the build type in arm64 (hardware and emulated) environment.
  ./configure --build=$(arch)-unknown-linux-gnu --disable-examples --disable-oggtest --disable-shared --enable-static && \
  make -j$(nproc) install && \
  # Sanity tests
  pkg-config --exists --modversion --path theora && \
  pkg-config --exists --modversion --path theoraenc && \
  pkg-config --exists --modversion --path theoradec && \
  ar -t /usr/local/lib/libtheora.a && \
  ar -t /usr/local/lib/libtheoraenc.a && \
  ar -t /usr/local/lib/libtheoradec.a && \
  readelf -h /usr/local/lib/libtheora.a && \
  readelf -h /usr/local/lib/libtheoraenc.a && \
  readelf -h /usr/local/lib/libtheoradec.a && \
  # Cleanup
  apk del build

FROM scratch
ARG THEORA_VERSION
COPY --from=build /usr/local/lib/pkgconfig/theora*.pc /usr/local/lib/pkgconfig/
COPY --from=build /usr/local/lib/libtheora*.a /usr/local/lib/
COPY --from=build /usr/local/include/theora/ /usr/local/include/theora/
