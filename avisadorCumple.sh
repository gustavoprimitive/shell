#!/bin/bash
#Comprueba si la fecha del sistema coincide con la fecha del bloque de registros, y en caso afirmativo muestra un mensaje de aviso.
#Dependencia con Zenity.
#Gustavo Tejerina

#Fecha del sistema
DATESYS=`date +"%d/%m"`
DATEFORMAT=`date +"%d %b %Y"`
#Fecha del sistema, más un día, para el preaviso en el día previo
DATESYS_DAY_AFTER=`date --date="+1 day" +"%d/%m"`
DATEFORMAT_DAY_AFTER=`date --date="+1 day" +"%d %b %Y"`

#Recorrido de eventos: fichero de script a partir de la línea de "Registros"
cat $0 |grep -E '^##' |sed 1,2d |while read REG
do
	#Extracción de fecha de registro
	DATEREG=`echo $REG |awk '{print $NF}'`
	
	#Aviso en día coincidente con registro
	if [ "$DATEREG" == "$DATESYS" ]; then
		NAME=`echo $REG |tr -d '##' |awk '{$NF="";print}' |tr -d '-'`
		zenity --info --text="$DATEFORMAT \n\nHoy es el cumpleaños de \n$NAME"
	#Aviso en día previo al de registro
	elif [ "$DATEREG" == "$DATESYS_DAY_AFTER" ]; then
		NAME=`echo $REG |tr -d '##' |awk '{$NF="";print}' |tr -d '-'`
                zenity --info --text="$DATEFORMAT_DAY_AFTER \n\nMañana será el cumpleaños de \n$NAME"
	fi
done


#####################Registros#######################
##Nombre	Apellido1	Apellido2	Fecha (DD/MM)
##foo		bar		-		15/01
