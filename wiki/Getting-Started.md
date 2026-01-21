# Getting Started (5 Minutes)

Get the code-server-astraluv image running in just 5 minutes!

## Prerequisites

- Docker installed and running
- 8GB+ disk space (for image download)
- (Optional) NVIDIA GPU with `nvidia-docker` or `docker --gpus`

## Option 1: Using Pre-Built Image (Fastest)

### 1. Pull from Docker Hub

```bash
docker pull danieldu28121999/code-server-astraluv:latest
```

**Image size**: ~8-12GB (depending on CUDA variant)

### 2. Run the Container

```bash
# Basic run (CPU only)
docker run -p 8888:8888 -p 8889:8889 \
  danieldu28121999/code-server-astraluv:latest

# With GPU support
docker run --gpus all -p 8888:8888 -p 8889:8889 \
  danieldu28121999/code-server-astraluv:latest

# With volume mount for persistent data
docker run -v $(pwd):/home/jovyan/project \
  -p 8888:8888 -p 8889:8889 --gpus all \
  danieldu28121999/code-server-astraluv:latest
```

### 3. Access the Services

Open your browser:

- **VS Code (code-server)**: http://localhost:8888
- **JupyterLab**: http://localhost:8889

### 4. Verify Installation

From another terminal:

```bash
# Check code-server
curl http://localhost:8888/

# Check JupyterLab
curl http://localhost:8889/

# Check logs
docker logs $(docker ps -q)
```

### 5. Stop the Container

```bash
docker stop $(docker ps -q)
```

---

## Option 2: Build Locally

### 1. Clone Repository

```bash
git clone https://github.com/danghoangnhan/kubeflow-notebook-uv.git
cd kubeflow-notebook-uv
```

### 2. Build Base Variant

```bash
./scripts/build.sh latest --cuda-flavor base
```

**Build time**: 10-15 minutes

### 3. Run Your Build

```bash
docker run -p 8888:8888 -p 8889:8889 \
  code-server-astraluv:latest
```

### 4. Access Services

Same as Option 1 - http://localhost:8888 and http://localhost:8889

---

## First Steps Inside the Container

### Install Your First Package

```bash
# Install UV first (already included)
uv --version

# Install data science tools
uv pip install pandas numpy matplotlib

# Or install deep learning framework
uv pip install torch torchvision --index-url https://download.pytorch.org/whl/cu122
```

### Create a Virtual Environment

```bash
uv venv myenv
source myenv/bin/activate

# Install packages in this environment
uv pip install -r requirements.txt
```

### Check Python Versions

```bash
# List installed Python versions
uv python list

# Install another Python version
uv python install 3.12
```

### Try Both IDEs

**In VS Code (port 8888):**
- Create a new file: `File → New File`
- Write Python code and execute

**In JupyterLab (port 8889):**
- Create a new notebook: `File → New → Notebook`
- Write and execute code cells

### Check GPU (if available)

```bash
# Check NVIDIA tools
nvidia-smi

# Check PyTorch GPU support (after installing torch)
python -c "import torch; print(torch.cuda.is_available())"
```

---

## Common Commands

| Command | Purpose |
|---------|---------|
| `uv pip install <package>` | Install Python package |
| `uv python list` | List available Python versions |
| `uv python install 3.12` | Install Python 3.12 |
| `uv venv myenv` | Create virtual environment |
| `source myenv/bin/activate` | Activate environment |

---

## Next Steps

- **Learn more UV commands**: See [Usage Guide](Usage-Guide)
- **Deploy to Kubeflow**: See [Kubeflow Deployment](Kubeflow-Deployment)
- **Understand CUDA variants**: See [Image Variants](Image-Variants)
- **Having issues?**: See [Troubleshooting](Troubleshooting)

---

## Tips & Tricks

### Mount Local Directory

Keep files between container runs:

```bash
docker run -v /path/to/local/dir:/home/jovyan/project \
  -p 8888:8888 -p 8889:8889 \
  code-server-astraluv:latest
```

### Set Memory Limit

Prevent runaway processes:

```bash
docker run -m 8g --cpus 4 \
  -p 8888:8888 -p 8889:8889 \
  code-server-astraluv:latest
```

### Keep Container Running

For background development:

```bash
docker run -d --name mynotebook \
  -p 8888:8888 -p 8889:8889 \
  code-server-astraluv:latest

# View logs
docker logs mynotebook

# Stop later
docker stop mynotebook
```

### Run with Bash Access

For debugging:

```bash
docker run -it code-server-astraluv:latest bash
```

---

## Choosing CUDA Variant

For first-time users, start with `base`:

```bash
docker pull danieldu28121999/code-server-astraluv:latest-cuda12.2-base
```

**Variants:**
- `base` (default tag): Smallest, sufficient for most uses
- `runtime`: Full CUDA runtime
- `devel`: Has compiler (`nvcc`) for building CUDA extensions

See [Image Variants](Image-Variants) for detailed comparison.

---

## Performance Expectations

| Metric | Expected |
|--------|----------|
| Pull time | 5-10 min (first time) |
| Container startup | 20-30 sec |
| code-server ready | 30-60 sec |
| JupyterLab ready | 30-60 sec |
| First `uv pip install` | 30-60 sec |
| Subsequent installs | 5-15 sec |

---

## Troubleshooting Quick Start

**Container won't start?**
- Check disk space: `df -h`
- Check Docker: `docker ps -a`
- View logs: `docker logs <container-id>`

**Services not responding?**
- Wait 30 seconds for startup
- Check ports: `docker ps`
- Try: `curl http://localhost:8888/`

**GPU not working?**
- Check Docker GPU: `docker run --gpus all nvidia/cuda:12.2.0-runtime-ubuntu22.04 nvidia-smi`
- Install nvidia-docker if needed

See [Troubleshooting](Troubleshooting) for more issues.

---

**Ready to dive deeper?** Check out the [Usage Guide](Usage-Guide)!
