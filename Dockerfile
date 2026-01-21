# =============================================================================
# GPU-Enabled Kubeflow Notebook with Astral UV and VS Code Server
# Base: NVIDIA CUDA 12.2 on Ubuntu 22.04
# Features: UV (multi-stage), code-server, s6-overlay
# Kubeflow Compliant: jovyan user, port 8888, NB_PREFIX support
#
# NOTE: This is a minimal image. Users install packages via UV:
#   uv pip install torch pandas numpy jupyterlab
#   uv python install 3.12  # Install additional Python versions
# =============================================================================

# -----------------------------
# Build Arguments
# -----------------------------
ARG CUDA_VERSION=12.2.0
ARG CUDA_FLAVOR=base
ARG UBUNTU_VERSION=22.04
ARG CODE_SERVER_VERSION=4.96.2
ARG S6_VERSION=v3.1.6.2
ARG UV_VERSION=latest

# -----------------------------
# Stage 1: Copy UV from official image
# -----------------------------
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

# -----------------------------
# Stage 2: Main image
# -----------------------------
FROM nvidia/cuda:${CUDA_VERSION}-${CUDA_FLAVOR}-ubuntu${UBUNTU_VERSION}

# Re-declare ARGs after FROM
ARG CUDA_FLAVOR
ARG CODE_SERVER_VERSION
ARG S6_VERSION

# -----------------------------
# Metadata Labels
# -----------------------------
LABEL maintainer="danieldu28121999"
LABEL description="GPU-enabled Kubeflow notebook with UV and VS Code Server - minimal image, install packages via UV"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/danghoangnhan/kubeflow-notebook-uv"
LABEL org.opencontainers.image.licenses="MIT"

# -----------------------------
# Environment Variables (Kubeflow Compliant)
# -----------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    SHELL=/bin/bash \
    NB_USER=jovyan \
    NB_UID=1000 \
    NB_GID=100 \
    HOME=/home/jovyan \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    CUDA_HOME=/usr/local/cuda \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH \
    # UV settings
    UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON_DOWNLOADS=automatic \
    UV_PYTHON_PREFERENCE=managed \
    PATH="/home/jovyan/.local/bin:$PATH"

# -----------------------------
# System Dependencies
# -----------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    # System utilities
    sudo \
    openssh-client \
    # Additional tools
    vim \
    htop \
    xz-utils \
    # For code-server
    locales \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    # Generate locale
    && locale-gen en_US.UTF-8

# -----------------------------
# Install s6-overlay
# For proper process management in Kubeflow
# -----------------------------
RUN curl -sSL https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-noarch.tar.xz | tar -Jxp -C / && \
    curl -sSL https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-x86_64.tar.xz | tar -Jxp -C /

# -----------------------------
# Create Non-Root User: jovyan
# Kubeflow requirement: user must be 'jovyan' with UID 1000
# -----------------------------
RUN groupadd -f -g ${NB_GID} users && \
    useradd -m -u ${NB_UID} -g ${NB_GID} -s /bin/bash ${NB_USER} && \
    mkdir -p /home/${NB_USER}/.local/bin /home/${NB_USER}/.local/share /home/${NB_USER}/.cache /home/${NB_USER}/project && \
    chown -R ${NB_USER}:users /home/${NB_USER}

# -----------------------------
# Copy UV from official image (multi-stage)
# See: https://docs.astral.sh/uv/guides/integration/docker/
# -----------------------------
COPY --from=uv /uv /uvx /usr/local/bin/

# -----------------------------
# Install code-server
# -----------------------------
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version=${CODE_SERVER_VERSION}

# -----------------------------
# Switch to jovyan user for user-level setup
# -----------------------------
USER ${NB_USER}
WORKDIR /home/${NB_USER}

# -----------------------------
# Install Python via UV (user can install additional versions)
# UV manages Python versions - no need for system Python or Miniconda
# -----------------------------
RUN uv python install 3.11 && \
    uv python pin 3.11

# Create Jupyter config directory first
RUN mkdir -p /home/${NB_USER}/.jupyter

# Install JupyterLab into a virtual environment via UV
USER ${NB_USER}
WORKDIR /home/${NB_USER}
RUN uv venv && uv pip install jupyterlab ipykernel notebook
USER root

# -----------------------------
# Install VS Code Extensions
# -----------------------------
RUN mkdir -p /home/${NB_USER}/.local/share/code-server/extensions && \
    code-server --install-extension ms-python.python --force && \
    code-server --install-extension ms-toolsai.jupyter --force

# -----------------------------
# Switch back to root to copy s6 scripts
# -----------------------------
USER root

# -----------------------------
# Copy s6-overlay scripts and configuration
# -----------------------------
COPY --chown=${NB_USER}:users s6/ /etc/

# Make s6 scripts executable
RUN chmod +x /etc/cont-init.d/* /etc/services.d/code-server/* /etc/services.d/jupyterlab/* 2>/dev/null || true

# Create code-server config directory
RUN mkdir -p /etc/code-server && chown ${NB_USER}:users /etc/code-server

# Copy code-server configuration
COPY --chown=${NB_USER}:users config/code-server-config.yaml /etc/code-server/config.yaml

# Copy Jupyter configuration
COPY --chown=${NB_USER}:users config/jupyter_lab_config.py /home/${NB_USER}/.jupyter/

# -----------------------------
# Setup Kubeflow Notebook Compatibility
# -----------------------------
ENV NB_PREFIX="/notebooks/${NB_USER}"

# Ensure proper permissions on home directory
RUN chown -R ${NB_USER}:users /home/${NB_USER}

# Switch to jovyan user (Kubeflow requirement)
USER ${NB_USER}
WORKDIR /home/${NB_USER}/project

# -----------------------------
# Expose Kubeflow Port
# -----------------------------
EXPOSE 8888 8889

# -----------------------------
# Health Check
# -----------------------------
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8888/ || exit 1

# -----------------------------
# Environment for s6-overlay
# -----------------------------
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

# -----------------------------
# Entrypoint with s6-overlay for process management
# Kubeflow recommendation for managing multiple services
# -----------------------------
ENTRYPOINT ["/init"]

# =============================================================================
# USAGE: Install packages via UV
# =============================================================================
#
# Install Python packages:
#   uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu122
#   uv pip install pandas numpy matplotlib jupyterlab scikit-learn
#
# Install additional Python versions:
#   uv python install 3.12
#   uv python install 3.10
#   uv python list
#
# Create virtual environment:
#   uv venv myenv
#   source myenv/bin/activate
#   uv pip install -r requirements.txt
#
# Use specific Python version:
#   uv venv --python 3.12 myenv-312
#
# =============================================================================
