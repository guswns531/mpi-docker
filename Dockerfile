# Use Ubuntu 20.04 as the base image
FROM ubuntu:20.04

# Set environment variable to prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV USERNAME=mpi

# Install essential packages and OpenMPI
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    curl \
    openssh-client \
    openssh-server \
    openmpi-bin \
    libopenmpi-dev

# Create a new user and set the default shell to bash
RUN useradd -m $USERNAME && \
    usermod -s /bin/bash $USERNAME

# Copy SSH keys to the new user's home directory
COPY .ssh /home/$USERNAME/.ssh

# Set permissions for SSH keys and configure SSH client
RUN chmod 600 /home/$USERNAME/.ssh/authorized_keys &&\
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh &&\
    echo "Host *" > /home/$USERNAME/.ssh/config && \
    echo "   StrictHostKeyChecking no" >> /home/$USERNAME/.ssh/config 

# Expose port 22 for SSH
EXPOSE 22
    
# Create the privilege separation directory for SSH
RUN mkdir -p /run/sshd \
    && chmod 755 /run/sshd

# Set up OpenMPI environment variables
RUN echo "export PATH=/usr/lib64/openmpi/bin:\$PATH" >> /home/$USERNAME/.bashrc
RUN echo "export LD_LIBRARY_PATH=/usr/lib64/openmpi/lib:\$LD_LIBRARY_PATH" >> /home/$USERNAME/.bashrc

# Start the SSH service
ENTRYPOINT ["/usr/sbin/sshd", "-D"]