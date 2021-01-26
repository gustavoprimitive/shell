#!/bin/bash

workingDir='/home/gustavo'
patterns=(xxx bbb ccc)

files=$(ls -t $workingDir/*.gz)

#Files
for f in $files
do
        echo "File: $f"
        #Lines
        while read line 
        do
                echo -e "\tLine: $line"
                #IDs
                for p in "${patterns[@]}"
                do
                        echo -e "\t\tPattern: $p"
                        if [ $(echo $line |grep -c $p) -gt 0 ]; then
                                echo -e "\t\t\t$p found in file $f"
                                #Excluding ID from array
                                patterns=($(echo "${patterns[@]}" |sed "s/$p//"))
                        fi
                done
        done < <(zcat $f)
done
