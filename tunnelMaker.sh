#!/bin/bash
#Creación de túneles entre puertos locales (LPORTS) y sus correspondientes remotos (RPORTS).
#Si se le pasa el parámetro "off", finaliza los procesos asociados a los puertos.
#Gustavo Tejerina

usage(){
	echo -e "Usage: \t$0 [off]"
}

#Datos de la máquina remota
IP=127.0.0.1
USER=vagrant
SSH_PORT=2222

#Puertos locales y remotos, respectivamente, con correspondencia según la posición en cada array
#Puertos locales
LPORTS=(8000 4040 3306 8888 8080 8081 18080)
#Puertos remotos
RPORTS=(8000 4040 3306 8888 8080 8081 18080)


if [[ ${#LPORTS[@]} -ne ${#RPORTS[@]} ]]; then
	echo "ERROR. Debe existir el mismo número de puertos locales que remotos"
	exit 1
fi

#Creación de túneles
if [[ $# -eq 0 ]]; then

	for i in $(seq 0 $(expr ${#LPORTS[@]} - 1))
	do
		echo "ssh -g -f -N -L${LPORTS[$i]}:localhost:${RPORTS[$i]} $USER@$IP -p $SSH_PORT"
		ssh -g -f -N -L${LPORTS[$i]}:localhost:${RPORTS[$i]} $USER@$IP -p $SSH_PORT
	done

else
	if [[ $# -gt 1 ]]; then
		usage
		exit 2
	#Finalización de procesos asociados a los túneles
	elif [[ $1 == "off" ]]; then
		for i in $(seq 0 $(expr ${#LPORTS[@]} - 1))
		do
			ps -fe |grep ssh |grep "ssh -g -f -N -L${LPORTS[$i]}:localhost:${RPORTS[$i]} $USER@$IP -p $SSH_PORT" |awk '{print $2}' |xargs kill -9
		done
	else
		usage
	fi
fi

exit 0
