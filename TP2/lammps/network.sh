#!/bin/sh

# ABOUT --------------------------------------------------------------------------------------------
#
# Tests the performance of LAMMPS using different network interfaces (Infiniband, IPoIB, Ethernet).
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

# Space-separated list of numbers of nodes to test
NNODES='1 2 4 8 16 32'

# Directory where to store the results (relative to script)
RESULTS='results'

# Maximum number of concurrent nodes, to avoid network congestion
MAX_CONCURRENT_NODES=32

# SOURCE -------------------------------------------------------------------------------------------

# Import utilities
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
. "$SCRIPT_DIR/lib.sh"

# Create output directory
mkdir -p "$SCRIPT_DIR/$RESULTS"

# Run all network configurations
for benchmark in 'LJ' 'RHODO'; do
    for network in 'IPoIB' 'ETHERNET'; do # INFINIBAND was already tested in `parallelism.sh`

        for nnodes in $NNODES; do
            # Wait for available nodes
            while :; do
                used_nodes="$(squeue -u "$(whoami)" -h -o '%D' | paste -sd+ | bc)"
                if [ "$((used_nodes + nnodes))" -le "$MAX_CONCURRENT_NODES" ]; then
                    break
                else
                    sleep 5
                fi
            done

            # Run LAMMPS
            lammps 'OMP-NUMA' "$nnodes" 48 "$benchmark" '' "$network" \
                "$SCRIPT_DIR/$RESULTS/$benchmark-OMP-NUMA-$nnodes-48-NOSTORAGE-$network"
        done
    done
done
