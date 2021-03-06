#!/bin/bash 
#Generación de túneles con fwd de puertos por intervalos

#Host remoto
HOST=""
#Host empleado como pasarela, usuario de login en el mismo y su certificado
GATEWAY=""
USER=""
CERT_FILE=""

COMMAND="ssh -L 6000:${HOST}:6000 ${USER}@${GATEWAY} "

#Primer intervalo
for i in {6001..6100}
do 
	COMMAND+=" -L $i:${HOST}:$i"
done

#Segundo intervalo
for i in {48000..50000}
do 
	COMMAND+=" -L $i:${HOST}:$i"
done

#Tercer intervalo
for i in {57500..58000}
do 
	COMMAND+=" -L $i:${HOST}:$i"
done

COMMAND+=" -i ${CERT_FILE}"

#Ejecución
$COMMAND 
