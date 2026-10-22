FROM ros:rolling

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# Build tooling + headless GPU rendering (Xvfb display, VirtualGL EGL backend) + profiling.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ccache \
    gdb \
    libegl1 \
    libgl1 \
    libglu1-mesa \
    linux-perf \
    mesa-utils \
    python3-colcon-common-extensions \
    python3-numpy \
    wget \
    x11-apps \
    x11-utils \
    heaptrack \
    imagemagick \
    xdotool \
    xvfb \
  && rm -rf /var/lib/apt/lists/*

ARG VGL_VERSION=3.1.3
RUN wget -q https://github.com/VirtualGL/virtualgl/releases/download/${VGL_VERSION}/virtualgl_${VGL_VERSION}_amd64.deb \
  && apt-get update && apt-get install -y --no-install-recommends ./virtualgl_${VGL_VERSION}_amd64.deb \
  && rm virtualgl_${VGL_VERSION}_amd64.deb && rm -rf /var/lib/apt/lists/*

# rviz build deps, resolved from the repo's package.xml files.
COPY . /tmp/rviz_src
RUN apt-get update && rosdep update --rosdistro rolling \
  && rosdep install --from-paths /tmp/rviz_src --ignore-src -y --rosdistro rolling \
  && rm -rf /tmp/rviz_src /var/lib/apt/lists/*

ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV CCACHE_DIR=/workspace/ws/.ccache
WORKDIR /workspace/ws
CMD ["/bin/bash"]
