FROM python:3.14-alpine AS base_image
LABEL \
  maintainer="Arne Fahrenwalde <arne@fahrenwal.de>" \
  description="DevContainer example for python projects" \
  version="1.0"
# Linux specific environment variables
ENV \
  BASE_DIR="/opt/app" \
  LANG="C.UTF-8" \
  LC_ALL="C.UTF-8" \
  USER="worker" \
  GROUP="worker"
# Python specific environment variables
ENV VIRTUAL_ENV="${BASE_DIR}/venv"
ENV \
  PATH="${VIRTUAL_ENV}/bin:${PATH}" \
  PYTHONDONTWRITEBYTECODE=1 \
  PYTHONPATH="${BASE_DIR}/src" \
  PYTHONUNBUFFERED=1
# overridable variables
ARG \
  TZ="Europe/Berlin" \
  UID=1000 \
  GID=1000

# install procps as simple docker healthcheck
RUN --mount=type=cache,target=/etc/apk/cache \
  apk add procps-ng

# Create the base layout for the application
#  /opt/app/
#           mnt/    -> docker volumes (r/w)
#           src/    -> project source code
#           venv/   -> virtual environment
RUN mkdir -p \
  "${BASE_DIR}/mnt" \
  "${BASE_DIR}/src" \
  "${BASE_DIR}/venv"

# add lower privileged user and group, only assign the app directory to the user
RUN addgroup -g ${GID} ${GROUP} \
  || export GROUP=$(awk -F: -v gid=${GID} '$3 == gid { print $1 }' /etc/group) \
  && adduser -u ${UID} -G ${GROUP} -h "${BASE_DIR}" -H -D ${USER} \
  && chown -R ${UID}:${GID} "${BASE_DIR}" \
  && chmod -R 750 "${BASE_DIR}"

# use the unprivileged user by default
USER ${USER}
WORKDIR "${BASE_DIR}"


FROM base_image AS build_image
ENV UV_COMPILE_BYTECODE=true
# install uv
COPY --from=ghcr.io/astral-sh/uv:latest --link /uv /uvx /usr/local/bin/
# add requirements for dynamic versioning support
USER root
RUN --mount=type=cache,target=/etc/apk/cache \
  apk add git make
RUN --mount=type=cache,target=/root/.cache \
  uv pip install --system uv-dynamic-versioning debugpy
USER ${USER}
# setup the app's virtual environment
RUN --mount=type=cache,uid=${UID},gid=${GID},target="${BASE_DIR}/.cache" \
  python3 -m venv --symlinks --without-pip "${VIRTUAL_ENV}"
# install app dependencies
RUN \
  --mount=type=bind,source=pyproject.toml,target="${BASE_DIR}/pyproject.toml" \
  --mount=type=bind,source=README.md,target="${BASE_DIR}/README.md" \
  --mount=type=bind,source=uv.lock,target="${BASE_DIR}/uv.lock" \
  uv sync --active

FROM build_image AS dev_image
# install ruff & ty
COPY --from=ghcr.io/astral-sh/ruff:latest --link /ruff /usr/local/bin/
COPY --from=ghcr.io/astral-sh/ty:latest --link /ty /usr/local/bin/
# install system dependencies for development and debugging inside a DevContainer
USER root
RUN --mount=type=cache,target=/etc/apk/cache \
  apk add \
    bind-tools \
    curl \
    fzf \
    gnupg \
    htop \
    iproute2 \
    iputils-ping \
    jq \
    lsof \
    net-tools \
    oh-my-zsh \
    pre-commit \
    procps \
    shadow \
    shellcheck \
    sudo \
    the_silver_searcher \
    vim \
    wget \
    zsh

# switch default shell to zsh
RUN chsh -s $(which zsh) ${USER}

# allow sudo for local developer
RUN echo "${USER} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USER} \
    && chmod 0440 /etc/sudoers.d/${USER}

USER ${USER}

# create mountpoints so that mounted volumes have the correct assigned permissions
RUN mkdir -p \
  "${BASE_DIR}/.cache" "${BASE_DIR}/cache" \
  "${BASE_DIR}/.vscode-server/{extensions" "${BASE_DIR}/extensionsCache" \
  "${BASE_DIR}/workspaces/${COMPOSE_PROJECT_NAME}"

ENV \
  TERM="xterm" \
  UV_LINK_MODE=copy

CMD sleep infinity


FROM base_image AS release

# set file/folder ownership to root to prevent changes during runtime
COPY --chown=0:${GID} --from=build_image --link "${BASE_DIR}" "${BASE_DIR}"

# ensure mount points are user writable
USER root
RUN chown -R ${UID}:${GID} "${BASE_DIR}/mnt"
USER ${USER}

COPY --chown=0:${GID} --link ./src "${BASE_DIR}/src"

# TODO: change command
CMD [ "app" ]

# TODO: update the healthcheck according to your needs
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD pgrep -f "app" > /dev/null || exit 1
