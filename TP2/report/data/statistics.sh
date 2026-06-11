#!/bin/sh

# ABOUT --------------------------------------------------------------------------------------------
#
# Generates statistics for the plots in the report. Will be automatically run when the report is
# compiled.
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
# SCRIPT -------------------------------------------------------------------------------------------

# Enter the data/ directory
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$SCRIPT_DIR" || exit 1

# Filter data for parallelism comparison plot
mkdir -p parallelism
for benchmark in 'LJ' 'RHODO'; do
    for parallelism in 'MPI' 'OMP' 'OMP-NUMA' 'KOKKOS' 'KOKKOS-NUMA'; do
        # Skip scaled RHODO with KOKKOS - incompatible combination
        if [ "$benchmark" = 'RHODO' ] && (printf '%s\n' "$parallelism" | grep -q 'KOKKOS'); then
            continue
        fi

        sed -En "1p; /^$benchmark,$parallelism,[0-9]+,48,NOSTORAGE,INFINIBAND/p" all.csv > \
            "parallelism/$benchmark-$parallelism.csv"
    done
done

# Filter data for core count comparison plot
mkdir -p cores
for benchmark in 'LJ' 'RHODO'; do
    # Isolate 44-core and 48-core data
    for cores in 44 48; do
        sed -En "1p; /^$benchmark,OMP-NUMA,[0-9]+,$cores,NOSTORAGE,INFINIBAND/p" all.csv > \
            "cores/$benchmark-$cores.csv"
    done

    # Calculate relative throughput
    join -t, -1 3 -2 3 "cores/$benchmark-44.csv" "cores/$benchmark-48.csv" |\
        awk -F, '
            BEGIN  { print "NNODES,REL_THROUGHPUT" }
            NR > 1 { printf "%s,%s\n", $1, ($7 / $13) }
        ' > "cores/$benchmark.csv"

    # Remove temporary files
    rm "cores/$benchmark-44.csv" "cores/$benchmark-48.csv"
done

# Filter data for checkpointing comparison plot
mkdir -p storage
for benchmark in 'LJ' 'RHODO'; do
    for storage in 'NOSTORAGE' 'LOCAL' 'PFS-SINGLE' 'PFS-SHARDED'; do
        sed -En "1p; /^$benchmark,OMP-NUMA,[0-9]+,48,$storage,INFINIBAND/p" all.csv > \
            "storage/$benchmark-$storage-tmp.csv"

        if [ "$storage" != 'NOSTORAGE' ]; then
            # Calculate relative throughput
            join -t, -1 3 -2 3 "storage/$benchmark-$storage-tmp.csv"   \
                               "storage/$benchmark-NOSTORAGE-tmp.csv" |\
                awk -F, '
                BEGIN  { print "NNODES,REL_THROUGHPUT" }
                NR > 1 { printf "%s,%s\n", $1, ($7 / $13) }
            ' > "storage/$benchmark-$storage.csv"

            # Remove temporary files
            rm "storage/$benchmark-$storage-tmp.csv"
        fi
    done

    rm "storage/$benchmark-NOSTORAGE-tmp.csv"
done

# Filter data for NIC comparison plot
mkdir -p network
for benchmark in 'LJ' 'RHODO'; do
    for network in 'INFINIBAND' 'IPoIB' 'ETHERNET'; do
        sed -En "1p; /^$benchmark,OMP-NUMA,[0-9]+,48,NOSTORAGE,$network/p" all.csv > \
            "network/$benchmark-$network.csv"
    done
done
