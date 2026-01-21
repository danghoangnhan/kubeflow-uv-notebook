# JupyterLab Configuration for Kubeflow Integration
# This file is automatically copied into the container

# Server configuration
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8889
c.ServerApp.open_browser = False

# Disable authentication (Kubeflow handles auth via reverse proxy)
c.ServerApp.token = ''
c.ServerApp.password = ''

# Allow remote access
c.ServerApp.allow_remote_access = True
c.ServerApp.allow_root = False

# CORS configuration for iframe embedding (Kubeflow)
c.ServerApp.allow_origin = '*'

# Notebook configuration
c.NotebookApp.token = ''
c.NotebookApp.password = ''

# Lab-specific settings
c.LabApp.ip = '0.0.0.0'
c.LabApp.port = 8889
c.LabApp.open_browser = False

# Disable output scrolling
c.NotebookApp.max_output_size = 10000000  # 10MB limit

# Kernel timeout
c.MappingKernelManager.kernel_info_timeout = 10

# Print working directory on startup
import os
print(f"[JupyterLab] Starting in: {os.getcwd()}")
print(f"[JupyterLab] NB_PREFIX: {os.getenv('NB_PREFIX', 'Not set')}")
