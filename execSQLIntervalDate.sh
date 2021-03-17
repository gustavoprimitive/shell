#!/bin/bash

startDate="2016-05-12"
endDate="2016-06-01"

sql="INSERT INTO tab1
PARTITION (DATE_PARTITION='textDay')
SELECT *
FROM tab2 
WHERE date_partition='textDay';"

function exec(){
	beeline -u "jdbc:hive2://localhost:21050" -e "\"$@\""
}

i=0
day=""
days=""

while [ "$day" != "$endDate" ]
do  
    day=$(date -d "$startDate + $i days" +%Y-%m-%d)
    days="$days $day"
    i=$(expr $i + 1)
done

for i in $days
do
	echo -e "\n- Day: $i"
	sql_replaced=$(echo $sql |sed "s/textDay/$i/g") 
	echo "$sql_replaced"
	exec $sql_replaced
done
