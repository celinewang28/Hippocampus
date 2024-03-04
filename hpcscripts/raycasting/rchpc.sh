#!/bin/bash
#set -x

rad=$1
while IFS= read -r line || [ -n "$line" ]; do
    temp="${line##*Data}/session01"
    echo "Reading from sessions.txt: $line"
    line+="/session01"
    dirpath=~/hpctmp/Data$temp
    mkdir -p "$dirpath"
    echo "---"
    echo "hpc session directory: $dirpath"
    for file in unityfile.mat eyelink.mat; do
        if [ ! -f "$dirpath/$file" ]; then
            scp "hippocampus@cortex.nus.edu.sg:$line/$file" "$dirpath"
        fi
    done

    curr=$(pwd)
    cd "$dirpath"
    echo "$dirpath" > batch.txt
    rcjob=$(qsub -v rad="$rad" "$curr/rcsubmit.pbs")
    qsub -W depend=afterok:"$rcjob" -v rad="$rad" "$curr/rctrf.pbs"
    binnerjob=$(qsub -W depend=afterok:"$rcjob" -v curr="$curr" "$curr/binning.pbs")

    echo "Changing back to working dir: $curr"
    cd "$curr"
done < ../sessions.txt

