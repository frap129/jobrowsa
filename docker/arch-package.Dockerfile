FROM archlinux:base-devel

ARG UID=1000
ARG GID=$UID

RUN groupadd --gid "${GID}" builder \
    && useradd --create-home --gid "${GID}" --uid "${UID}" builder

USER builder
WORKDIR /repo
