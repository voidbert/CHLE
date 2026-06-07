#!/bin/sh

# ABOUT --------------------------------------------------------------------------------------------
#
# Benchmarks Infiniband, IPoIB, and Ethernet latency and bandwidth between two ARM nodes.
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
# SLURM CONFIGURATION ------------------------------------------------------------------------------
#
# General properties
#SBATCH --job-name=build-osu
#SBATCH --time=00:10:00
#SBATCH --output=output-%j.out
#
# Run on ARM systems
#SBATCH --partition=normal-arm
#SBATCH --account=f202500010hpcvlabuminhoa
#
# Manage number of tasks
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=48
#
# CONFIGURATION ------------------------------------------------------------------------------------

# Space-separated list of network interfaces to test (INFINIBAND, IPoIB, ETHERNET)
INTERFACES='INFINIBAND IPoIB ETHERNET'

# CSV file path (relative to the script) where the benchmark results will be outputted to
OUTPUT_FILE="benchmark.csv"

# SCRIPT -------------------------------------------------------------------------------------------

# Determine the path to the script's directory
SCRIPT_DIR="$(dirname "$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/Command=/{print $2}')")"

# Load necessary modules
module purge
module load OpenMPI/5.0.3-GCC-13.3.0

# Define mpirun flags for each configuration
INFINIBAND_FLAGS='--mca pml ucx'
IPoIB_FLAGS='
    --mca pml ob1 --mca btl tcp,sm,self --mca btl_tcp_if_include ib0 --mca oob_tcp_if_include ib0
'
ETHERNET_FLAGS='
    --mca pml ob1 --mca btl tcp,sm,self --mca btl_tcp_if_include eth0 --mca oob_tcp_if_include eth0
'

# Benchmark different network configurations
echo 'INTERFACE,LATENCY_AVG_US,BANDWIDTH_AVG_MBS' > "$SCRIPT_DIR/$OUTPUT_FILE"
for interface in $INTERFACES; do
    mpirun_flags="$(eval "printf '%s\n' \$${interface}_FLAGS")"

    # Measure latency
    latency="$(
        mpirun -n 2 $mpirun_flags "$SCRIPT_DIR/build/bin/omb_pt2pt"  \
            -m 1:1 -i 5 -- osu_latency                              |\
            awk '/^[^#]/ { print $2 }'
    )"

    # Measure bandwidth
    bandwidth="$(
        mpirun -n 2  $mpirun_flags "$SCRIPT_DIR/build/bin/omb_pt2pt"  \
            -m 1048576:1048576 -i 5 -- osu_bw                        |\
            awk '/^[^#]/ { print $2 }'
    )"

    # Output results
    printf '%s,%s,%s\n' "$interface" "$latency" "$bandwidth" >> "$SCRIPT_DIR/$OUTPUT_FILE"
done
