# Kubeflow Deployment Guide

Deploying code-server-astraluv to Kubeflow for team collaboration.

## Overview

The image is fully Kubeflow-compatible with:
- Standard `jovyan` user
- Automatic `NB_PREFIX` support
- Multi-interface support (code-server + JupyterLab)
- GPU enablement via Kubeflow configuration
- Persistent storage integration

---

## Minimal Kubeflow Notebook Server Spec

```yaml
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: ml-notebook
  namespace: kubeflow
spec:
  template:
    spec:
      containers:
      - name: notebook
        image: danieldu28121999/code-server-astraluv:latest-cuda12.2-base
        ports:
        - containerPort: 8888
          name: code-server
        - containerPort: 8889
          name: jupyter
        resources:
          requests:
            memory: "8Gi"
            cpu: "4"
          limits:
            memory: "16Gi"
            cpu: "8"
            nvidia.com/gpu: "1"
        volumeMounts:
        - name: notebook-storage
          mountPath: /home/jovyan
      volumes:
      - name: notebook-storage
        persistentVolumeClaim:
          claimName: notebook-pvc
```

---

## CUDA Variant Selection

Choose based on your needs:

**Base (Recommended)**:
```
image: danieldu28121999/code-server-astraluv:latest-cuda12.2-base
```
- ~8GB image size
- CUDA runtime + cuDNN
- Best for inference and training

**Runtime**:
```
image: danieldu28121999/code-server-astraluv:latest-cuda12.2-runtime
```
- ~10GB image size
- Full CUDA runtime

**Devel**:
```
image: danieldu28121999/code-server-astraluv:latest-cuda12.2-devel
```
- ~12GB image size
- Full CUDA toolkit with nvcc
- For building custom CUDA kernels

---

## GPU Configuration

Enable GPU:

```yaml
resources:
  limits:
    nvidia.com/gpu: "1"
```

Verify in container:

```bash
nvidia-smi
```

---

## Storage Configuration

Create PVC for persistent storage:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: notebook-pvc
  namespace: kubeflow
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
```

---

## Environment Variables

NB_PREFIX is automatically set by Kubeflow:

```bash
echo $NB_PREFIX  # Output: /notebook or /user/username/notebook
```

Both code-server and JupyterLab automatically use this for routing.

---

## Accessing the Notebook

1. Log into Kubeflow UI
2. Navigate to Notebooks
3. Find your notebook server
4. Click CONNECT
5. Both code-server and JupyterLab are accessible

---

## Troubleshooting

**Notebook won't start**:
```bash
kubectl describe notebook ml-notebook -n kubeflow
kubectl logs notebook/ml-notebook -n kubeflow -c notebook
```

**GPU not available**:
```bash
kubectl get nodes
kubectl describe node <node-name>
```

**Out of memory**: Increase memory limits in the spec

---

**Next Steps**: [Troubleshooting](Troubleshooting) | [Contributing](Contributing)
