# Usage Guide

Comprehensive guide for using code-server-astraluv in your daily workflows.

## Table of Contents

1. [VS Code (code-server)](#vs-code-code-server)
2. [JupyterLab](#jupyterlab)
3. [Package Management with UV](#package-management-with-uv)
4. [GPU Workflows](#gpu-workflows)
5. [Working with Multiple Python Versions](#working-with-multiple-python-versions)
6. [Tips & Tricks](#tips--tricks)

---

## VS Code (code-server)

### Accessing code-server

Open your browser and navigate to `http://localhost:8888`

### Installing Extensions

code-server supports most VS Code extensions via the Extensions sidebar (Ctrl+Shift+X) or CLI:

```bash
code-server --install-extension ms-python.python
code-server --install-extension ms-python.vscode-pylance
code-server --install-extension DavidAnson.vscode-markdownlint
```

### Creating and Running Python Files

1. File → New File → `script.py`
2. Write your code
3. Open terminal (Ctrl+`) and run: `python script.py`

### Debugging

1. Set breakpoints by clicking line numbers
2. Open Run/Debug (Ctrl+Shift+D)
3. Press F5 to start debugging

---

## JupyterLab

### Accessing JupyterLab

Navigate to `http://localhost:8889`

### Creating Notebooks

1. File → New → Notebook
2. Select Python kernel
3. Start writing code in cells

### Cell Operations

- Execute: Shift+Enter
- Insert below: Ctrl+M, B
- Delete: Ctrl+M, X
- Convert to markdown: Ctrl+M, M

### Example Notebook

```python
# Cell 1: Imports
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# Cell 2: Data
df = pd.DataFrame({
    'x': np.linspace(0, 10, 50),
    'y': np.sin(np.linspace(0, 10, 50))
})
print(df.head())

# Cell 3: Plot
plt.plot(df['x'], df['y'])
plt.xlabel('X')
plt.ylabel('Sin(X)')
plt.show()
```

---

## Package Management with UV

UV is a modern Python package manager - **10-100x faster than pip**.

### Basic Commands

```bash
# Install package
uv pip install pandas

# Install specific version
uv pip install numpy==1.24.0

# Install from file
uv pip install -r requirements.txt

# List packages
uv pip list
```

### Python Version Management

```bash
# List available versions
uv python list

# Install version
uv python install 3.12

# Pin for project
uv python pin 3.12
```

### Virtual Environments

```bash
# Create
uv venv myproject
source myproject/bin/activate

# Install packages
uv pip install -r requirements.txt

# Deactivate
deactivate
```

### Project Configuration (pyproject.toml)

```toml
[project]
name = "my-project"
version = "0.1.0"
requires-python = ">=3.10"

dependencies = [
    "pandas>=2.0.0",
    "numpy>=1.24.0",
    "torch>=2.0.0",
]

[project.optional-dependencies]
dev = ["pytest>=7.0", "ruff>=0.1.0"]
```

Usage:
```bash
uv pip install -e .              # Install project
uv pip install -e ".[dev]"       # With dev tools
```

---

## GPU Workflows

### Check GPU Availability

```bash
nvidia-smi

# From Python
python -c "import torch; print(torch.cuda.is_available())"
```

### Install GPU Packages

```bash
# PyTorch with GPU
uv pip install torch --index-url https://download.pytorch.org/whl/cu122

# TensorFlow with GPU
uv pip install tensorflow[and-cuda]
```

### GPU Example (PyTorch)

```python
import torch

# Create tensors
x = torch.randn(1000, 1000, device='cuda')
y = torch.randn(1000, 1000, device='cuda')

# Compute
z = torch.mm(x, y)
print(z.shape)

# Memory
print(f"Allocated: {torch.cuda.memory_allocated() / 1e9:.2f} GB")
torch.cuda.empty_cache()  # Clear cache
```

---

## Working with Multiple Python Versions

```bash
# Install version
uv python install 3.12

# Create venv with specific version
uv venv --python 3.12 py312-env
source py312-env/bin/activate

# Run script with specific version
uv python -p 3.12 script.py
```

---

## Tips & Tricks

### Mount Persistent Storage

```bash
docker run -v /path/to/data:/home/jovyan/data \
  -p 8888:8888 -p 8889:8889 \
  code-server-astraluv:latest
```

### Resource Limits

```bash
docker run -m 16g --cpus 8 \
  -p 8888:8888 -p 8889:8889 \
  code-server-astraluv:latest
```

### View Logs

```bash
docker logs -f container-name
docker logs --tail 50 container-name
```

### Execute Commands

```bash
docker exec container-name python -c "import torch; print(torch.cuda.is_available())"
docker exec -it container-name bash
```

### Docker Compose

```yaml
version: '3.8'
services:
  notebook:
    image: danieldu28121999/code-server-astraluv:latest
    ports:
      - "8888:8888"
      - "8889:8889"
    volumes:
      - ./project:/home/jovyan/project
    deploy:
      resources:
        limits:
          memory: 16G
          cpus: '8'
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

Run: `docker-compose up -d`

---

**Next Steps**: [Kubeflow Deployment](Kubeflow-Deployment) | [Troubleshooting](Troubleshooting) | [Contributing](Contributing)
