#!/bin/sh

# ABOUT --------------------------------------------------------------------------------------------
#
# Tests the best parallelism configuration by performing scalability analyses for the following
# configurations:
#
#  - MPI         - Each node runs multiple MPI processes
#  - OMP         - Each node runs one MPI process, which spawns multiple OpenMP threads
#  - OMP-NUMA    - Each node runs one MPI process per NUMA node, each of which spawns multiple
#                  OpenMP threads
#  - KOKKOS      - Similar to OMP, but using the Kokkos backend instead
#  - KOKKOS-NUMA - Similar to OMP-NUMA, but using the Kokkos backend instead
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

# Number of benchmarks to test
BENCHMARKS='LJ RHODO'

# Space-separated list of parallelism configurations to test
PARALLELISMS='MPI OMP OMP-NUMA KOKKOS KOKKOS-NUMA'

# Space-separated list of numbers of nodes to test
NNODES='1 2 4 8 16 32'

# Directory where to store the results (relative to script)
RESULTS='results'

# SOURCE -------------------------------------------------------------------------------------------

# Import utilities
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
. "$SCRIPT_DIR/lib.sh"

# Create output directory
mkdir -p "$SCRIPT_DIR/results"

# Run all parallelism configurations
for benchmark in $BENCHMARKS; do
    for parallelism in $PARALLELISMS; do

        # Skip scaled RHODO with KOKKOS - incompatible combination
        if [ "$benchmark" = 'RHODO' ] && (printf '%s\n' "$parallelism" | grep -q 'KOKKOS'); then
            continue
        fi

        # Strong scaling analysis
        for nnodes in $NNODES; do
            lammps "$parallelism" "$nnodes" 48 "$benchmark" '' 'INFINIBAND' \
                "$SCRIPT_DIR/$RESULTS/$benchmark-$parallelism-$nnodes-48-NOSTORAGE-INFINIBAND"
        done
    done
done
