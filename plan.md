# Implementation Plan: GPU-Enabled Kubeflow Notebook with Astral UV

## Overview
Build a production-ready Docker image for Kubeflow notebooks with:
- GPU/CUDA support (NVIDIA CUDA 12.2)
- Astral UV for fast Python package management
- VS Code Server (code-server) interface
- Pre-installed data science libraries (PyTorch, pandas, numpy, etc.)
- Kubeflow compatibility (NB_PREFIX, proper port configuration)
- Non-root user security setup

## Implementation Steps

### Phase 1: Dockerfile Setup

#### Step 1.1: Create Base Dockerfile
- Base image: `nvidia/cuda:12.2.0-base-ubuntu22.04`
- Set environment variables (LANG, NB_USER, NB_PREFIX, etc.)
- Configure non-interactive apt installations

#### Step 1.2: Install System Dependencies
- Install core utilities (curl, wget, git, build-essential)
- Install Python 3 and pip
- Install sudo, tini, openssh-client, ca-certificates
- Clean up apt cache to reduce image size

#### Step 1.3: Create Non-Root User
- Create user `developer` with UID 1000, GID 100
- Configure sudo access without password
- Set proper home directory permissions

#### Step 1.4: Install Python Environment Tools
- Install Miniconda to /opt/conda
- Install Astral UV via official install script
- Move UV binary to /usr/local/bin for global access

#### Step 1.5: Install Python Data Science Stack
- Upgrade pip, setuptools, wheel
- Install core libraries: numpy, pandas, matplotlib, seaborn, scikit-learn
- Install Jupyter: notebook, jupyterlab, ipykernel
- Install PyTorch with CUDA 12.2 support (torch, torchvision, torchaudio)

#### Step 1.6: Install VS Code Server
- Install code-server via official install script
- Create extensions directory
- Pre-install extensions: ms-python.python, ms-toolsai.jupyter

#### Step 1.7: Configure Kubeflow Integration
- Set NB_PREFIX environment variable
- Configure working directory (/home/developer/project)
- Expose port 8888
- Set up proper entrypoint with tini

#### Step 1.8: Configure Startup Command
- Start code-server on 0.0.0.0:8888
- Disable authentication (Kubeflow handles auth)
- Disable telemetry
- Configure extensions directory

### Phase 2: Build and Test

#### Step 2.1: Create Build Script
- Create build.sh with proper tagging
- Add version management (latest + semantic versioning)
- Include build arguments for customization

#### Step 2.2: Local Build Test
- Build image locally
- Verify image size is reasonable
- Check all layers built successfully

#### Step 2.3: Local Runtime Test
- Run container with GPU support (--gpus all)
- Test port 8888 accessibility
- Verify code-server launches correctly
- Test GPU availability in Python (torch.cuda.is_available())
- Test UV functionality
- Verify Jupyter kernel works

### Phase 3: Registry and Deployment

#### Step 3.1: Push to Container Registry
- Tag image with repository name
- Push to Docker Hub / private registry
- Verify image is pullable

#### Step 3.2: Create Kubeflow Notebook Configuration
- Create YAML manifest for Kubeflow Notebook CR
- Configure GPU resources (limits/requests)
- Set proper image pull policy
- Configure volume mounts if needed

#### Step 3.3: Deploy to Kubeflow
- Apply notebook configuration
- Wait for pod to be ready
- Access via Kubeflow UI
- Test NB_PREFIX path handling

#### Step 3.4: Validation
- Test GPU access in notebook
- Test UV package installation
- Test code-server extensions
- Test Jupyter kernel
- Verify persistent storage (if configured)

### Phase 4: Documentation and Maintenance

#### Step 4.1: Create Documentation
- Document build process
- Document usage instructions
- Document environment variables
- Create troubleshooting guide

#### Step 4.2: Setup CI/CD ✅ COMPLETED
- Created GitHub Actions workflow (`.github/workflows/build-and-push.yml`)
- Triggers on semantic version tags (`v*` pattern)
- Automates builds on tag push with Docker Buildx
- Automates registry push to Docker Hub
- Integrated Trivy security scanning
- Semantic version tagging (v1.0.0, 1.0.0, 1.0, latest)
- Cache optimization with GitHub Actions cache
- Security findings uploaded to GitHub Security tab

---

## 🔹 CI/CD Pipeline (GitHub Actions)

### Files Created

- **`.github/workflows/build-and-push.yml`** - Main workflow for automated builds
- **`.github/SETUP_CI_CD.md`** - Complete setup guide for GitHub Actions
- **`build.sh`** - Local build script that mirrors CI/CD pipeline

### Workflow Features

| Feature | Details |
|---------|---------|
| **Trigger** | Semantic version tags (`v1.0.0`, `v1.2.3`, etc.) |
| **Build** | Automated Docker image build with caching |
| **Registry** | Docker Hub (configurable via secrets) |
| **Security** | Trivy vulnerability scanning (CRITICAL/HIGH) |
| **Tags** | Automatic semantic versioning (1.0.0, 1.0, latest) |
| **Auth** | GitHub Secrets (DOCKER_USERNAME, DOCKER_PASSWORD) |

### Quick Start

1. **Set up GitHub Secrets:**
   - `DOCKER_USERNAME` - Your Docker Hub username
   - `DOCKER_PASSWORD` - Docker Hub personal access token

2. **Push a version tag:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. **Monitor build in GitHub Actions tab**

4. **Use in Kubeflow:**
   ```yaml
   image: your-username/code-server-astraluv:v1.0.0
   ```

See [`.github/SETUP_CI_CD.md`](.github/SETUP_CI_CD.md) for detailed setup instructions.

---

## Dockerfile: `code-server + Kubeflow + Astral UV + GPU + Jupyter + Python libs`

```dockerfile
# -----------------------------
# Base Image
# -----------------------------
FROM nvidia/cuda:12.2.0-base-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    SHELL=/bin/bash \
    NB_USER=developer \
    NB_UID=1000 \
    NB_GID=100 \
    PATH=/opt/conda/bin:$PATH

# -----------------------------
# System dependencies
# -----------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git build-essential \
    python3 python3-venv python3-pip \
    sudo tini openssh-client \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------
# Create user
# -----------------------------
RUN groupadd -g ${NB_GID} ${NB_USER} \
    && useradd -m -u ${NB_UID} -g ${NB_GID} -s /bin/bash ${NB_USER} \
    && echo "${NB_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# -----------------------------
# Install Miniconda (for Python envs)
# -----------------------------
RUN curl -sSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p /opt/conda \
    && rm /tmp/miniconda.sh \
    && /opt/conda/bin/conda clean -tipsy

# -----------------------------
# Install Astral UV
# -----------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.cargo/bin/uv /usr/local/bin/uv

# -----------------------------
# Python packages (common data science)
# -----------------------------
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir \
       numpy pandas matplotlib seaborn scikit-learn \
       jupyter notebook jupyterlab \
       torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu122 \
       ipykernel

# -----------------------------
# Install code-server (VS Code server)
# -----------------------------
RUN curl -fsSL https://code-server.dev/install.sh | sh

# -----------------------------
# VS Code extensions
# -----------------------------
RUN mkdir -p /home/${NB_USER}/.local/share/code-server/extensions \
    && chown -R ${NB_USER}:${NB_USER} /home/${NB_USER}/.local \
    && su ${NB_USER} -c "code-server --install-extension ms-python.python --force" \
    && su ${NB_USER} -c "code-server --install-extension ms-toolsai.jupyter --force"

# -----------------------------
# Setup Kubeflow Notebook compatibility
# -----------------------------
ENV NB_PREFIX="/notebooks/${NB_USER}" \
    HOME=/home/${NB_USER}

WORKDIR /home/${NB_USER}/project
RUN mkdir -p /home/${NB_USER}/project \
    && chown -R ${NB_USER}:${NB_USER} /home/${NB_USER}

# -----------------------------
# Expose Kubeflow port
# -----------------------------
EXPOSE 8888

# -----------------------------
# SSH (optional)
# -----------------------------
RUN apt-get update && apt-get install -y openssh-server \
    && mkdir /var/run/sshd

# -----------------------------
# Switch to non-root user
# -----------------------------
USER ${NB_USER}

# -----------------------------
# Entrypoint with tini for signal handling
# -----------------------------
ENTRYPOINT ["/usr/bin/tini", "--"]

# -----------------------------
# Start code-server + Jupyter (Kubeflow ready)
# -----------------------------
CMD code-server --bind-addr 0.0.0.0:8888 \
     --auth none \
     --disable-telemetry \
     --extensions-dir /home/${NB_USER}/.local/share/code-server/extensions
```

---

## 🔹 Features included

| Feature                  | Notes                                                       |
| ------------------------ | ----------------------------------------------------------- |
| Kubeflow Notebook ready  | `NB_PREFIX` + port 8888                                     |
| VS Code Server           | `code-server` installed, extensions preloaded               |
| Jupyter / Python         | Notebook & kernel support                                   |
| Astral `uv`              | Fast Python envs                                            |
| GPU / CUDA               | Base: `nvidia/cuda:12.2`                                    |
| Preinstalled Python libs | torch, torchvision, pandas, numpy, matplotlib, scikit-learn |
| Non-root                 | Security-friendly                                           |
| SSH optional             | Can enable for debug / dev containers                       |

---

## 🔹 Build & push

```bash
docker build -t dockerhub_user/code-server-astraluv:latest .
docker push dockerhub_user/code-server-astraluv:latest
```

Use in Kubeflow Notebook YAML:

```yaml
image: dockerhub_user/code-server-astraluv:latest
imagePullPolicy: Always
```

---

If you want, I can also make a **“one-command auto-update version”**:

* Kubeflow automatically pulls new image when pushed
* No manual restart required
* Fully integrated with `latest` tag + Astral UV

Do you want me to make that?
