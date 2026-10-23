# Build/test environment for rviz on a released ROS distro (backports).
# docker build --build-arg DISTRO=humble -t rviz-humble -f docker/distro/Dockerfile docker/pr_src
ARG DISTRO=humble
FROM ros:${DISTRO}-ros-base
ARG DISTRO
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]
RUN apt-get update && apt-get install -y --no-install-recommends \
    ccache python3-colcon-common-extensions xvfb mesa-utils libgl1-mesa-dri \
    ros-${DISTRO}-rviz-ogre-vendor \
  && rm -rf /var/lib/apt/lists/*
COPY . /tmp/rviz_src
RUN apt-get update && rosdep update --rosdistro ${DISTRO} \
  && rosdep install --from-paths /tmp/rviz_src --ignore-src -y --rosdistro ${DISTRO} \
     --skip-keys rviz_ogre_vendor \
  && rm -rf /tmp/rviz_src /var/lib/apt/lists/*
ENV DISTRO=${DISTRO}
WORKDIR /workspace
