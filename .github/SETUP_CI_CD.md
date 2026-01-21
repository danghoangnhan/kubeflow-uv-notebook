# CI/CD Setup Guide

This guide walks you through setting up the automated build and push pipeline for the GPU-enabled Kubeflow notebook.

## Prerequisites

- GitHub repository access
- Docker Hub account (or other Docker registry)
- GitHub Actions enabled (enabled by default for public repos)

## Step 1: Create Docker Hub Access Token

1. Go to [Docker Hub](https://hub.docker.com)
2. Log in to your account
3. Navigate to **Account Settings** → **Security** → **Personal Access Tokens**
4. Click **Generate New Token**
5. Name it something like `github-actions-kubeflow`
6. Set permissions to **Read, Write** (for pushing images)
7. Click **Generate** and copy the token (you won't see it again!)

## Step 2: Add GitHub Secrets

In your GitHub repository:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** and add:
   - **Name:** `DOCKER_USERNAME`
     - **Value:** Your Docker Hub username
   - **Name:** `DOCKER_PASSWORD`
     - **Value:** The personal access token you created above

## Step 3: Verify Workflow Setup

The workflow file `.github/workflows/build-and-push.yml` is already configured to:

- **Trigger:** On any git tag pushed (`v*` pattern, e.g., `v1.0.0`, `v1.2.3`)
- **Build:** Creates a Docker image with semantic versioning tags
- **Scan:** Runs Trivy vulnerability scanning
- **Push:** Uploads to Docker Hub

## Step 4: Test the Pipeline

### Option A: Using Git Tags (Recommended for Production)

```bash
# Make changes, commit, then create a semantic version tag
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will automatically:
1. Build the image
2. Tag it as `your-username/code-server-astraluv:v1.0.0`
3. Tag it as `your-username/code-server-astraluv:1.0.0` (semver)
4. Tag it as `your-username/code-server-astraluv:1.0` (major.minor)
5. Tag it as `your-username/code-server-astraluv:latest`
6. Scan for vulnerabilities with Trivy
7. Push all tags to Docker Hub

### Option B: Manual Trigger (For Testing)

1. Go to **Actions** tab in GitHub
2. Select **Build and Push Docker Image** workflow
3. Click **Run workflow**
4. Enter a tag (or leave empty for default)

## Step 5: Monitor the Build

1. Go to **Actions** tab in your GitHub repository
2. Select the most recent workflow run
3. Watch the build progress in real-time
4. Check scan results in the **Security** tab

## Local Testing

Before pushing to production, test locally:

```bash
# Just build
./build.sh v1.0.0

# Build and scan (requires Trivy installed)
./build.sh v1.0.0 --scan

# Build, scan, and push (requires Docker Hub login)
export DOCKER_USERNAME="your-username"
export DOCKER_PASSWORD="your-docker-hub-token"  # Or use docker login first
./build.sh v1.0.0 --scan --push
```

## Image Tagging Strategy

The workflow automatically creates multiple tags for semantic versioning:

```
docker.io/your-username/code-server-astraluv:v1.2.3     # Full tag
docker.io/your-username/code-server-astraluv:1.2.3      # Semver
docker.io/your-username/code-server-astraluv:1.2        # Major.minor
docker.io/your-username/code-server-astraluv:latest     # Latest
```

Use `latest` for quick prototyping, specific versions for production deployments.

## Security Scanning with Trivy

Trivy scans for:
- **CRITICAL** vulnerabilities
- **HIGH** severity issues

Results are:
1. Uploaded to GitHub Security tab (SARIF format)
2. Posted to workflow summary
3. Available in the workflow artifacts

Review security findings before production deployment.

## Troubleshooting

### Build Fails: "Authentication required"
- Verify `DOCKER_PASSWORD` secret is set correctly
- Ensure it's a personal access token, not your account password
- Check token permissions include "Write" access

### Trivy Scan Always Fails
- This is expected in early builds (base image may have CVEs)
- Review HIGH/CRITICAL findings
- Consider pinning base image to specific version
- Address security issues in Dockerfile

### Workflow Not Triggering
- Check that tags follow `v*` pattern (e.g., `v1.0.0`)
- Ensure Actions tab shows the workflow is enabled
- Verify `.github/workflows/build-and-push.yml` is in `main` branch

### Image Not Pushing
- Verify Docker Hub credentials are correct
- Check that `DOCKER_USERNAME` matches your Hub username
- Ensure repository name in workflow matches your Hub repo

## Advanced Configuration

### Change Registry
Edit `.github/workflows/build-and-push.yml`:
```yaml
REGISTRY_IMAGE: ${{ secrets.DOCKER_USERNAME }}/code-server-astraluv
```

### Add Email Notifications
Add step to workflow:
```yaml
- name: Send notification
  if: failure()
  uses: dawidd6/action-send-mail@v3
  with:
    server_address: ${{ secrets.MAIL_SERVER }}
    server_port: ${{ secrets.MAIL_PORT }}
    username: ${{ secrets.MAIL_USERNAME }}
    password: ${{ secrets.MAIL_PASSWORD }}
    subject: Build failed for kubeflow-notebook
    to: your-email@example.com
    from: github-actions
```

### Different Registry (GCR, ECR, etc.)
Replace the `docker/login-action` step with provider-specific credentials.

## Next Steps

1. Push your first tag: `git tag v0.1.0 && git push origin v0.1.0`
2. Monitor the workflow run in **Actions**
3. Once complete, verify image in Docker Hub
4. Use in Kubeflow: `image: docker.io/your-username/code-server-astraluv:v0.1.0`
