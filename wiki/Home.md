# code-server-astraluv Wiki

Welcome to the **code-server-astraluv** project documentation! This is a production-ready Docker image for Kubeflow notebooks with GPU/CUDA support, Astral UV for fast Python package management, and both VS Code Server and JupyterLab interfaces.

## 🚀 Quick Links

- **[Getting Started](Getting-Started)** - 5-minute quick start guide
- **[Installation & Build](Installation-&-Build)** - Build from source locally
- **[Image Variants](Image-Variants)** - Understanding CUDA flavors
- **[Usage Guide](Usage-Guide)** - Using code-server and JupyterLab
- **[Kubeflow Deployment](Kubeflow-Deployment)** - Deploy to Kubeflow clusters
- **[Testing](Testing)** - Comprehensive testing guide
- **[Troubleshooting](Troubleshooting)** - Common issues and solutions
- **[Contributing](Contributing)** - How to contribute

## 📋 Project Overview

### What is code-server-astraluv?

A minimal, production-ready Docker image combining:

| Component | Details |
|-----------|---------|
| **Base OS** | Ubuntu 22.04 |
| **GPU Support** | NVIDIA CUDA 12.2 |
| **IDE Interfaces** | VS Code (8888) + JupyterLab (8889) |
| **Package Manager** | Astral UV (10-100x faster than pip) |
| **Python** | 3.11 (managed by UV) |
| **Process Manager** | s6-overlay for multi-service |
| **Kubeflow** | Full compatibility (jovyan user, NB_PREFIX) |

### Key Features

✅ **Dual IDE Support**
- VS Code Server (code-server) on port 8888
- JupyterLab on port 8889
- Both run simultaneously

✅ **CUDA Variants**
- `base`: Minimal runtime (~8GB)
- `runtime`: Full runtime (~10GB, default)
- `devel`: Development toolkit (~12GB)

✅ **Production Ready**
- Non-root user (jovyan)
- Security scanning (Trivy)
- s6-overlay for proper process management
- Health checks configured

✅ **Developer Friendly**
- UV for fast dependency management
- Git, curl, build tools included
- Kubeflow-compatible out of the box

## 🎯 Design Philosophy

**Minimal is Better**

This is not a "batteries included" image. Instead:

- Only Python 3.11 and UV are pre-installed
- Users install packages exactly as needed: `uv pip install torch pandas numpy`
- Image stays smaller and faster to build
- Flexibility: choose your dependencies
- Easier updates: no breaking package changes

## 📊 Image Specifications

```
Name:               code-server-astraluv
Base Image:         nvidia/cuda:12.2.0-${CUDA_FLAVOR}-ubuntu22.04
User:               jovyan (UID: 1000, GID: 100)
Python:             3.11 (managed by UV)
code-server:        v4.96.2
JupyterLab:         Latest (via UV)
s6-overlay:         v3.1.6.2
Ports Exposed:      8888 (code-server), 8889 (JupyterLab)
Registry:           Docker Hub (danieldu28121999/code-server-astraluv)
```

## 🔄 CI/CD Pipeline

Automated with GitHub Actions:

- **Tag Releases** (v2.0.0):
  - Builds all 3 CUDA variants
  - Pushes to Docker Hub
  - Semantic versioning (v2.0.0, 2.0.0, 2.0, latest)
  - Trivy security scanning

- **Main Branch**:
  - Builds base variant on every push
  - Runs security scans
  - Non-destructive testing

## 📚 Documentation Structure

| Page | Purpose |
|------|---------|
| Getting Started | 5-minute quickstart |
| Installation & Build | Local build instructions |
| Image Variants | CUDA flavor comparison |
| Usage Guide | IDE usage & UV examples |
| Kubeflow Deployment | Deployment manifests & setup |
| Testing | Test strategies & automation |
| Troubleshooting | Common issues & solutions |
| Contributing | Development guidelines |

## 🤔 Common Questions

**Q: Why such a minimal image?**
A: Smaller size, faster builds, better flexibility, and easier updates. Users install exactly what they need.

**Q: Can I use my own packages?**
A: Yes! Install anything via UV: `uv pip install my-package`. See [Usage Guide](Usage-Guide) for examples.

**Q: Which CUDA variant should I use?**
A: Start with `base` (smallest). Use `runtime` if you need full CUDA. Use `devel` if compiling CUDA extensions.

**Q: How do I access both interfaces?**
A: Start container with both ports: `-p 8888:8888 -p 8889:8889`. Access code-server at :8888, JupyterLab at :8889.

**Q: Is this production-ready?**
A: Yes! Non-root user, security scanning, proper process management, Kubeflow-compatible.

## 🚀 Getting Started

### Quickest Start (5 minutes)

```bash
# Pull from Docker Hub
docker pull danieldu28121999/code-server-astraluv:latest

# Run with GPU support
docker run -p 8888:8888 -p 8889:8889 --gpus all \
  danieldu28121999/code-server-astraluv:latest

# Access:
# code-server: http://localhost:8888
# JupyterLab: http://localhost:8889
```

### Build Locally

```bash
./scripts/build.sh latest --cuda-flavor base
docker run -p 8888:8888 -p 8889:8889 code-server-astraluv:latest
```

### Deploy to Kubeflow

See [Kubeflow Deployment](Kubeflow-Deployment) for complete examples.

## 📊 Version Information

| Component | Version |
|-----------|---------|
| CUDA | 12.2.0 |
| Ubuntu | 22.04 |
| code-server | v4.96.2 |
| s6-overlay | v3.1.6.2 |
| UV | Latest |
| Python | 3.11 |

## 🔐 Security

- **Non-root user**: Runs as `jovyan` (UID 1000)
- **Minimal attack surface**: Only essential packages
- **Regular scanning**: Trivy scans on every build
- **No hardcoded secrets**: Auth handled by Kubeflow
- **SARIF reports**: Security findings in GitHub

## 📝 License

MIT License - See [LICENSE](https://github.com/danghoangnhan/kubeflow-notebook-uv/blob/main/LICENSE) for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/danghoangnhan/kubeflow-notebook-uv/issues)
- **Discussions**: [GitHub Discussions](https://github.com/danghoangnhan/kubeflow-notebook-uv/discussions)
- **Wiki**: You're reading it!

## 📈 Project Status

- **Version**: 2.0.0+
- **Status**: Production Ready ✅
- **Maintenance**: Active
- **Last Updated**: January 2024

---

**Next Steps:**
- New to the project? Start with [Getting Started](Getting-Started)
- Want to build locally? Go to [Installation & Build](Installation-&-Build)
- Ready to deploy? Check [Kubeflow Deployment](Kubeflow-Deployment)
- Have issues? See [Troubleshooting](Troubleshooting)
