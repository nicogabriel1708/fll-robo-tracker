
# Stage 1: Build OpenCV with CUDA
FROM nvidia/cuda:13.0.1-cudnn-devel-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential cmake git pkg-config \
    libgtk-3-dev libavcodec-dev libavformat-dev libswscale-dev \
    libtbb-dev libjpeg-dev libpng-dev libtiff-dev libdc1394-dev \
    python3-dev python3-pip python3-numpy \
    libopenblas-dev liblapack-dev libv4l-dev wget unzip \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone OpenCV and contrib modules
WORKDIR /opt

ARG OPENCV_VERSION=4.13.0

RUN git clone --branch ${OPENCV_VERSION} --depth 1 https://github.com/opencv/opencv.git && \
    git clone --branch ${OPENCV_VERSION} --depth 1 https://github.com/opencv/opencv_contrib.git

# Build OpenCV
WORKDIR /opt/opencv/build

RUN cmake .. \
    -DCMAKE_BUILD_TYPE=RELEASE \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DCUDA_NVCC_FLAGS="--std=c++17" \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DOPENCV_EXTRA_MODULES_PATH=/opt/opencv_contrib/modules \
    -DWITH_CUDA=ON \
    -DCUDA_ARCH_BIN=12.1 \
    -DWITH_CUDNN=ON \
    -DOPENCV_DNN_CUDA=ON \
    -DWITH_TBB=ON \
    -DWITH_OPENGL=ON \
    -DWITH_V4L=ON \
    -DWITH_GSTREAMER=ON \
    -DBUILD_opencv_python3=ON \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_PERF_TESTS=OFF \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig

# Stage 2: Runtime
FROM nvidia/cuda:13.0.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Python and dependencies
RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-numpy \
    libv4l-dev ffmpeg \
    libgtk-3-0 libglib2.0-0 \
    libavcodec58 libavformat58 libswscale5 \
    libtbb12 libopenblas0 liblapack3 \
    libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy OpenCV from builder
COPY --from=builder /usr/local /usr/local

RUN ldconfig

# Set working directory
WORKDIR /app

# Copy project files
COPY . /app

# Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# Expose port
EXPOSE 8000

# Command to run
CMD ["python3", "-m", "src.run"]
