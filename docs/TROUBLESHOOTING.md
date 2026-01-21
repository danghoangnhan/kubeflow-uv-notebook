# Troubleshooting Guide

Common issues and solutions for the Kubeflow Notebook with Astral UV.

## Table of Contents

- [Container Issues](#container-issues)
- [Code-Server Issues](#code-server-issues)
- [GPU Issues](#gpu-issues)
- [Kubeflow Issues](#kubeflow-issues)
- [Package Management Issues](#package-management-issues)
- [Permission Issues](#permission-issues)

## Container Issues

### Container Fails to Start

**Symptoms**: Container exits immediately after starting

**Diagnosis**:
```bash
# Check container logs
docker logs <container-name>

# Check container status
docker ps -a | grep <container-name>
```

**Common Causes**:
1. Port 8888 already in use
2. Insufficient memory
3. s6-overlay initialization failure

**Solutions**:
```bash
# Use a different port
docker run -p 9999:8888 danieldu28121999/kubeflow-notebook-uv:latest

# Allocate more memory
docker run -m 4g danieldu28121999/kubeflow-notebook-uv:latest

# Check s6-overlay logs
docker logs <container-name> 2>&1 | grep s6
```

### Container Runs but Services Don't Start

**Symptoms**: Container running but code-server not accessible

**Diagnosis**:
```bash
# Check if code-server process is running
docker exec <container-name> ps aux | grep code-server

# Check s6 service status
docker exec <container-name> s6-svstat /var/run/s6/services/code-server
```

**Solution**:
```bash
# Restart container
docker restart <container-name>

# Check init logs
docker logs <container-name> | grep cont-init
```

## Code-Server Issues

### Code-Server Not Loading in Browser

**Symptoms**: Browser shows "Connection refused" or timeout

**Check List**:
1. Verify container is running: `docker ps`
2. Verify port mapping: `docker port <container-name>`
3. Test connectivity: `curl http://localhost:8888`

**Solutions**:
```bash
# Check if port is accessible
curl -v http://localhost:8888

# Check firewall rules
sudo ufw status
sudo firewall-cmd --list-ports

# Try different port
docker run -p 8889:8888 danieldu28121999/kubeflow-notebook-uv:latest
```

### Code-Server Slow or Unresponsive

**Symptoms**: Code-server loads but is very slow

**Solutions**:
```bash
# Allocate more CPU and memory
docker run -m 8g --cpus 4 danieldu28121999/kubeflow-notebook-uv:latest

# Check resource usage
docker stats <container-name>

# Restart code-server service
docker exec <container-name> s6-svc -r /var/run/s6/services/code-server
```

### VS Code Extensions Not Working

**Symptoms**: Extensions installed but not functional

**Solutions**:
```bash
# List installed extensions
docker exec <container-name> code-server --list-extensions

# Reinstall extensions
docker exec -u jovyan <container-name> code-server --install-extension ms-python.python --force

# Check extension directory
docker exec <container-name> ls -la /home/jovyan/.local/share/code-server/extensions
```

## GPU Issues

### GPU Not Detected

**Symptoms**: `torch.cuda.is_available()` returns `False`

**Check Host GPU**:
```bash
# On host machine
nvidia-smi

# Check Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

**Common Causes**:
1. nvidia-docker2 not installed
2. NVIDIA driver not loaded
3. Container not started with `--gpus` flag

**Solutions**:
```bash
# Install nvidia-docker2 (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker

# Run container with GPU
docker run --gpus all danieldu28121999/kubeflow-notebook-uv:latest

# Verify GPU in container
docker run --rm --gpus all danieldu28121999/kubeflow-notebook-uv:latest nvidia-smi
```

### CUDA Out of Memory

**Symptoms**: `RuntimeError: CUDA out of memory`

**Solutions**:
```python
# Clear GPU cache
import torch
torch.cuda.empty_cache()

# Use smaller batch sizes
batch_size = 16  # Try reducing this

# Use gradient accumulation
for i, batch in enumerate(dataloader):
    loss = model(batch)
    loss.backward()

    if (i + 1) % accumulation_steps == 0:
        optimizer.step()
        optimizer.zero_grad()
```

### Multiple GPUs Not Visible

**Symptoms**: Only one GPU visible when multiple GPUs available

**Solutions**:
```bash
# Expose all GPUs
docker run --gpus all danieldu28121999/kubeflow-notebook-uv:latest

# Expose specific GPUs
docker run --gpus '"device=0,1"' danieldu28121999/kubeflow-notebook-uv:latest

# Check visible devices
docker exec <container-name> nvidia-smi -L
```

## Kubeflow Issues

### Notebook Not Loading in Kubeflow UI

**Symptoms**: Notebook shows "Loading..." indefinitely

**Check**:
```bash
# Check pod status
kubectl get pods -n kubeflow-user | grep <notebook-name>

# Check pod logs
kubectl logs -n kubeflow-user <pod-name>

# Describe pod
kubectl describe pod -n kubeflow-user <pod-name>
```

**Common Causes**:
1. Image pull failure
2. Resource constraints
3. NB_PREFIX misconfiguration

**Solutions**:
```bash
# Check image pull status
kubectl get events -n kubeflow-user | grep <pod-name>

# Increase resources
kubectl edit notebook -n kubeflow-user <notebook-name>
# Update resource limits

# Check NB_PREFIX
kubectl logs -n kubeflow-user <pod-name> | grep NB_PREFIX
```

### IFrame Not Loading in Kubeflow

**Symptoms**: Notebook shows blank iframe or access denied

**Solutions**:
1. Verify CORS headers are set correctly
2. Check NB_PREFIX is being used
3. Ensure auth is disabled in code-server

```bash
# Check code-server configuration
kubectl exec -it -n kubeflow-user <pod-name> -- cat /etc/code-server/config.yaml

# Verify no X-Frame-Options blocking
kubectl exec -it -n kubeflow-user <pod-name> -- curl -I http://localhost:8888
```

### PVC Mount Issues

**Symptoms**: Files not persisting after pod restart

**Check PVC**:
```bash
# List PVCs
kubectl get pvc -n kubeflow-user

# Check PVC status
kubectl describe pvc -n kubeflow-user <pvc-name>

# Check mount in pod
kubectl exec -it -n kubeflow-user <pod-name> -- df -h | grep jovyan
```

**Solutions**:
```bash
# Recreate PVC
kubectl delete pvc -n kubeflow-user <pvc-name>
kubectl apply -f kubeflow/notebook-gpu.yaml

# Fix permissions
kubectl exec -it -n kubeflow-user <pod-name> -- chown -R jovyan:users /home/jovyan
```

## Package Management Issues

### UV Command Not Found

**Symptoms**: `bash: uv: command not found`

**Solutions**:
```bash
# Check UV installation
docker exec <container-name> which uv

# Check PATH
docker exec <container-name> echo $PATH

# Reinstall UV (if necessary)
docker exec <container-name> bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh"
```

### Pip Install Fails

**Symptoms**: Package installation errors

**Solutions**:
```bash
# Use UV instead of pip (faster and more reliable)
uv pip install <package-name>

# Update pip
pip install --upgrade pip

# Use --no-cache-dir for space issues
pip install --no-cache-dir <package-name>

# Install in user directory
pip install --user <package-name>
```

### Conflicting Dependencies

**Symptoms**: Package dependency resolution errors

**Solutions**:
```bash
# Use UV for better dependency resolution
uv pip install <package-name>

# Create a clean virtual environment
uv venv myenv
source myenv/bin/activate
uv pip install <packages>

# Use pip-tools
pip install pip-tools
pip-compile requirements.in
pip-sync requirements.txt
```

## Permission Issues

### Permission Denied in /home/jovyan

**Symptoms**: Cannot write files to home directory

**Check**:
```bash
# Check ownership
docker exec <container-name> ls -la /home/jovyan

# Check user
docker exec <container-name> whoami
docker exec <container-name> id
```

**Solutions**:
```bash
# Fix ownership
docker exec -u root <container-name> chown -R jovyan:users /home/jovyan

# For Kubeflow
kubectl exec -it -n kubeflow-user <pod-name> -- bash
sudo chown -R jovyan:users /home/jovyan
```

### Cannot Install System Packages

**Symptoms**: `apt-get` commands fail with permission denied

**Solution**:
```bash
# System packages should be installed in Dockerfile
# For temporary testing, use sudo
docker exec -u root <container-name> apt-get update
docker exec -u root <container-name> apt-get install -y <package>

# Or exec as root
docker exec -it -u root <container-name> bash
```

## General Debugging

### Get Detailed Logs

```bash
# Container logs
docker logs -f <container-name>

# s6-overlay logs
docker exec <container-name> cat /var/log/s6-*

# code-server logs
docker exec <container-name> cat /home/jovyan/.local/share/code-server/logs/*
```

### Check Resource Usage

```bash
# Docker stats
docker stats <container-name>

# Inside container
docker exec <container-name> top
docker exec <container-name> free -h
docker exec <container-name> df -h
```

### Test Network Connectivity

```bash
# From host
curl -v http://localhost:8888

# From container
docker exec <container-name> curl http://localhost:8888

# DNS resolution
docker exec <container-name> nslookup google.com
```

## Still Having Issues?

1. Check the [README](../README.md) for basic setup
2. Review [TESTING.md](./TESTING.md) for validation steps
3. Open an issue on [GitHub](https://github.com/danieldu28121999/kubeflow-notebook-uv/issues)
4. Include:
   - Container/pod logs
   - Output of `docker version` or `kubectl version`
   - Output of `nvidia-smi` (for GPU issues)
   - Steps to reproduce
