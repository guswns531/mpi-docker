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