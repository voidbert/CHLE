#!/bin/sh

# ABOUT --------------------------------------------------------------------------------------------
#
# Outputs a CSV file with performance data from LAMMPS' logs.
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

# Directory where to store the results (relative to script)
RESULTS='results'

# SOURCE -------------------------------------------------------------------------------------------

# Build RegEx for decomposing file names into their constituent parts
PARALLELISM_REGEX='MPI|OMP|OMP-NUMA|KOKKOS|KOKKOS-NUMA'
BENCHMARK_REGEX='LJ|RHODO'
STORAGE_REGEX='NOSTORAGE|LOCAL|PFS-SINGLE|PFS-SHARDED'
NETWORK_REGEX='INFINIBAND|IPoIB|ETHERNET'
FILENAME_REGEX="($BENCHMARK_REGEX)-($PARALLELISM_REGEX)-([0-9]+)-([0-9]+)-($STORAGE_REGEX)-($NETWORK_REGEX).out"

# Aggregate all LAMMPS throughputs in a single CSV file
echo 'BENCHMARK,PARALLELISM,NNODES,NTASKSPERNODE,STORAGE,NETWORK,THROUGHPUT'

cd "$RESULTS" || exit 1
grep -Eor '[0-9.]+ timesteps/s'                                     |\
    sed -En "s/^$FILENAME_REGEX:([0-9.]+).*/\1,\2,\3,\4,\5,\6,\7/p" |\
    sort -V
