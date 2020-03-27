#!/bin/bash
#En un entorno Spark con Hive, genera una tabla en Hive con los datos y estructura de los datos en los ficheros Parquet de HDFS.
#Recibe como parámetros: el path HDFS con los ficheros, el nombre de la base de datos de Hive y el nombre que se quiere dar a la nueva tabla.
#Gustavo Tejerina

#Output de uso de script
usage() {
	echo "Usage:"
	echo -e "\t$0 /hdfs_path db_name table_name"
}

#Validación de parámetro
if [[ $# -ne 3 ]]; then
	usage
	exit 1
fi

if [[ $(hdfs dfs -ls "$1" 2>/dev/null |wc -l) -eq 0 ]]; then
	echo "ERROR. No se encuentra el directorio HDFS $1"
	exit 2
fi

OUTFILE=$(echo $1 |awk -F'/' '{print $NF}')

#Consulta sobre Parquet desde spark-shell
spark-shell << EOF
//Dataframe
val df = sqlContext.read.parquet("$1")
//Creación de tabla
df.saveAsTable("$2.$3")
:q
EOF

if [[ $(hive -e "USE $2; SHOW TABLES" |grep "$3" |wc -l) -ne 0 ]]; then
	echo "Se ha generado la tabla $2.$3"
fi

exit 0
