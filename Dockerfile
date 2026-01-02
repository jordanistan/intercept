# INTERCEPT - Signal Intelligence Platform
# Docker container for running the web interface

# ==============================================================================
# Build Stage: Compile dependencies that are not in the standard repositories
# ==============================================================================
FROM python:3.11-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    librtlsdr-dev \
    libusb-1.0-0-dev \
    zlib1g-dev \
    libncurses-dev \
    libssl-dev \
    pkg-config \
    libpcap-dev \
    libcurl4-openssl-dev

# --- Build hcxdumptool ---
WORKDIR /build/hcxdumptool
RUN git clone --depth 1 https://github.com/ZerBea/hcxdumptool.git .
RUN make
RUN cp hcxdumptool /usr/local/bin/ # Explicitly copy the binary

# --- Build hcxtools ---
WORKDIR /build/hcxtools
RUN git clone --depth 1 https://github.com/ZerBea/hcxtools.git .
RUN make
RUN cp hcxpcapngtool hcxhashtool whoismac /usr/local/bin/ # Explicitly copy binaries

# --- Build dump1090-fa ---
WORKDIR /build/dump1090-fa
RUN git clone --depth 1 https://github.com/flightaware/dump1090.git .
RUN make

# ==============================================================================
# Final Stage: Create the production image
# ==============================================================================
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # RTL-SDR tools
    rtl-sdr \
    # Pager decoder
    multimon-ng \
    # 433MHz decoder
    rtl-433 \
    # WiFi tools (aircrack-ng suite)
    aircrack-ng \
    # Bluetooth tools
    bluez \
    # SoapySDR
    soapysdr-tools \
    # LimeSDR
    limesuite \
    # HackRF
    hackrf \
    # Dependencies for built artifacts
    librtlsdr0 \
    libusb-1.0-0 \
    zlib1g \
    libncurses6 \
    libssl3 \
    libpcap0.8 \
    libcurl4 \
    # Cleanup
    && rm -rf /var/lib/apt/lists/*

# Copy built artifacts from the builder stage
COPY --from=builder /usr/local/bin/hcxdumptool /usr/local/bin/
COPY --from=builder /usr/local/bin/hcxpcapngtool /usr/local/bin/
COPY --from=builder /usr/local/bin/hcxhashtool /usr/local/bin/
COPY --from=builder /usr/local/bin/whoismac /usr/local/bin/
COPY --from=builder /build/dump1090-fa/dump1090 /usr/local/bin/dump1090-fa

# Create a symlink for dump1090
RUN ln -s /usr/local/bin/dump1090-fa /usr/local/bin/dump1090

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose web interface port
EXPOSE 5050

# Environment variables with defaults
ENV INTERCEPT_HOST=0.0.0.0 \
    INTERCEPT_PORT=5050 \
    INTERCEPT_LOG_LEVEL=INFO

# Run the application
CMD ["python", "intercept.py"]
