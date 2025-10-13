# Start from NVIDIA CUDA 12.9 base image
FROM nvidia/cuda:12.9.0-runtime-ubuntu22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install Python and system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv git curl && \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip and install PyTorch nightly build supporting sm_120
RUN pip install --upgrade pip && \
    pip install --pre torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/nightly/cu129

# Simple GPU test
COPY <<EOF /app/test_gpu.py
import torch
print("Torch Version:", torch.__version__)
print("CUDA Version:", torch.version.cuda)
print("GPU Available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("Device:", torch.cuda.get_device_name(0))
    a = torch.randn((10000,10000), device='cuda')
    b = torch.randn((10000,10000), device='cuda')
    c = torch.matmul(a,b)
    print("Matrix multiply OK, result shape:", c.shape)
EOF

WORKDIR /app
CMD ["python3", "test_gpu.py"]

