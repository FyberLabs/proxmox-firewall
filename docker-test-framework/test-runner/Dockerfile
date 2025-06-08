FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    openssh-client \
    jq \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
RUN wget -O terraform.zip https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip && \
    unzip terraform.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform.zip

# Install Ansible
RUN pip install --no-cache-dir \
    ansible==9.0.1 \
    ansible-core==2.16.0 \
    pytest==7.4.3 \
    pytest-html==4.1.1 \
    pytest-xdist==3.5.0 \
    requests==2.31.0 \
    httpx==0.25.2 \
    pyyaml==6.0.1 \
    jinja2==3.1.2 \
    proxmoxer==2.0.1

# Create test user
RUN useradd -m -s /bin/bash testuser

# Set working directory
WORKDIR /workspace

# Copy test scripts and configurations
COPY run_tests.py /usr/local/bin/
COPY pytest.ini /workspace/
COPY requirements.txt /workspace/

# Install Python test dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Switch to test user
USER testuser

# Default command
CMD ["python", "/usr/local/bin/run_tests.py"]
