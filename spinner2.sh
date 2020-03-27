!#/bin/bash
#Animación spinner
#Gustavo Tejerina

anim()
{
	while true
	do
		printf "."
		sleep 1
		printf "."
		sleep 1
		printf "."
		sleep 1
		printf "."
		sleep 1
		printf "\r"
		printf "    "
		printf "\r"
		sleep 1
	done
}

anim
