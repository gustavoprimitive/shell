!#/bin/bash
#Animación spinner
#Gustavo Tejerina

anim()
{
	while true
	do
		printf "|"
		sleep 1
		printf "\r \r"
		
		printf "/"
		sleep 1
		printf "\r \r"

		printf "-"
		sleep 1
		printf "\r \r"

		printf "\\"
		sleep 1
		printf "\r \r"
	done
}

anim
