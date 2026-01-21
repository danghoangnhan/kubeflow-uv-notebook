# Testing Guide

Comprehensive testing procedures for the Kubeflow Notebook with Astral UV image.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Local Testing](#local-testing)
- [GPU Testing](#gpu-testing)
- [Automated Testing](#automated-testing)
- [Kubeflow Testing](#kubeflow-testing)
- [Performance Testing](#performance-testing)

## Prerequisites

### Required Tools

```bash
# Docker
docker --version  # Should be 20.10+

# For GPU testing
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi

# For Python tests
pip install pytest pytest-timeout requests
```

### Build the Image

```bash
./scripts/build.sh v1.0.0
```

## Local Testing

### Quick Test Script

The fastest way to test basic functionality:

```bash
./scripts/test-local.sh
```

This runs:
- Container startup test
- Code-server accessibility test
- Python version check
- UV installation check
- Jupyter installation check
- Package availability check
- User permissions check
- Home directory check
- VS Code extensions check

### Manual Testing

```bash
# Start container
docker run -d --name test-notebook -p 8888:8888 danieldu28121999/kubeflow-notebook-uv:latest

# Wait for services to start
sleep 15

# Test 1: Container is running
docker ps | grep test-notebook

# Test 2: Code-server responds
curl -s http://localhost:8888 | head -n 10

# Test 3: Python works
docker exec test-notebook python --version

# Test 4: UV works
docker exec test-notebook uv --version

# Test 5: Jupyter works
docker exec test-notebook jupyter --version

# Test 6: Import data science libraries
docker exec test-notebook python -c "
import numpy as np
import pandas as pd
import torch
import sklearn
print('All imports successful!')
"

# Test 7: User is jovyan
docker exec test-notebook whoami

# Test 8: Home directory
docker exec test-notebook bash -c 'echo $HOME'

# Cleanup
docker rm -f test-notebook
```

### Interactive Testing

```bash
# Start container
docker run -it --rm -p 8888:8888 danieldu28121999/kubeflow-notebook-uv:latest bash

# Inside container, test various components
python --version
uv --version
jupyter --version
code-server --version

# Test UV
uv venv testenv
source testenv/bin/activate
uv pip install requests
python -c "import requests; print(requests.__version__)"

# Exit
exit
```

## GPU Testing

### Quick GPU Test Script

```bash
./scripts/test-gpu.sh
```

This tests:
- nvidia-smi accessibility
- PyTorch CUDA availability
- GPU computation
- Memory allocation

### Manual GPU Testing

```bash
# Start container with GPU
docker run -d --name test-gpu --gpus all -p 8888:8888 danieldu28121999/kubeflow-notebook-uv:latest

# Test 1: nvidia-smi works
docker exec test-gpu nvidia-smi

# Test 2: CUDA is available in PyTorch
docker exec test-gpu python -c "
import torch
assert torch.cuda.is_available(), 'CUDA not available'
print(f'CUDA version: {torch.version.cuda}')
print(f'GPU count: {torch.cuda.device_count()}')
print(f'GPU name: {torch.cuda.get_device_name(0)}')
"

# Test 3: GPU computation
docker exec test-gpu python -c "
import torch
import time

# Create tensors on GPU
x = torch.rand(1000, 1000).cuda()
y = torch.rand(1000, 1000).cuda()

# Benchmark
start = time.time()
z = torch.matmul(x, y)
torch.cuda.synchronize()
end = time.time()

print(f'Matrix multiplication time: {(end-start)*1000:.2f} ms')
print(f'Result device: {z.device}')
"

# Test 4: Memory management
docker exec test-gpu python -c "
import torch

# Allocate memory
tensor = torch.zeros(100, 100, 100).cuda()
print(f'Memory allocated: {torch.cuda.memory_allocated(0) / 1024**2:.2f} MB')

# Clear cache
torch.cuda.empty_cache()
print('Cache cleared')
"

# Cleanup
docker rm -f test-gpu
```

### GPU Benchmark

```bash
docker run --rm --gpus all danieldu28121999/kubeflow-notebook-uv:latest python -c "
import torch
import time

sizes = [100, 500, 1000, 2000]

print('Matrix Multiplication Benchmark (GPU)')
print('=' * 50)

for size in sizes:
    x = torch.rand(size, size).cuda()
    y = torch.rand(size, size).cuda()

    # Warmup
    for _ in range(10):
        _ = torch.matmul(x, y)
    torch.cuda.synchronize()

    # Benchmark
    start = time.time()
    for _ in range(100):
        z = torch.matmul(x, y)
    torch.cuda.synchronize()
    end = time.time()

    avg_time = (end - start) / 100 * 1000
    print(f'{size}x{size}: {avg_time:.3f} ms')
"
```

## Automated Testing

### Python Test Suite

Install test dependencies:
```bash
pip install pytest pytest-timeout requests
```

Run all tests:
```bash
pytest tests/ -v
```

Run specific test files:
```bash
# Image tests
pytest tests/test_image.py -v -s

# GPU tests (requires GPU)
pytest tests/test_gpu.py -v -s -m gpu

# Kubeflow tests
pytest tests/test_kubeflow.py -v -s
```

### Test Coverage

```bash
# Install coverage
pip install pytest-cov

# Run with coverage
pytest tests/ --cov=. --cov-report=html

# View report
open htmlcov/index.html
```

### Continuous Testing

```bash
# Watch for changes and rerun tests
pip install pytest-watch

# Run
ptw tests/ -- -v
```

## Kubeflow Testing

### Deploy Test Notebook

```bash
# Deploy GPU notebook
kubectl apply -f kubeflow/notebook-gpu.yaml

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod -l app=kubeflow-notebook-uv-gpu -n kubeflow-user --timeout=300s

# Get pod name
POD_NAME=$(kubectl get pods -n kubeflow-user -l app=kubeflow-notebook-uv-gpu -o jsonpath='{.items[0].metadata.name}')
```

### Test in Kubeflow

```bash
# Test 1: Pod is running
kubectl get pod -n kubeflow-user $POD_NAME

# Test 2: Check logs
kubectl logs -n kubeflow-user $POD_NAME

# Test 3: Service is ready
kubectl port-forward -n kubeflow-user $POD_NAME 8888:8888 &
sleep 5
curl -s http://localhost:8888 | head -n 10

# Test 4: GPU is accessible
kubectl exec -it -n kubeflow-user $POD_NAME -- nvidia-smi

# Test 5: PyTorch CUDA works
kubectl exec -it -n kubeflow-user $POD_NAME -- python -c "
import torch
assert torch.cuda.is_available()
print(f'GPU: {torch.cuda.get_device_name(0)}')
"

# Test 6: User is jovyan
kubectl exec -it -n kubeflow-user $POD_NAME -- whoami

# Test 7: Home directory is correct
kubectl exec -it -n kubeflow-user $POD_NAME -- bash -c 'echo $HOME'

# Test 8: PVC is mounted
kubectl exec -it -n kubeflow-user $POD_NAME -- df -h | grep jovyan

# Test 9: NB_PREFIX is set
kubectl exec -it -n kubeflow-user $POD_NAME -- bash -c 'echo $NB_PREFIX'
```

### Test Persistence

```bash
# Create a test file
kubectl exec -it -n kubeflow-user $POD_NAME -- bash -c 'echo "test data" > /home/jovyan/test.txt'

# Delete and recreate pod
kubectl delete pod -n kubeflow-user $POD_NAME
kubectl wait --for=condition=Ready pod -l app=kubeflow-notebook-uv-gpu -n kubeflow-user --timeout=300s

# Get new pod name
POD_NAME=$(kubectl get pods -n kubeflow-user -l app=kubeflow-notebook-uv-gpu -o jsonpath='{.items[0].metadata.name}')

# Verify file persists
kubectl exec -it -n kubeflow-user $POD_NAME -- cat /home/jovyan/test.txt
```

### Access via Kubeflow UI

1. Open Kubeflow dashboard
2. Navigate to Notebooks
3. Find your notebook
4. Click "CONNECT"
5. Verify code-server loads in iframe
6. Test GPU in terminal:
   ```bash
   nvidia-smi
   python -c "import torch; print(torch.cuda.is_available())"
   ```

## Performance Testing

### Startup Time

```bash
# Measure container startup time
time docker run --rm danieldu28121999/kubeflow-notebook-uv:latest sleep 0

# Measure service startup time
START_TIME=$(date +%s)
docker run -d --name perf-test -p 8888:8888 danieldu28121999/kubeflow-notebook-uv:latest

# Wait for service to be ready
while ! curl -s http://localhost:8888 > /dev/null; do
    sleep 1
done

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "Service ready in ${ELAPSED} seconds"

docker rm -f perf-test
```

### Memory Usage

```bash
# Run container and monitor memory
docker run -d --name mem-test danieldu28121999/kubeflow-notebook-uv:latest
sleep 30

# Check memory usage
docker stats --no-stream mem-test

docker rm -f mem-test
```

### GPU Performance

```bash
docker run --rm --gpus all danieldu28121999/kubeflow-notebook-uv:latest python -c "
import torch
import time

# Training simulation
model = torch.nn.Linear(1000, 1000).cuda()
optimizer = torch.optim.SGD(model.parameters(), lr=0.01)

data = [torch.rand(32, 1000).cuda() for _ in range(100)]

start = time.time()
for batch in data:
    output = model(batch)
    loss = output.sum()
    loss.backward()
    optimizer.step()
    optimizer.zero_grad()

torch.cuda.synchronize()
end = time.time()

print(f'Training loop time: {end-start:.2f} seconds')
print(f'Batches per second: {len(data)/(end-start):.2f}')
"
```

## Test Checklist

### Before Release

- [ ] Build succeeds without errors
- [ ] Container starts successfully
- [ ] Code-server accessible on port 8888
- [ ] Python 3.11+ installed
- [ ] UV command available
- [ ] Jupyter installed and working
- [ ] All data science packages import successfully
- [ ] User is jovyan with UID 1000
- [ ] Home directory is /home/jovyan
- [ ] VS Code extensions installed
- [ ] GPU detected (nvidia-smi works)
- [ ] PyTorch CUDA available
- [ ] GPU computation works
- [ ] Deploys to Kubeflow successfully
- [ ] Loads in Kubeflow iframe
- [ ] PVC persistence works
- [ ] All automated tests pass

### After Release

- [ ] Pull from Docker Hub works
- [ ] GitHub Actions build succeeded
- [ ] Security scan passed
- [ ] SBOM generated
- [ ] Documentation is accurate
- [ ] Examples work as documented

## Reporting Issues

When reporting test failures, include:

1. **Environment**:
   - Docker version
   - GPU driver version (if applicable)
   - OS and kernel version

2. **Reproduction steps**:
   - Exact commands run
   - Expected vs actual behavior

3. **Logs**:
   ```bash
   docker logs <container-name> > logs.txt
   ```

4. **System info**:
   ```bash
   docker info > docker-info.txt
   nvidia-smi > gpu-info.txt  # if applicable
   ```

## Next Steps

- See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) if tests fail
- See [DEPLOYMENT.md](./DEPLOYMENT.md) for production deployment
- See [README.md](../README.md) for usage instructions
