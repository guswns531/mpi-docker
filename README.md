# MPI Docker Setup with Docker Compose

This guide walks you through setting up an MPI (Message Passing Interface) environment using Docker and Docker Compose. We will create two Docker containers that can communicate with each other over SSH, enabling you to run distributed MPI programs.

## Prerequisites

Ensure that you have the following installed on your system:
- Docker
- Docker Compose

### Install Docker and Docker Compose 
reference : https://docs.docker.com/engine/install/ubuntu/

1.  Add Docker's official GPG key:
    ```bash
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    ```
2. Add the repository to Apt sources:
    ```bash
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    ```
3.  Install the latest version
    ```bash
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    ```


## Step 1: Generate SSH Keys

First, generate SSH keys that will be used by the containers to communicate securely.

```bash
mkdir workspace
cd workspace 

mkdir .ssh
ssh-keygen -t rsa -f $(pwd)/.ssh/id_rsa -q -N "" 
cat $(pwd)/.ssh/id_rsa.pub >> $(pwd)/.ssh/authorized_keys
```

## Step 2: Create the Dockerfile

Next, create a `Dockerfile` that will be used to build the MPI-enabled Docker image. Save the following content into a file named `Dockerfile`:

```Dockerfile
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
```

Save this as `Dockerfile`.

## Step 3: Build the Docker Image

Now, build the Docker image using the `Dockerfile` created in the previous step.

```bash
docker build -t mpi-docker .
```

## Step 4: Set Up Docker Compose

We will use Docker Compose to set up and manage our MPI containers. This configuration will create two containers, `mpi-node1` and `mpi-node2`, that will be connected on the same network, allowing them to communicate with each other. The current directory will be mounted to `/workspace` inside the containers.

```yaml
version: '3.8'

services:
  mpi-node1:
    image: mpi-docker
    container_name: mpi-node1
    hostname: mpi-node1
    networks:
      - mpi-network
    volumes: 
      - .:/workspace # Mounts the current directory (.) on the host to the '/workspace' directory inside the container.

  mpi-node2:
    image: mpi-docker
    container_name: mpi-node2
    hostname: mpi-node2
    networks:
      - mpi-network
    volumes:
      - .:/workspace

networks:
  mpi-network:
    driver: bridge
```

Save this as `docker-compose.yml`.

## Step 5: Start the MPI Cluster

Start the containers using Docker Compose:

```bash
docker-compose up -d
```

You can verify that the containers are running using:

```bash
docker ps
```

You should see output similar to this:

```bash
CONTAINER ID   IMAGE        COMMAND               CREATED          STATUS          PORTS     NAMES
17386ddffef8   mpi-docker   "/usr/sbin/sshd -D"   1 minutes ago   Up 1 minutes   22/tcp    mpi-node2
185be5bf0b6d   mpi-docker   "/usr/sbin/sshd -D"   1 minutes ago   Up 1 minutes   22/tcp    mpi-node1
```

## Step 6: Configure MPI Hosts

Create a `hosts` file that MPI will use to identify the nodes. 
The `hosts` file in the current directory is mounted to the `/workspace` directory inside the containers.

```bash
echo "mpi-node1 slots=1" > hosts
echo "mpi-node2 slots=1" >> hosts
```

Then, run the MPI program across the containers by executing `mpirun` as the `mpi` user within the `mpi-node1` container:

```bash
docker exec -u mpi mpi-node1 mpirun -np 2 -hostfile /workspace/hosts hostname
```

This command runs the `hostname` command on each container to verify that MPI is working correctly.

## Step 7: Run a Simple MPI Program

Let’s create a simple MPI program, compile it, and run it across the containers.

1. Create a new file named `hello_mpi.c` in the current directory:

   ```c
    #include <mpi.h>
    #include <stdio.h>
    #include <unistd.h>

    int main(int argc, char** argv) {
        MPI_Init(&argc, &argv);

        int world_rank;
        MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

        int world_size;
        MPI_Comm_size(MPI_COMM_WORLD, &world_size);

        char hostname[256];
        gethostname(hostname, 256);
        
        printf("Hello from rank %d out of %d processors on %s\n", world_rank, world_size, hostname);

        MPI_Finalize();
        return 0;
    }
   ```

2. Compile the MPI program inside the `mpi-node1` container:

   ```bash
   docker exec -u mpi mpi-node1 mpicc -o /workspace/hello_mpi /workspace/hello_mpi.c
   ```

3. Run the compiled MPI program across the two containers:

   ```bash
   docker exec -u mpi mpi-node1 mpirun -np 2 -hostfile /workspace/hosts /workspace/hello_mpi
   ```

   This should produce output similar to:

   ```bash
    Hello from rank 0 out of 2 processors on mpi-node1
    Hello from rank 1 out of 2 processors on mpi-node2
   ```

## Step 8: Stop and Clean Up

When you're done, you can stop and remove the containers using:

```bash
docker-compose down
```
