#!/bin/bash 
#SBATCH --ntasks-per-node=2
#SBATCH --partition=workq
#SBATCH --nodes=100
#SBATCH --job-name=IO-500
#SBATCH --time=01:30:00
#SBATCH -o io_500_out_%J
#SBATCH -e io_500_err_%J

#DW jobdw type=scratch access_mode=striped capacity=3200GiB

# parameters that are always true
# If hyperthreading is not active, do not divide by two in the next command
let maxTasks=$((${SLURM_JOB_CPUS_PER_NODE} * ${SLURM_JOB_NUM_NODES}))/2
mpirun="srun -m block"
workdir=/$DW_JOB_STRIPED/test.$$/
output_dir=/$DW_JOB_STRIPED/io500-results-${SLURM_JOB_NUM_NODES}

# precreate directories for lustre with the appropriate striping
mkdir -p ${workdir}/ior_easy
lfs setstripe --stripe-count 2  ${workdir}/ior_easy

mkdir -p ${workdir}/ior_hard
lfs setstripe --stripe-count 144  ${workdir}/ior_hard

# commands
find_cmd=$PWD/../io500-find.sh
ior_cmd=/project/k01/markomg/burst_test/BB_ior/io-500-dev/proposal-draft/ior
mdtest_cmd=/project/k01/markomg/burst_test/BB_ior/io-500-dev/proposal-draft/mdtest
mdreal_cmd=/project/k01/markomg/burst_test/BB_ior/io-500-dev/proposal-draft/md-real-io # set to "" to not run mdreal

params_mdreal="-P=10 -I=10"

#
identify_parameters_ior_hard=True
identify_parameters_ior_easy=True
identify_parameters_md_easy=True # also enables to do the find 
identify_parameters_md_hard=True
identify_parameters_find=False # only works if ior_easy is also run

timeExpected=300 

cd ..
source ./auto-determine-parameters.sh | tee auto-${SLURM_JOB_NUM_NODES}-${SLURM_JOB_CPUS_PER_NODE}.txt 
