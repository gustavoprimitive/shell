#!/bin/bash
#A través de Spark, extrae a un fichero el contenido de otros ficheros de datos en un directorio de HDFS.
#Gustavo Tejerina

#Path en que se dejará el fichero con los datos de la consulta
OUTPATH="/home/vagrant"

#Output de uso de script
usage() {
	echo "Usage:"
	echo -e "\t$0 <hdfs_path_file>"
}

#Validación de parámetro
if [[ $# -ne 1 ]]; then
	usage
	exit 1
fi

if [[ $(hdfs dfs -ls -d "$1" 2>/dev/null |wc -l) -eq 0 ]]; then
	echo "ERROR. No se encuentra el fichero HDFS $1"
	exit 2
fi

OUTFILE=$(basename $1)

#Consulta sobre Parquet desde spark-shell
spark-shell << EOF |tee "$OUTPATH/${OUTFILE}.out"
//Dataframe
val df = sqlContext.read.parquet("$1")
//Registro de tabla temporal
df.registerTempTable("tempTab")
//Consulta sobre tabla
sqlContext.sql("SELECT * FROM tempTab").show(df.count().toInt)
:q
EOF

if [[ -f "$OUTPATH/$OUTFILE.out" ]]; then
	echo "Se ha generado el fichero: $OUTPATH/$OUTFILE.out"
fi	

exit 0
