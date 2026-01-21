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

Both workflows are configured with proper security permissions for SARIF uploads:
- ✅ `contents: read` — allows reading the repository
- ✅ `security-events: write` — required for uploading vulnerability scan results to GitHub Security tab
- ✅ `github/codeql-action/upload-sarif@v4` — latest stable version for SARIF uploads

You have two workflows available:

### Workflow 1: `build-and-push.yml` (Release/Tag-based)
- **Trigger:** On any git tag pushed (`v*` pattern, e.g., `v1.0.0`, `v1.2.3`)
- **Build:** Creates a Docker image with semantic versioning tags
- **Scan:** Runs Trivy vulnerability scanning
- **Push:** Uploads to Docker Hub
- **Use case:** Production releases

### Workflow 2: `docker-build-main.yml` (Continuous builds on main)
- **Trigger:** On push to `main` branch, pull requests, or manual workflow dispatch
- **Build:** Creates a Docker image with date + commit hash tags
- **Tagging:** `YYYYMMDD-shortsha`, `shortsha`, and `latest`
- **Scan:** Runs Trivy vulnerability scanning on pushed images
- **Push:** Uploads to Docker Hub on main branch pushes
- **Use case:** Development/testing, automatic builds on every commit

## Step 4: Test the Pipeline

### Option A: Continuous Integration (Recommended for Development)

Simply push to the `main` branch:

```bash
# Make changes, commit, and push
git add .
git commit -m "Your changes"
git push origin main
```

GitHub Actions will automatically:
1. Build the Docker image
2. Tag it with:
   - `YYYYMMDD-shortsha` (e.g., `20250121-a1b2c3d`)
   - `shortsha` (e.g., `a1b2c3d`)
   - `latest`
3. Scan for vulnerabilities with Trivy
4. Push all tags to Docker Hub
5. Post results to GitHub Security tab

### Option B: Production Release (Using Git Tags)

```bash
# Make changes, commit, then create a semantic version tag
git tag v1.0.0
git push origin v1.0.0
```

The `build-and-push.yml` workflow will:
1. Build the image
2. Tag it as:
   - `your-username/code-server-astraluv:v1.0.0`
   - `your-username/code-server-astraluv:1.0.0` (semver)
   - `your-username/code-server-astraluv:1.0` (major.minor)
   - `your-username/code-server-astraluv:latest`
3. Scan for vulnerabilities with Trivy
4. Push all tags to Docker Hub

### Option C: Manual Trigger (For Testing)

1. Go to **Actions** tab in GitHub
2. Select either workflow
3. Click **Run workflow**
4. Workflow runs with default settings

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

### Tags from `build-and-push.yml` (Tag-based releases):
```
docker.io/your-username/code-server-astraluv:v1.2.3     # Full tag
docker.io/your-username/code-server-astraluv:1.2.3      # Semver
docker.io/your-username/code-server-astraluv:1.2        # Major.minor
docker.io/your-username/code-server-astraluv:latest     # Latest
```

### Tags from `docker-build-main.yml` (Main branch builds):
```
docker.io/your-username/code-server-astraluv:20250121-a1b2c3d  # Date + commit
docker.io/your-username/code-server-astraluv:a1b2c3d           # Short commit hash
docker.io/your-username/code-server-astraluv:latest             # Latest
```

**Recommendation:**
- Use specific version tags from releases for production deployments
- Use `latest` tag for development/testing environments
- Use commit hash tags for debugging specific builds

## Security Scanning with Trivy

Trivy scans for:
- **CRITICAL** vulnerabilities
- **HIGH** severity issues

Results are:
1. Uploaded to GitHub Security tab (SARIF format)
2. Posted to workflow summary
3. Available in the workflow artifacts

Review security findings before production deployment.

### SARIF Upload Best Practices

Both workflows use **`github/codeql-action/upload-sarif@v4`** with best practices:

#### Permissions Required
```yaml
permissions:
  contents: read          # Allow reading the repository
  security-events: write  # Required for SARIF upload to GitHub Security tab
```

Both workflows include these permissions, ensuring SARIF results are properly uploaded.

#### Token Handling for Private Repos & Forks

**Default behavior (GITHUB_TOKEN):**
- Works for pushes to the main repository
- SARIF upload may fail on pull requests from forks (read-only token)

**For fork support or private repos:**

If you need SARIF results on PRs from forks, create a Personal Access Token (PAT):

1. Go to **GitHub Settings** → **Developer settings** → **Personal access tokens**
2. Click **Generate new token (classic)**
3. Grant scopes:
   - `repo` (full repository access)
   - `security_events` (read/write for SARIF uploads)
4. Copy the token and add it as a repository secret: `PAT_TOKEN`
5. Update your workflow SARIF upload step:
   ```yaml
   - name: Upload Trivy results to GitHub Security tab
     uses: github/codeql-action/upload-sarif@v4
     with:
       sarif_file: 'trivy-results.sarif'
       token: ${{ secrets.PAT_TOKEN }}
   ```

**Current configuration:**
- `docker-build-main.yml` only scans on pushes (`if: github.event_name == 'push'`), avoiding fork token issues
- `build-and-push.yml` scans after every release tag

For fork PRs, consider:
- Using a PAT token for full fork support, OR
- Accepting that fork PRs won't upload to Security tab (safe default)

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

**For `docker-build-main.yml` (main branch):**
- Verify push is to `main` branch (not a different branch)
- Ensure Actions tab shows the workflow is enabled
- Check `.github/workflows/docker-build-main.yml` exists and is syntactically correct

**For `build-and-push.yml` (tags):**
- Check that tags follow `v*` pattern (e.g., `v1.0.0`)
- Ensure Actions tab shows the workflow is enabled
- Verify `.github/workflows/build-and-push.yml` is in `main` branch

### Image Not Pushing

- Verify Docker Hub credentials are correct in **Settings → Secrets and variables → Actions**
- Check that `DOCKER_USERNAME` matches your Hub username exactly
- Ensure `DOCKER_PASSWORD` is a personal access token (not your account password)
- Verify the image repository exists on Docker Hub or enable auto-creation
- Check GitHub Actions logs for authentication errors
- Test credentials locally: `docker login -u your-username`

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
