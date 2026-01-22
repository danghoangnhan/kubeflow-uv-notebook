# Kubeflow Notebook with Astral UV and GPU Support

A **minimal**, production-ready Docker image for Kubeflow notebooks featuring GPU/CUDA support, Astral UV for fast Python package management, and VS Code Server (code-server).

## Design Philosophy

This is a **minimal base image** - no Python packages are pre-installed. Users install exactly what they need using UV, which is 10-100x faster than pip. This approach:

- Keeps the image small (~3-4 GB vs 8-12 GB)
- Avoids dependency conflicts
- Lets users choose exact package versions
- Supports multiple Python versions via UV

## Features

- **GPU Support**: NVIDIA CUDA 12.2 on Ubuntu 22.04
- **Astral UV**: Lightning-fast Python package manager (10-100x faster than pip)
  - See [official UV documentation](https://docs.astral.sh/uv/) for usage guide
- **IDE Interface**:
  - **VS Code Server** (port 8888): Full-featured code-server interface
  - **JupyterLab**: Optional - users can install via `uv pip install jupyterlab` if needed
- **CUDA Variants**: Choose the right CUDA image for your needs
  - `base`: Minimal CUDA runtime (smallest, ~2GB)
  - `runtime`: Full CUDA runtime (default, ~10GB)
  - `devel`: Development toolkit with nvcc compiler (largest, ~12GB)
- **Kubeflow Compliant**:
  - `jovyan` user (UID 1000, GID 100)
  - Port 8888 exposure
  - NB_PREFIX support
  - s6-overlay for process management
- **CI/CD**: Automated builds and security scanning via GitHub Actions

## Quick Start

### Pull from Docker Hub

```bash
docker pull danieldu28121999/code-server-astraluv:latest
```

### Run Locally

```bash
# CPU
docker run -p 8888:8888 danieldu28121999/code-server-astraluv:latest

# GPU
docker run --gpus all -p 8888:8888 danieldu28121999/code-server-astraluv:latest
```

Access code-server at [http://localhost:8888](http://localhost:8888)

### Install Python and Packages (Inside Container)

```bash
# First, install Python (any version you need)
uv python install 3.11

# Install packages using UV (10-100x faster than pip)
uv pip install pandas numpy matplotlib

# Optional: Install JupyterLab if you need interactive notebooks
uv pip install jupyterlab
jupyter lab --ip=0.0.0.0 --port=8889 --no-browser &

# For detailed UV usage, see: https://docs.astral.sh/uv/
```

### Deploy to Kubeflow

```bash
# CPU-only notebook
kubectl apply -f kubeflow/notebook.yaml

# GPU-enabled notebook
kubectl apply -f kubeflow/notebook-gpu.yaml
```

## Image Variants

All image variants use **Python 3.11** with **CUDA 12.2** and include both code-server and JupyterLab support.

### CUDA Flavor Variants

Choose based on your use case:

| Variant | Size | Use Case | Tag Suffix |
|---------|------|----------|-----------|
| **base** | ~8GB | Minimal CUDA runtime, no compiler | `-cuda12.2-base` |
| **runtime** | ~10GB | Full CUDA runtime (default) | `-cuda12.2-runtime` |
| **devel** | ~12GB | Development toolkit with nvcc compiler | `-cuda12.2-devel` |

**Examples:**
```bash
# Use base variant (smallest)
docker pull danieldu28121999/code-server-astraluv:latest-cuda12.2-base

# Use runtime variant (default)
docker pull danieldu28121999/code-server-astraluv:latest-cuda12.2-runtime

# Use devel variant (for building CUDA extensions)
docker pull danieldu28121999/code-server-astraluv:latest-cuda12.2-devel
```

## IDE Support

The image includes **VS Code Server** (code-server) by default:

### VS Code Server (code-server)
- **Port**: 8888
- **URL**: `http://localhost:8888`
- **Best for**: Full IDE experience, integrated terminal, extensions, Python development
- **Status**: Enabled by default

### JupyterLab (Optional)
If you need interactive notebooks, install JupyterLab inside the container:

```bash
# Install Python first
uv python install 3.11

# Install JupyterLab
uv pip install jupyterlab

# Start JupyterLab on port 8889
jupyter lab --ip=0.0.0.0 --port=8889 --no-browser &
```

Then access both simultaneously:
```bash
docker run -p 8888:8888 -p 8889:8889 --gpus all \
  danieldu28121999/code-server-astraluv:latest

# In container terminal:
uv python install 3.11
uv pip install jupyterlab
jupyter lab --ip=0.0.0.0 --port=8889 --no-browser &

# Now access:
# - code-server: http://localhost:8888
# - JupyterLab: http://localhost:8889
```

## What's Included

### System Tools
- CUDA 12.2 (base image)
- Git, wget, curl
- vim, htop
- build-essential (for compiling packages)

### Pre-installed
- **Astral UV** & **uvx** - From official image, for fast package installation
- **code-server** (4.96.2) - VS Code in browser
- **VS Code extensions**: Python, Jupyter
- **s6-overlay** - Process management

### Not Pre-installed (Install as Needed)
- **Python** - Install any version via UV: `uv python install 3.11`
- **JupyterLab** - Install via: `uv pip install jupyterlab`
- **Python packages** - Install via: `uv pip install <package>`

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NB_USER` | `jovyan` | Username (Kubeflow requirement) |
| `NB_UID` | `1000` | User ID |
| `NB_GID` | `100` | Group ID |
| `HOME` | `/home/jovyan` | Home directory |
| `NB_PREFIX` | `/notebooks/jovyan` | URL prefix for Kubeflow |
| `CUDA_HOME` | `/usr/local/cuda` | CUDA installation path |
| `UV_PYTHON_PREFERENCE` | `managed` | UV uses managed Python |

## Kubeflow Integration

This image is fully compliant with [Kubeflow custom image requirements](https://www.kubeflow.org/docs/components/notebooks/container-images/):

- ✅ Exposes HTTP interface on port 8888
- ✅ Handles `NB_PREFIX` environment variable
- ✅ Runs as `jovyan` user (UID 1000)
- ✅ Home directory at `/home/jovyan`
- ✅ Works with PVC mounts
- ✅ s6-overlay for process management
- ✅ CORS-compatible for iframe embedding

### Deployment Examples

#### Basic CPU Notebook

```yaml
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: my-notebook
  namespace: kubeflow-user
spec:
  template:
    spec:
      containers:
      - name: notebook
        image: danieldu28121999/code-server-astraluv:latest
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
```

#### GPU-Enabled Notebook

```yaml
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: my-gpu-notebook
  namespace: kubeflow-user
spec:
  template:
    spec:
      containers:
      - name: notebook
        image: danieldu28121999/code-server-astraluv:latest
        resources:
          requests:
            memory: "8Gi"
            cpu: "4"
            nvidia.com/gpu: "1"
```

See [kubeflow/](./kubeflow/) directory for complete examples.

## Building from Source

### Clone Repository

```bash
git clone https://github.com/danieldu28121999/kubeflow-notebook-uv.git
cd kubeflow-notebook-uv
```

### Build Image

```bash
./scripts/build.sh v1.0.0
```

### Test Image

```bash
# Test basic functionality
./scripts/test-local.sh

# Test GPU support (requires GPU)
./scripts/test-gpu.sh
```

### Push to Registry

```bash
./scripts/push.sh v1.0.0
```

## Testing

### Run Python Tests

```bash
# Install pytest
pip install pytest pytest-timeout requests

# Run all tests
pytest tests/ -v

# Run specific test suite
pytest tests/test_image.py -v

# Run GPU tests (requires GPU)
pytest tests/test_gpu.py -v -m gpu
```

### Manual Testing

```bash
# Start container
docker run -d --name test -p 8888:8888 danieldu28121999/code-server-astraluv:latest

# Check UV
docker exec test uv --version

# Check Python versions
docker exec test uv python list

# Install a package
docker exec test uv pip install --system requests

# Cleanup
docker rm -f test
```

## GPU Support

### Install PyTorch with CUDA

```bash
# Inside the container
uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu122
```

### Verify GPU Access

```python
import torch

print(f"CUDA available: {torch.cuda.is_available()}")
print(f"CUDA version: {torch.version.cuda}")
print(f"GPU count: {torch.cuda.device_count()}")
print(f"GPU name: {torch.cuda.get_device_name(0)}")

# Test computation
x = torch.rand(1000, 1000).cuda()
y = torch.rand(1000, 1000).cuda()
z = torch.matmul(x, y)
print(f"Computation device: {z.device}")
```

### Requirements
- NVIDIA GPU with CUDA Compute Capability 3.5+
- NVIDIA Driver 450.80.02+
- nvidia-docker2 (for local Docker)
- NVIDIA GPU Operator (for Kubernetes)

## CI/CD

This project uses GitHub Actions for automated builds and security scanning.

### Workflows

- **Build and Push**: Triggered on push to main/master or version tags
- **Security Scan**: Weekly vulnerability scanning with Trivy

### Release Process

```bash
# Create a new release
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# GitHub Actions will automatically:
# - Build the image
# - Tag with v1.0.0, v1.0, v1, latest
# - Push to Docker Hub
# - Run security scans
# - Generate SBOM
```

### Required Secrets

Configure these in GitHub repository settings:

- `DOCKER_HUB_USERNAME`: Your Docker Hub username
- `DOCKER_HUB_TOKEN`: Docker Hub access token

## Troubleshooting

### Code-server not loading

Check container logs:
```bash
docker logs <container-name>
```

### GPU not detected

Verify nvidia-docker2 is installed:
```bash
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

### Permission denied on /home/jovyan

This usually happens with PVC mounts:
```bash
kubectl exec -it <pod-name> -- sudo chown -R jovyan:users /home/jovyan
```

### Package installation fails

Use UV instead of pip:
```bash
uv pip install <package-name>
```

For packages requiring compilation:
```bash
# build-essential is pre-installed
uv pip install <package-name>
```

## Image Details

| Property | Value |
|----------|-------|
| **Base Image** | nvidia/cuda:12.2.0-base-ubuntu22.04 |
| **UV Source** | ghcr.io/astral-sh/uv:latest (multi-stage) |
| **Image Size** | ~9.5 GB (minimal, no pre-installed Python) |
| **Python** | None pre-installed (install via UV) |
| **User** | jovyan (UID 1000, GID 100) |
| **Port** | 8888 (code-server) |
| **Entrypoint** | s6-overlay (/init) |

## Tags

- `latest` - Latest stable build from main branch
- `v1.0.0` - Semantic version tags
- `v1.0` - Major.minor tags
- `v1` - Major version tags

## Security

- Runs as non-root user (`jovyan`)
- Weekly security scans via Trivy
- SBOM generation for supply chain security
- No hardcoded secrets
- Minimal base image (CUDA base, not devel)
- UV copied from official verified image

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/danieldu28121999/kubeflow-notebook-uv/issues)
- **Documentation**: See [wiki/](./wiki/) directory
- **Kubeflow Docs**: [Kubeflow Notebooks](https://www.kubeflow.org/docs/components/notebooks/)

## Acknowledgments

- Based on [NVIDIA CUDA](https://hub.docker.com/r/nvidia/cuda) base images
- UV from [Astral](https://github.com/astral-sh/uv) official Docker image
- Powered by [code-server](https://github.com/coder/code-server)
- Process management via [s6-overlay](https://github.com/just-containers/s6-overlay)

---

**Built for the Kubeflow community**
