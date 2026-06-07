#!/bin/sh

# ABOUT --------------------------------------------------------------------------------------------
#
# Builds OSU Micro Benchmarks for Deucalion's ARM partition.
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
# Run on ARM systems with Internet access
#SBATCH --partition=dev-arm
#SBATCH --account=f202500010hpcvlabuminhoa
#
# Manage number of tasks
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#
# CONFIGURATION ------------------------------------------------------------------------------------

# Version of OSU Micro Benchmarks to build.
OSU_VERSION='8.0b2'

# SCRIPT -------------------------------------------------------------------------------------------

# Determine the path to the script's directory
SCRIPT_DIR="$(dirname "$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/Command=/{print $2}')")"

# Load necessary modules
module purge
module load OpenMPI/5.0.3-GCC-13.3.0
module load libtool/2.4.7-GCCcore-13.3.0

# Download source code
tarball_url="https://mvapich.cse.ohio-state.edu/download/mvapich/osu-micro-benchmarks-$OSU_VERSION.tar.gz"
curl -Ls "$tarball_url" | tar -xzC /tmp
cd "/tmp/osu-micro-benchmarks-$OSU_VERSION"

# Build OMB
./autogen.sh
./configure CC=mpicc CXX=mpicxx --prefix="$SCRIPT_DIR/build"
make -j48
make install
