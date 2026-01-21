# Deployment Guide

Comprehensive guide for deploying the Kubeflow Notebook with Astral UV in production environments.

## Table of Contents

- [Docker Deployment](#docker-deployment)
- [Kubeflow Deployment](#kubeflow-deployment)
- [Production Considerations](#production-considerations)
- [CI/CD Setup](#cicd-setup)
- [Monitoring and Maintenance](#monitoring-and-maintenance)

## Docker Deployment

### Local Development

```bash
# Pull latest image
docker pull danieldu28121999/kubeflow-notebook-uv:latest

# Run with CPU
docker run -d \
  --name my-notebook \
  -p 8888:8888 \
  -v $(pwd)/workspace:/home/jovyan/workspace \
  danieldu28121999/kubeflow-notebook-uv:latest

# Run with GPU
docker run -d \
  --name my-gpu-notebook \
  --gpus all \
  -p 8888:8888 \
  -v $(pwd)/workspace:/home/jovyan/workspace \
  danieldu28121999/kubeflow-notebook-uv:latest
```

### Docker Compose

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  notebook:
    image: danieldu28121999/kubeflow-notebook-uv:latest
    ports:
      - "8888:8888"
    volumes:
      - ./workspace:/home/jovyan/workspace
    environment:
      - JUPYTER_ENABLE_LAB=yes
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

Run:
```bash
docker-compose up -d
```

### Production Docker Deployment

```bash
# Use specific version tag
docker run -d \
  --name production-notebook \
  --restart unless-stopped \
  --gpus all \
  -p 8888:8888 \
  -v /data/notebooks:/home/jovyan \
  -m 16g \
  --cpus 8 \
  --shm-size 2g \
  -e JUPYTER_ENABLE_LAB=yes \
  danieldu28121999/kubeflow-notebook-uv:v1.0.0
```

## Kubeflow Deployment

### Prerequisites

1. **Kubeflow Installation**: Kubeflow 1.7+ installed
2. **GPU Support**: NVIDIA GPU Operator or device plugin (for GPU notebooks)
3. **Storage**: StorageClass configured for PVCs
4. **Namespace**: User namespace created

```bash
# Verify Kubeflow
kubectl get namespace kubeflow

# Verify GPU support (if using GPUs)
kubectl get nodes -o json | jq '.items[].status.allocatable."nvidia.com/gpu"'

# Create user namespace if needed
kubectl create namespace kubeflow-user
```

### Basic Deployment

```bash
# Deploy CPU notebook
kubectl apply -f kubeflow/notebook.yaml

# Verify deployment
kubectl get notebook -n kubeflow-user
kubectl get pod -n kubeflow-user
```

### GPU Deployment

```bash
# Deploy GPU notebook
kubectl apply -f kubeflow/notebook-gpu.yaml

# Verify GPU allocation
kubectl get pod -n kubeflow-user -o yaml | grep "nvidia.com/gpu"

# Check GPU in pod
POD_NAME=$(kubectl get pods -n kubeflow-user -l app=kubeflow-notebook-uv-gpu -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n kubeflow-user $POD_NAME -- nvidia-smi
```

### Custom Configuration

#### Adjust Resources

```yaml
resources:
  requests:
    memory: "16Gi"
    cpu: "8"
    nvidia.com/gpu: "2"  # Request 2 GPUs
  limits:
    memory: "32Gi"
    cpu: "16"
    nvidia.com/gpu: "2"
```

#### Add Environment Variables

```yaml
env:
- name: JUPYTER_ENABLE_LAB
  value: "yes"
- name: UV_INDEX_URL
  value: "https://your-pypi-mirror.com/simple"
- name: CUSTOM_VAR
  value: "custom-value"
```

#### Configure Storage

```yaml
volumes:
- name: workspace
  persistentVolumeClaim:
    claimName: workspace-large
- name: datasets
  persistentVolumeClaim:
    claimName: shared-datasets
- name: dshm
  emptyDir:
    medium: Memory
    sizeLimit: 8Gi  # Larger shared memory

volumeMounts:
- name: workspace
  mountPath: /home/jovyan
- name: datasets
  mountPath: /datasets
  readOnly: true
- name: dshm
  mountPath: /dev/shm
```

#### Node Affinity

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-type
          operator: In
          values:
          - gpu-node
        - key: gpu-type
          operator: In
          values:
          - nvidia-a100
```

### Multi-User Deployment

Create notebooks for multiple users:

```bash
# User 1
cat <<EOF | kubectl apply -f -
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: user1-notebook
  namespace: kubeflow-user1
spec:
  template:
    spec:
      containers:
      - name: notebook
        image: danieldu28121999/kubeflow-notebook-uv:latest
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
EOF

# User 2
cat <<EOF | kubectl apply -f -
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: user2-notebook-gpu
  namespace: kubeflow-user2
spec:
  template:
    spec:
      containers:
      - name: notebook
        image: danieldu28121999/kubeflow-notebook-uv:latest
        resources:
          requests:
            memory: "8Gi"
            cpu: "4"
            nvidia.com/gpu: "1"
EOF
```

## Production Considerations

### Image Versioning

**Always use specific version tags in production:**

```yaml
# Good - specific version
image: danieldu28121999/kubeflow-notebook-uv:v1.0.0

# Bad - floating tag
image: danieldu28121999/kubeflow-notebook-uv:latest
```

### Resource Limits

Set appropriate resource limits to prevent resource exhaustion:

```yaml
resources:
  requests:
    memory: "8Gi"
    cpu: "4"
  limits:
    memory: "16Gi"  # Prevent OOM on node
    cpu: "8"        # Prevent CPU hogging
```

### Security

#### Network Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: notebook-network-policy
  namespace: kubeflow-user
spec:
  podSelector:
    matchLabels:
      app: kubeflow-notebook-uv
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: kubeflow
    ports:
    - protocol: TCP
      port: 8888
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443  # HTTPS
    - protocol: TCP
      port: 80   # HTTP
```

#### Pod Security

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 100
  seccompProfile:
    type: RuntimeDefault
```

### Backup and Recovery

#### Backup Workspace

```bash
# Create backup of PVC
kubectl create job backup-notebook \
  --image=alpine:latest \
  --namespace=kubeflow-user \
  -- sh -c "tar czf /backup/workspace-$(date +%Y%m%d).tar.gz /data"

# Or use Velero
velero backup create notebook-backup \
  --include-namespaces kubeflow-user \
  --include-resources pvc,notebook
```

#### Disaster Recovery

```bash
# Export notebook definition
kubectl get notebook -n kubeflow-user kubeflow-notebook-uv-gpu -o yaml > notebook-backup.yaml

# Restore
kubectl apply -f notebook-backup.yaml
```

### High Availability

#### Multiple Replicas (Not typical for notebooks, but for services)

```yaml
# For stateless services only
replicas: 3
```

#### PVC Backup Strategy

```yaml
# Use storage class with backup support
storageClassName: backup-enabled-storage
```

## CI/CD Setup

### GitHub Actions Configuration

#### 1. Create Docker Hub Access Token

1. Go to [Docker Hub](https://hub.docker.com/)
2. Settings → Security → New Access Token
3. Name: "GitHub Actions CI/CD"
4. Permissions: Read, Write, Delete

#### 2. Add GitHub Secrets

In your GitHub repository:
1. Settings → Secrets and variables → Actions
2. Add secrets:
   - `DOCKER_HUB_USERNAME`: danieldu28121999
   - `DOCKER_HUB_TOKEN`: (your access token)

#### 3. Workflows Are Already Configured

The repository includes:
- `.github/workflows/docker-build-push.yml` - Build and push on tag
- `.github/workflows/security-scan.yml` - Weekly security scans

### Release Process

```bash
# 1. Test locally
./scripts/build.sh v1.1.0
./scripts/test-local.sh
./scripts/test-gpu.sh

# 2. Commit changes
git add .
git commit -m "feat: add new feature"
git push origin main

# 3. Create release tag
git tag -a v1.1.0 -m "Release v1.1.0 - Add new features"
git push origin v1.1.0

# 4. GitHub Actions automatically:
#    - Builds image
#    - Pushes to Docker Hub with multiple tags
#    - Runs security scans
#    - Generates SBOM

# 5. Update Kubeflow deployments
kubectl set image notebook/kubeflow-notebook-uv-gpu \
  notebook=danieldu28121999/kubeflow-notebook-uv:v1.1.0 \
  -n kubeflow-user
```

### Automated Deployment

#### ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kubeflow-notebook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/danieldu28121999/kubeflow-notebook-uv.git
    targetRevision: HEAD
    path: kubeflow
  destination:
    server: https://kubernetes.default.svc
    namespace: kubeflow-user
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

#### Flux CD

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: kubeflow-notebook
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/danieldu28121999/kubeflow-notebook-uv.git
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: kubeflow-notebook
  namespace: flux-system
spec:
  interval: 10m
  path: ./kubeflow
  prune: true
  sourceRef:
    kind: GitRepository
    name: kubeflow-notebook
```

## Monitoring and Maintenance

### Monitoring

#### Prometheus Metrics

```yaml
apiVersion: v1
kind: Service
metadata:
  name: notebook-metrics
  namespace: kubeflow-user
  labels:
    app: kubeflow-notebook-uv
spec:
  type: ClusterIP
  ports:
  - name: metrics
    port: 9090
    targetPort: 9090
  selector:
    app: kubeflow-notebook-uv
```

#### Grafana Dashboard

Monitor:
- CPU usage
- Memory usage
- GPU utilization
- Disk I/O
- Network traffic

```bash
# Get metrics
kubectl top pod -n kubeflow-user
kubectl top node
```

### Logging

#### Collect Logs

```bash
# Pod logs
kubectl logs -f -n kubeflow-user <pod-name>

# Previous pod logs
kubectl logs -n kubeflow-user <pod-name> --previous

# All logs to file
kubectl logs -n kubeflow-user <pod-name> > notebook.log
```

#### Log Aggregation

Use tools like:
- **ELK Stack** (Elasticsearch, Logstash, Kibana)
- **Loki** (Grafana Loki)
- **CloudWatch** (AWS)
- **Stackdriver** (GCP)

### Maintenance

#### Update Image

```bash
# Update to new version
kubectl set image notebook/kubeflow-notebook-uv-gpu \
  notebook=danieldu28121999/kubeflow-notebook-uv:v1.2.0 \
  -n kubeflow-user

# Rollout status
kubectl rollout status notebook/kubeflow-notebook-uv-gpu -n kubeflow-user

# Rollback if needed
kubectl rollout undo notebook/kubeflow-notebook-uv-gpu -n kubeflow-user
```

#### Clean Up Old Images

```bash
# On Docker
docker image prune -a --filter "until=24h"

# On Kubernetes nodes
kubectl node-shell <node-name>
crictl rmi --prune
```

#### Security Updates

```bash
# Check for vulnerabilities
docker scan danieldu28121999/kubeflow-notebook-uv:latest

# Rebuild with latest patches
./scripts/build.sh v1.2.1
./scripts/push.sh v1.2.1

# Update in Kubeflow
kubectl set image ...
```

## Scaling

### Vertical Scaling

```bash
# Increase resources
kubectl edit notebook kubeflow-notebook-uv-gpu -n kubeflow-user

# Update resources section
resources:
  requests:
    memory: "16Gi"  # Increased from 8Gi
    cpu: "8"        # Increased from 4
```

### Horizontal Scaling (Multiple Users)

```bash
# Create notebook templates
for user in user1 user2 user3; do
  kubectl apply -f - <<EOF
apiVersion: kubeflow.org/v1
kind: Notebook
metadata:
  name: ${user}-notebook
  namespace: kubeflow-${user}
spec:
  template:
    spec:
      containers:
      - name: notebook
        image: danieldu28121999/kubeflow-notebook-uv:v1.0.0
EOF
done
```

## Best Practices

1. **Use specific image tags** in production
2. **Set resource limits** to prevent resource exhaustion
3. **Enable PVC backup** for data persistence
4. **Monitor resource usage** continuously
5. **Implement network policies** for security
6. **Regular security scans** of images
7. **Document custom configurations**
8. **Test updates** in staging before production
9. **Keep images updated** with security patches
10. **Use CI/CD** for automated deployments

## Troubleshooting Deployment

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues and solutions.

## Next Steps

- Monitor your deployment
- Set up alerts
- Plan for scaling
- Schedule regular updates
- Backup important data
