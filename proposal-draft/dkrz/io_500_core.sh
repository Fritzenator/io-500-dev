#!/bin/bash -e
#IO-500 benchmark
# don't edit

export LC_NUMERIC=C  # prevents printf errors

# check variables
if [[ "$workdir" == "" || "$ior_easy_params" == "" || "$mdtest_hard_files_per_proc" == "" || "$ior_hard_writes_per_proc" == "" || "$find_cmd" == "" || "$ior_cmd" == ""  || "$mdtest_cmd" == ""  ]] ; then
	echo "IO500 script lacks important paramaters!"
	exit 1
fi 
# 

if [[ ! -d $workdir/ior_easy ]] ; then
	echo "[Precreating] missing directories"
	mkdir -p $workdir/ior_easy $workdir/mdt_easy  $workdir/mdt_hard $workdir/ior_hard $output_dir 2>/dev/null
fi

function print_bw  {
   echo "$1/$phase BW:$2 MB/s time: ${3}s" 
}

function print_iops  {
   echo "$1/$phase IOPs:$2 time:${duration}s" 
}

function startphase {
  echo "[Starting] phase $phase"
  start=$(date +%s.%N)
}

function endphase  {  
  end=$(date +%s.%N)
  duration=$(printf "%.0f" $(echo "scale=2; $end - $start" | bc))
  if [[ $duration -le 300 ]] ; then
	echo "[Warning]: the runtime is below 5 minutes"
  fi
}

params_ior_hard="-e -g -vv -G 27 -k -t 47000 -b 47000 -s $ior_hard_writes_per_proc -o ${workdir}/ior_hard/IOR_file"
params_ior_easy="-F -e -g -vv -G 27 -k $ior_easy_params -o $workdir/ior_easy/ior_file_easy"
params_md_easy="-v -u -b 1 -L -d ${workdir}/mdt_easy -u -n $mdtest_easy_files_per_proc"
params_md_hard="-d ${workdir}/mdt_hard -n $mdtest_hard_files_per_proc -w 3900 -e 3900"

# ior easy write
phase="ior-easy-write"
startphase
$mpirun $ior_cmd -w $params_ior_easy > $output_dir/ior_easy 2>&1
endphase   
bw1=$(grep "Max W" $output_dir/ior_easy | sed 's\(\\g' | sed 's\)\\g' | tail -n 1 | awk '{print $5}')

bw_dur1=$(grep "write " $output_dir/ior_easy | tail -n 1 | awk '{print $10}')
print_bw 1 $bw1 $bw_dur1 | tee   $output_dir/ior-easy-results.txt


grep -q "file-per-proc" $output_dir/ior_easy
if [ $? -eq 0 ]; then
	let ior_easy_files=$(($nodes*$procs_per_node))
else
	let ior_easy_files=1
fi 
#mdtest easy create
phase="md-easy-create"
startphase
$mpirun $mdtest_cmd -C $params_md_easy > $output_dir/mdt_easy 2>&1
endphase  
iops1=$(grep "File creation" $output_dir/mdt_easy | tail -n 1 | awk '{print $4}')
print_iops 1 $iops1 | tee  $output_dir/mdt-easy-results.txt


touch $workdir/timestamp

# ior hard write
phase="ior-hard-write"
startphase
$mpirun $ior_cmd -w $params_ior_hard > $output_dir/ior_hard 2>&1
endphase  
bw2=$(grep "Max W" $output_dir/ior_hard | sed 's\(\\g' | sed 's\)\\g' | tail -n 1 | awk '{print $5}')

bw_dur2=$(grep "write " $output_dir/ior_hard | tail -n 1 | awk '{print $10}')
print_bw 2 $bw2 $bw_dur2 | tee $output_dir/ior-hard-results.txt


#mdtest hard create
phase="md-hard-create"
startphase
$mpirun $mdtest_cmd -C  $params_md_hard > $output_dir/mdt_hard 2>&1
endphase  

iops2=$(grep "File creation"  $output_dir/mdt_hard | tail -n 1 | awk '{print $4}')
print_iops 2  $iops2 | tee -a $output_dir/mdt-hard-results.txt


# ior easy read
phase="ior-easy-read"
startphase
$mpirun $ior_cmd -R -r -C $params_ior_easy >> $output_dir/ior_easy 2>&1
endphase  
bw3=$(grep "Max R" $output_dir/ior_easy | sed 's\(\\g' | sed 's\)\\g' | tail -n 1 | awk '{print $5}')

bw_dur3=$(grep "read " $output_dir/ior_easy | tail -n 1 | awk '{print $10}')
print_bw 3 $bw3 $bw_dur3 | tee -a $output_dir/mdt-easy-results.txt


# mdtest easy stat
phase="md-easy-stat"
startphase
$mpirun $mdtest_cmd -T $params_md_easy >> $output_dir/mdt_easy
endphase  
iops3=$(grep "File stat" $output_dir/mdt_easy | tail -n 1 | awk '{print $4}')
print_iops 3 $iops3 | tee -a $output_dir/mdt-easy-results.txt

# ior hard read
phase="md-hard-read"
startphase
$mpirun $ior_cmd  -R -r -C $params_ior_hard >> $output_dir/ior_hard 2>&1
endphase  
bw4=$(grep "Max R" $output_dir/ior_hard | sed 's\(\\g' | sed 's\)\\g' | tail -n 1| awk '{print $5}')
bw_dur4=$(grep "read " $output_dir/ior_hard | tail -n 1 | awk '{print $10}')
print_bw 4 $bw4 $bw_dur4 | tee -a $output_dir/ior-hard-results.txt


# mdtest hard stat
phase="md-hard-stat"
startphase
$mpirun $mdtest_cmd -T $params_md_hard   >> $output_dir/mdt_hard 2>&1
endphase  
iops4=$(grep "File stat" $output_dir/mdt_hard | tail -n 1 | awk '{print $4}')
print_iops 4 $iops4 | tee -a $output_dir/mdt-hard-results.txt

##### find
phase="find"
searched_files1=$(grep "files/directories" $output_dir/mdt_hard | tail -n 1 | awk '{print $3*2}')
searched_files2=$(grep "files/directories" $output_dir/mdt_easy | tail -n 1 | awk '{print $3*2}')
startphase
iops5=$($find_cmd $workdir)
endphase  
print_iops 5 $iops5 | tee -a $output_dir/find-results.txt 

# cleanup phase
# mdtest easy remove
phase="md-easy-delete"
startphase
$mpirun $mdtest_cmd -r $params_md_easy >> $output_dir/mdt_easy 2>&1
endphase  
iops6=$(grep "File removal" $output_dir/mdt_easy | tail -n 1 | awk '{print $4}')
print_iops 6 $iops6 | tee -a $output_dir/mdt-easy-results.txt

# mdtest hard remove
phase="md-hard-delete"
startphase
$mpirun $mdtest_cmd -r $params_md_hard   >> $output_dir/mdt_hard 2>&1
endphase  
iops7=$(grep "File removal" $output_dir/mdt_hard | tail -n 1 | awk '{print $4}')
print_iops 7 $iops7 | tee -a $output_dir/mdt-hard-results.txt


bw_score=`echo $bw1 $bw2 $bw3 $bw4 | awk '{print ($1*$2*$3*$4)^(1/4)}'`
md_score=`echo $iops1 $iops2 $iops3 $iops4 $iops6 $iops7 $iops5 | awk '{print ($1*$2*$3*$4*$5*$6*$7)^(1/7)}'`
export final_score=$( echo "$bw_score*$md_score" | bc)


echo -e "\nIO-500 score:"$final_score
