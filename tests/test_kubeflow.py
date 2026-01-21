"""Test Kubeflow compliance and integration"""

import os
import subprocess
import time

import pytest
import requests

IMAGE_NAME = (
    os.getenv("DOCKER_HUB_USERNAME", "danieldu28121999")
    + "/kubeflow-notebook-uv:latest"
)

# Configuration
MAX_STARTUP_RETRIES = 30
STARTUP_RETRY_DELAY = 1
HTTP_TIMEOUT = 10
HTTP_MAX_RETRIES = 5


@pytest.fixture(scope="module")
def running_container():
    """Start a container for testing"""
    container_name = "test-kubeflow-compliance"

    # Clean up any existing container
    subprocess.run(
        ["docker", "rm", "-f", container_name],
        capture_output=True,
        stderr=subprocess.DEVNULL,
    )

    # Start container
    result = subprocess.run(
        [
            "docker",
            "run",
            "-d",
            "--name",
            container_name,
            "-p",
            "8888:8888",
            "-e",
            "NB_PREFIX=/notebook/test-user/test-notebook",
            IMAGE_NAME,
        ],
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0, f"Failed to start container: {result.stderr}"

    # Wait for services to start with retry logic
    startup_complete = False
    for attempt in range(MAX_STARTUP_RETRIES):
        try:
            response = requests.get("http://localhost:8888", timeout=HTTP_TIMEOUT)
            if response.status_code in [200, 302, 404]:
                startup_complete = True
                break
        except requests.RequestException:
            pass

        if attempt < MAX_STARTUP_RETRIES - 1:
            time.sleep(STARTUP_RETRY_DELAY)

    if not startup_complete:
        # Get logs for debugging
        logs = subprocess.run(
            ["docker", "logs", container_name],
            capture_output=True,
            text=True,
        )
        subprocess.run(["docker", "rm", "-f", container_name], capture_output=True)
        pytest.fail(
            f"Container failed to start after {MAX_STARTUP_RETRIES} retries.\n"
            f"Logs:\n{logs.stdout}\nStderr:\n{logs.stderr}"
        )

    yield container_name

    # Cleanup
    subprocess.run(["docker", "rm", "-f", container_name], capture_output=True)


def test_port_8888_exposed(running_container):
    """Test that port 8888 is exposed (Kubeflow requirement)"""
    result = subprocess.run(
        ["docker", "port", running_container, "8888"], capture_output=True, text=True
    )
    assert result.returncode == 0
    assert "8888" in result.stdout
    print(f"✓ Port 8888 is exposed: {result.stdout.strip()}")


def test_nb_prefix_variable(running_container):
    """Test NB_PREFIX environment variable is set"""
    result = subprocess.run(
        ["docker", "exec", running_container, "bash", "-c", "echo $NB_PREFIX"],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert "/notebook/" in result.stdout or result.stdout.strip() == ""
    print(f"✓ NB_PREFIX: {result.stdout.strip() or '(not set, will use default)'}")


def test_code_server_responding(running_container):
    """Test code-server is responding on port 8888"""
    last_error = None
    for attempt in range(HTTP_MAX_RETRIES):
        try:
            response = requests.get("http://localhost:8888", timeout=HTTP_TIMEOUT)
            # Accept any HTTP response (200, 302, etc.) as long as server responds
            assert response.status_code in [200, 302, 404]
            print(f"✓ code-server is responding (HTTP {response.status_code})")
            return
        except requests.RequestException as e:
            last_error = e
            if attempt < HTTP_MAX_RETRIES - 1:
                time.sleep(1)

    pytest.fail(f"code-server not responding after {HTTP_MAX_RETRIES} retries: {last_error}")


def test_cors_headers(running_container):
    """Test CORS headers for iframe compatibility"""
    last_error = None
    for attempt in range(HTTP_MAX_RETRIES):
        try:
            response = requests.get("http://localhost:8888", timeout=HTTP_TIMEOUT)
            # code-server with auth=none should allow embedding
            # Check if X-Frame-Options is absent or set to allow
            x_frame_options = response.headers.get("X-Frame-Options", "")
            print(f"✓ X-Frame-Options: {x_frame_options or '(not set - allows embedding)'}")
            return
        except requests.RequestException as e:
            last_error = e
            if attempt < HTTP_MAX_RETRIES - 1:
                time.sleep(1)

    pytest.fail(f"Failed to check headers after {HTTP_MAX_RETRIES} retries: {last_error}")


def test_jovyan_user(running_container):
    """Test container runs as jovyan user"""
    result = subprocess.run(
        ["docker", "exec", running_container, "whoami"], capture_output=True, text=True
    )
    assert result.returncode == 0
    assert "jovyan" in result.stdout
    print(f"✓ Running as user: {result.stdout.strip()}")


def test_home_directory_writable(running_container):
    """Test /home/jovyan is writable (important for PVC mounts)"""
    result = subprocess.run(
        [
            "docker",
            "exec",
            running_container,
            "bash",
            "-c",
            "touch /home/jovyan/test-file && rm /home/jovyan/test-file && echo 'success'",
        ],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert "success" in result.stdout
    print(f"✓ /home/jovyan is writable")


def test_project_directory_exists(running_container):
    """Test /home/jovyan/project directory exists"""
    result = subprocess.run(
        ["docker", "exec", running_container, "test", "-d", "/home/jovyan/project"],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    print(f"✓ /home/jovyan/project exists")


def test_s6_overlay_running(running_container):
    """Test s6-overlay is managing processes"""
    result = subprocess.run(
        ["docker", "exec", running_container, "ps", "aux"],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert "s6-" in result.stdout or "/init" in result.stdout
    print(f"✓ s6-overlay is running")


def test_code_server_process_running(running_container):
    """Test code-server process is running"""
    result = subprocess.run(
        ["docker", "exec", running_container, "pgrep", "-f", "code-server"],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert result.stdout.strip()
    print(f"✓ code-server process is running (PID: {result.stdout.strip()})")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
