#!/bin/sh

# ABOUT --------------------------------------------------------------------------------------------
#
# Contains helpers for launhcing LAMMPS with different parallelism configurations. Also defines the
# benchmarks used for testing.
#
# LICENSE ------------------------------------------------------------------------------------------
#
# Copyright (C) 2026 Humberto Gomes, José Lopes
#
# This program is free software: you can redistribute it and/or modify it under the terms of the
# GNU General Public License as published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITH ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program. If not,
# see <https://www.gnu.org/licenses/>.
#
# CONFIGURATION ------------------------------------------------------------------------------------

# Account to be used for running ARM Slurm jobs
SLURM_ACCOUNT='f202500010hpcvlabuminhoa'

# SOURCE -------------------------------------------------------------------------------------------

# Runs a LAMMPS benchmark with the provided parallelism configuration.
#
# Arguments:
#
#   $1 - Parallelism method: 'MPI'         - Each node runs multiple MPI processes
#                            'OMP'         - Each node runs one MPI process, which spawns multiple
#                                            OpenMP threads
#                            'OMP-NUMA'    - Each NUMA node runs one MPI process, each of which
#                                            spawns multiple OpenMP threads
#                            'KOKKOS'      - Similar to OMP, but using the Kokkos backend instead
#                            'KOKKOS-NUMA' - Similar to OMP-NUMA, but using the Kokkos backend
#                                            instead
#
#   $2 - Number of nodes
#
#   $3 - Number of processes / threads per node (not MPI process)
#
#   $4 - Benchmark to execute: 'LJ'    - simple Lennard-Jones potential benchmark
#                              'RHODO' - Lennard-Jones for short interactions, particle-particle
#                                        particle-mesh (PPPM) for long-range Coulombics
#
#   $5 - Simulation dump path: ''                  - No dump will be performed
#                              Path containing '%' - One file will be outputted for each MPI rank
#                              Other path          - All ranks will output to the same file
#
#   $6 - Network interface to test: 'INFINIBAND' - Use Infiniband with UCX
#                                   'IPoIB'      - Use TCP/IP over Infiniband
#                                   'ETHERNET'   - Use Ethernet
#
#   $7 - Output file base name (without .out extension)
lammps() {
    # Parse function arguments
    if [ "$#" -ne 7 ]                                                     ||
       ! (echo "$1" | grep -Eq '^(MPI|OMP|OMP-NUMA|KOKKOS|KOKKOS-NUMA)$') ||
       ! (echo "$2" | grep -Eq '^[0-9]+$')                                ||
       ! (echo "$3" | grep -Eq '^[0-9]+$')                                ||
       ! (echo "$4" | grep -Eq '^(LJ|RHODO)$'); then

        echo 'lib.sh: lammps: wrong command-line usage' >&2
        return 1
    fi

    parallelism="$1"
    nnodes="$2"
    nproc="$3"
    benchmark="$4"
    dump_path="$5"
    network_interface="$6"
    output_file="$7"

    # Determine environment varibles for parallelism
    if [ "$parallelism" = 'MPI' ]; then

        ntasks_per_node="$nproc"
        ncpus_per_task=1
        openmp_environment=''
        mpirun_parallel_flags=''
        lammps_parallel_flags=''

    elif [ "$parallelism" = 'OMP' ]; then

        ntasks_per_node=1
        ncpus_per_task="$nproc"
        openmp_environment='OMP_PROC_BIND=spread'
        mpirun_parallel_flags='--bind-to none'
        lammps_parallel_flags="-sf omp -pk omp $ncpus_per_task"

    elif [ "$parallelism" = 'OMP-NUMA' ]; then

        ntasks_per_node=4
        ncpus_per_task="$((nproc / 4))"
        openmp_environment=''
        mpirun_parallel_flags='--bind-to numa'
        lammps_parallel_flags="-sf omp -pk omp $ncpus_per_task"

    elif [ "$parallelism" = 'KOKKOS' ]; then

        ntasks_per_node=1
        ncpus_per_task="$nproc"
        openmp_environment='OMP_PROC_BIND=spread'
        mpirun_parallel_flags='--bind-to none'
        lammps_parallel_flags="-sf kk -k on t $ncpus_per_task"

    elif [ "$parallelism" = 'KOKKOS-NUMA' ]; then

        ntasks_per_node=4
        ncpus_per_task="$((nproc / 4))"
        openmp_environment=''
        mpirun_parallel_flags='--bind-to numa'
        lammps_parallel_flags="-sf kk -k on t $ncpus_per_task"

    fi

    # Determine benchmark parameters (paths are relative to inputs/)
    if [ "$benchmark" = 'LJ' ]; then
        benchmark_file='inputs/lj'
        axes_scale=13
    elif [ "$benchmark" = 'RHODO' ]; then
        benchmark_file='inputs/rhodo'
        axes_scale=5
    fi

    # Determine network parameters
    if [ "$network_interface" = 'INFINIBAND' ]; then
        mpirun_network_flags='--mca pml ucx'
    elif [ "$network_interface" = 'IPoIB' ]; then
        mpirun_network_flags='
            --mca pml ob1 --mca btl tcp,sm,self
            --mca btl_tcp_if_include ib0 --mca oob_tcp_if_include ib0
        '
    elif [ "$network_interface" = 'ETHERNET' ]; then
        mpirun_network_flags='
            --mca pml ob1 --mca btl tcp,sm,self
            --mca btl_tcp_if_include eth0 --mca oob_tcp_if_include eth0
        '
    fi

    # Add output options to benchmark file
    if [ -n "$dump_path" ]; then
        # Delete previous dump files if they exist
        if printf '%s\n' "$dump_path" | grep -q '%'; then
            wildcard_dump_path="$(printf '%s\n' "$dump_path" | sed 's/%/*/')"
            rm $wildcard_dump_path 2>/dev/null
        else
            rm "$dump_path" 2>/dev/null
        fi

        # Append dump command to the benchmark
        uuid="$(date +%s)-$(od -An -N4 -tu4 < /dev/urandom | tr -d ' ')"
        processed_benchmark_file="$benchmark_file.$uuid.tmp"

        dump_command="dump dump all atom 100 $dump_path"
        sed -E "s:^run(.*):$dump_command\nrun\1:" "$benchmark_file" > "$processed_benchmark_file"
        benchmark_file="$processed_benchmark_file"
    fi

    # Run LAMMPS
    sbatch --job-name        "lammps-$parallelism-$nnodes-$nproc" \
           --time            '02:00:00'                           \
           --partition       'normal-arm'                         \
           --output          "$output_file.out"                   \
           --account         "$SLURM_ACCOUNT"                     \
           --nodes           "$nnodes"                            \
           --ntasks-per-node "$ntasks_per_node"                   \
           --cpus-per-task   "$ncpus_per_task"                    \
           --export          ALL                                  <<EOF
#!/bin/sh

        # Load necessary modules
        module purge
        module load LAMMPS/29Aug2024_update2-foss-2024a-kokkos

        # Fix newlines in environment variable
        mpirun_network_flags="$(echo "$mpirun_network_flags" | tr -d '\n')"

        # Run LAMMPS
        cd "$SCRIPT_DIR"
        env $openmp_environment OMP_NUM_THREADS="$ncpus_per_task"                  \
            mpirun $mpirun_parallel_flags \$mpirun_network_flags --                \
                lmp $lammps_parallel_flags                                         \
                    -var x "$axes_scale" -var y "$axes_scale" -var z "$axes_scale" \
                    -log "$output_file.log" -in "$benchmark_file"
EOF
}
