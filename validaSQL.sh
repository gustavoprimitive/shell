#!/bin/ksh
#Script para correccion de fuente a partir de fichero sql, generando un fichero resultante que posteriormente se compila.
#Uso: ./script.sh path tag
#En path se indica la ruta completa al directorio que contiene los ficheros sql a tratar.
#El tag sera un string de busqueda de las lineas de comentario cabecera y fin de las modificaciones introducidas. Por ejemplo, el codigo de un proyecto como "ES1607FD".
#Si el valor de tag es "fast", sólo se probará la compilación del código.
#27/05/2016
#Gustavo Tejerina

#Comando para finalizar la animacion en background si se termina la ejecucion del script
trap "pkill validasql.sh ; exit" SIGINT SIGTERM SIGSTP SIGSTOP INT 1>/dev/null 2>/dev/null

clear

#Validacion de recepcion de parametros
if [[ $# -gt 2 ]]; then
	echo "Error: Solo se debe pasar como parametros el path de los ficheros SQL y el patron de cabecera."
	usage
	exit 1
elif [[ $# -lt 2 ]]; then
	echo "Error: No se han pasado como parametros el path de los ficheros SQL y el patron de cabecera."
	usage
	exit 2
fi

if [[ "$1" == "" || "$2" == "" ]]; then
        echo "Error: No se aceptan cadenas vacias como parametros."
	usage
        exit 7
fi

#Recogida de credenciales de fichero de propiedades
if [ -f ./validasql.properties ]; then
	. ./validasql.properties
else
	echo "Error: No se encuentra el fichero properties con los datos de usuario en el directorio del script."
	exit 6
fi

#Export de encoding para castellano
export LC_ALL=es_ES.UTF-8

#Variables para datos de entrada
#Directorio con ficheros sql de origen
PATH_SQL="$1"
#Patron de busqueda en cabecera
HEADER="$2"

##### FUNCTIONS #####

usage(){
        echo -e "Usage: \t$0 SQL_path tag|"fast""
}

#Funcion para construir el nombre temporal del objeto
NAME_PROGRAM()
{
	PROGRAM=$1
	#Primer nombre propuesto
	FIRST_NAME='NEO_'${PROGRAM}'_TEST'
	#Se comprueba si la logitud es valida para Oracle (30 o menos caracteres)
	if [[ `echo "$FIRST_NAME" |tr -d '\n' |wc -c` -le 30 ]]; then
		PROGRAM_REPLACE=$FIRST_NAME
	else	
		#Segundo nombre propuesto
		#Nombre con prefijo, sufijo y 21 primeros carac del nombre del programa
		PROGRAM_REPLACE='NEO_'`echo "$PROGRAM" |cut -c -21`'_TEST' 
	fi
}

#Funcion de chequeo sobre unos minimos que debe cumplir el fichero sql y asigacion de un tipo de flujo a seguir en el codigo
MIN_CHECK()
{
	PATH_SQL=$1
	FILE=$2
	PROGRAM=`echo $FILE |cut -d'.' -f 1`
	
	#Si el fichero sql no es de tipo "ascii text"
	#if [[ `file $PATH_SQL'/'$FILE |grep -ic 'ascii text'` -eq 0 ]]; then
		#ERROR="format"
	#else	
		#Si no contiene sentencia BEGIN o END, error
		if [[ `cat $PATH_SQL'/'$FILE |sed -e 's/^[ \t]*//' |egrep -v ^[\--] |egrep -ic 'begin'` -eq 0 || `cat $PATH_SQL'/'$FILE |sed -e 's/^[ \t]*//' |egrep -v ^[\--] |egrep -ic 'begin'` -eq 0 ]]; then
			ERROR="nosql"
		else
			#Si contiene DDL
			if [[ `cat $PATH_SQL'/'$FILE |sed -e 's/^[ \t]*//' |egrep -v ^[\--] |egrep -ic 'drop |alter |grant |revoke |truncate '` -gt 0 ]]; then #Líneas del fichero sin espacios por la izquierda, que no sean comentario, y contengan DDLs
				ERROR="ddl"
			#Si es parametrizacion
			elif [[ `cat $PATH_SQL'/'$FILE |sed -e 's/^[ \t]*//' |egrep -v ^[\--] |egrep -i 'procedure |function |package ' |grep -ic create` -eq 0 ]]; then 
				ERROR="param"
			#Si es procedimiento, funcion o paquete
			else
				#Si el nombre del fichero no se encuentra como parte del texto del mismo, se interpreta que no coinciden nombre de fichero y programa
				if [[ `grep -ic $PROGRAM $PATH_SQL'/'$FILE` -eq 0 ]]; then
						ERROR="filename"
				else
					ERROR="false"
				fi
			fi
		fi
	#fi
}

#Funcion de verificacion de login en Sql*plus
TEST_SQLPLUS()
{
SQL_USER=`sqlplus -s ${ORA_USER}'/'${ORA_PASS}'@'${ORA_SID} <<EOF
SET HEAD OFF
SET FEEDBACK OFF
SELECT USER FROM DUAL;
EXIT
EOF`
SQL_USER=`echo $SQL_USER |tr -d '\n'`
}

#Funcion de borrado de objeto en B.DD.
RM_PROGRAM_REPLACE()
{
TEST_OBJECT=$1
PROGRAM_REPLACE=$2
sqlplus -s ${ORA_USER}'/'${ORA_PASS}'@'${ORA_SID} <<EOF
DROP $TEST_OBJECT $PROGRAM_REPLACE;
EOF
}

#Funcion de creacion de objeto en B.DD.
ADD_PROGRAM_REPLACE()
{
PATH_SQL=$1
PROGRAM=$2
EXEC_CHAIN='@'${PATH_SQL}'/'${PROGRAM}'_reviewed.sql'
sqlplus -s ${ORA_USER}'/'${ORA_PASS}'@'${ORA_SID} <<EOF
SET DEFINE OFF
$EXEC_CHAIN
EOF
}

#Funcion de ejecucion de fichero de parametrizacion
EXEC_PARAM()
{
PATH_SQL=$1
PROGRAM=$2
EXEC_CHAIN='@'${PATH_SQL}'/'${PROGRAM}'_reviewed.sql'
TEST_EXEC_PARAM=`sqlplus ${ORA_USER}'/'${ORA_PASS}'@'${ORA_SID} <<EOF
SET DEFINE OFF
$EXEC_CHAIN
ROLLBACK;
EOF`
}

#Funcion que busca si se han producido errores o warnings en la compilacion
TEST_COMPILE()
{
PROGRAM_REPLACE=$1
WARN=`sqlplus -s ${ORA_USER}'/'${ORA_PASS}'@'${ORA_SID} <<EOF
SET HEAD OFF
SET LINESIZE 32767
SET FEEDBACK OFF
SELECT 'LINEA: '||LINE, TEXT FROM DBA_ERRORS WHERE NAME = '$PROGRAM_REPLACE' AND OWNER = 'SA';
EOF`
}

#Funcion de verificacion de existencia de objeto en B.DD.
TEST_PROGRAM_REPLACE()
{
PROGRAM_REPLACE=$1
TEST_OBJECT=`sqlplus -s ${ORA_USER}'/'${ORA_PASS}'@'${ORA_SID} <<EOF
SET HEAD OFF
SET SERVEROUTPUT OFF
SELECT OBJECT_TYPE FROM ALL_OBJECTS WHERE OBJECT_NAME = '$PROGRAM_REPLACE';
EOF`
TEST_OBJECT_COUNT=`sqlplus -s ${ORA_USER}'/'${ORA_PASS}'@'${ORA_SID} <<EOF
SET HEAD OFF
SET SERVEROUTPUT OFF
SELECT COUNT(1) FROM ALL_OBJECTS WHERE OBJECT_NAME = '$PROGRAM_REPLACE';
EOF`
}

#Funcion de cambio de nombre de ficheros SQL antiguo y nuevo
RENAME_SQL()
{
	PATH_SQL=$1
	FILE=$2
	PROGRAM=`echo $FILE |awk -F'.' '{print $1}'`
	#Renombrado de fichero original añadiendo ".old"
	mv $PATH_SQL'/'$FILE $PATH_SQL'/'$FILE'.old'
	#Renombrado de nuevo fichero: se elimina sufijo "_filtered"
	mv $PATH_SQL'/'$PROGRAM'_reviewed.sql' $PATH_SQL'/'$FILE
}

#Funcion para mostrar animacion de progreso
ANIM()
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

#Funcion de finalizacion de funcion ANIM()
ANIM_END()
{
	if [[ "$!" != "" ]]; then
		kill $! 1>/dev/null 2>/dev/null ; trap 'kill $!' SIGTERM SIGINT SIGSTOP SIGTSTP INT 1>/dev/null 2>/dev/null
		printf "\r"
		printf "    "
		printf "\r"
	fi
}

##### MAIN #####

#Comprobación de que la ruta en PATH_SQL existe
if [ ! -d $PATH_SQL ]; then
	echo "Error: El valor $PATH_SQL no se corrresponde con una ruta a directorio."
	exit 3
else
	#Generacion de fichero de salida
	LOGFILE='validasql_'`date +"%d-%m-%Y"`'.log'
	date +"%d/%m/%Y %H:%m" > $PATH_SQL'/'$LOGFILE
fi

#Comprobacion de que hay conexion con B.DD.
TEST_SQLPLUS
if [[ "$SQL_USER" != "SA" ]]; then
	echo "Error: Fallo en conexion con B.DD. a traves de SQl*Plus."
	exit 5
fi

#Cabecera
echo "*******************************************************************************************************************************"
echo "Revision de codigo fuente de ficheros SQL contenidos en el directorio `tput smso`$PATH_SQL`tput rmso`" 
echo "*******************************************************************************************************************************"
echo ""
ls -l $PATH_SQL |egrep -i '\.sql$' |egrep -v '\.old$' |grep -v reviewed |awk '{print "-->"$NF}'
echo ""

#Recorrido de los nombres de ficheros sql del directorio dado para almacenar en array
i=0
ls -l $PATH_SQL |egrep -i '\.sql$' |grep -v reviewed |egrep -v '\.old$' |awk '{print $NF}' |while read line
do
    FILES[ $i ]="$line"        
    i=`expr $i + 1`
done

#Recorrido de valores del array
for FILE in "${FILES[@]}"	
do
	
	#Se anyade salto de linea al final del fichero original
	echo "" >> $PATH_SQL'/'$FILE
	#N de lineas del fichero sql para el bucle de recorrido
	NUM_LINES=`wc -l $PATH_SQL'/'$FILE |awk '{print $1}'`
	#Nombre del programa sql extraido del nombre del fichero
	PROGRAM=`echo $FILE |awk -F'.' '{print $1}'`
	
	echo "\n***** Fichero: `tput smso`$FILE`tput rmso` *****" |tee -a $PATH_SQL'/'$LOGFILE 
	
	#Se comprueba si ya existe fichero de salida
    	if [ -f $PATH_SQL'/'$PROGRAM'_reviewed.sql' ]; then
    		echo "\tYa existe un fichero con el nombre de salida ${PROGRAM}_reviewed.sql en el directorio ${PATH_SQL}. Se sobreescribe para continuar la ejecucion." >> $PATH_SQL'/'$LOGFILE
        	rm ${PATH_SQL}/${PROGRAM}_reviewed.sql
    	elif [ -f $PATH_SQL'/'$PROGRAM'.old' ]; then
    		echo "\tYa existe un fichero con el nombre de salida ${PROGRAM}.old en el directorio ${PATH_SQL}. Se sobreescribe para continuar la ejecucion." >> $PATH_SQL'/'$LOGFILE
		rm ${PATH_SQL}/${PROGRAM}.old
	fi
	
        #Salida de pantalla de hora de comienzo
	echo "\tStart `date +"%H:%M:%S"`"

	#Llamada a funcion de barra de proceso
	ANIM&
	#Llamada a función de chequeo de condiciones minimas para considerar el fichero como programa sql a tratar
	MIN_CHECK $PATH_SQL $FILE	
	
	if [[ "$ERROR" == "nosql" ]]; then	
		ANIM_END 2>/dev/null
		echo "\tError. El fichero $FILE no parece tener estructura de programa." >> $PATH_SQL'/'$LOGFILE
		echo "\tError. Revisar log $PATH_SQL/$LOGFILE."
	elif [[ "$ERROR" == "filename" ]]; then	
		ANIM_END 2>/dev/null
		echo "\tError. El nombre del fichero $FILE no coincide con el nombre del programa." >> $PATH_SQL'/'$LOGFILE
		echo "\tError. Revisar log $PATH_SQL/$LOGFILE."		
	elif [[ "$ERROR" == "format" ]]; then
		ANIM_END 2>/dev/null
		echo "\tError. El fichero $FILE no es del tipo correcto. Sólo se procesarán ficheros 'ascii text'." >> $PATH_SQL'/'$LOGFILE
        echo "\tError. Revisar log $PATH_SQL/$LOGFILE."
	elif [[ "$ERROR" == "ddl" ]]; then
		ANIM_END 2>/dev/null
		echo "\tWarning. El fichero $FILE parece contener sentencias DDL." >> $PATH_SQL'/'$LOGFILE
		echo "\tWarning. Revisar log $PATH_SQL/$LOGFILE."
	elif [[ "$ERROR" == "param" ]]; then
		#Fichero de parametrizacion, se cambian los commit por rollback
		echo "1.- Es fichero de parametrizacion." >> $PATH_SQL'/'$LOGFILE
		cat $PATH_SQL'/'$FILE |sed 's/[Cc][Oo][Mm][Mm][Ii][Tt]/ROLLBACK/g' > $PATH_SQL'/'$PROGRAM'_reviewed.sql'
	#Si es procedimiento, función o paquete y el segundo parámetro no es igual a "fast"
	elif [[ "$HEADER" != "fast" ]]; then		
		ANIM_END 2>/dev/null
		#Contruccion de nombre valido de programa corregido para compilar
		NAME_PROGRAM $PROGRAM
		
		#Recorrido de contenido de fichero
		#Salida de pantalla de hora de comienzo
                echo "\tEnd `date +"%H:%M:%S"`"

        	echo "1.- Comprobacion de declaracion y cabeceras de $PROGRAM." >> $PATH_SQL'/'$LOGFILE
		#Llamada a funcion de barra de proceso
		ANIM&
		
		i=0
		while [ $i -le $NUM_LINES ]
		do
			i=`expr $i + 1`
			#Texto de linea
			LINE=`cat $PATH_SQL'/'$FILE |sed -n $i'p'`
		
			#Si es la linea de declaracion
			TEST_CREATE=`echo $LINE |sed -e 's/^[ \t]*//' |egrep -v ^[\--] |egrep -i 'procedure |function |package ' |grep -i $PROGRAM |grep -ic create`
			if [[ $TEST_CREATE -eq 1 ]]; then
				echo "\tEncontrada sentencia de creacion (linea $i)." >> $PATH_SQL'/'$LOGFILE
				#Si en la sentencia de creacion falta el usuario "SA", se anade
				TEST_USER=`echo $LINE |sed -e 's/^[ \t]*//' |egrep -v ^[\--] |egrep -i 'procedure |function |package ' |grep -i $PROGRAM |egrep -ic 'SA\.|"SA"\.'`
				if [[ $TEST_USER -eq 0 ]]; then
					echo "\t\tFalta indicacion de esquema SA (linea $i)." >> $PATH_SQL'/'$LOGFILE
					PROGRAM_REPLACE_SCH='SA.'$PROGRAM_REPLACE
					LINE_OUT=`echo $LINE |sed "s/$PROGRAM/$PROGRAM_REPLACE_SCH/" |tr -d '"'`
					echo "\t\t...Hecho." >> $PATH_SQL'/'$LOGFILE
				else
					#Construccion de nombre de programa temporal
					PROGRAM_REPLACE=$PROGRAM_REPLACE
					LINE_OUT=`echo $LINE |sed "s/$PROGRAM/$PROGRAM_REPLACE/" |tr -d '"'`
				fi
				echo "$LINE_OUT" >> $PATH_SQL'/'$PROGRAM'_reviewed.sql'
			#Si no es linea de declaracion
			else
				#Se comprueba si la linea es cabecera
				TEST_HEADER=`echo $LINE |grep -i NEORIS |egrep [\--] |grep -ci "$HEADER"`
				if [[ $TEST_HEADER -eq 1 ]]; then
					echo "\tEncontrada cabecera con patron de busqueda (linea $i)." >> $PATH_SQL'/'$LOGFILE
					#Si en la cabecera la fecha esta informada  como XX/XX/XXXX
					if [[ `echo $LINE |egrep -c '[Xx]+/[Xx]+/[Xx]+'` -eq 1 ]]; then
						echo "\t\tFalta fecha en cabecera (linea $i)" >> $PATH_SQL'/'$LOGFILE
						TODAY=`date +"%d/%m/%Y"`
						LINE_OUT=`echo $LINE |sed "s|XX/XX/XXXX|$TODAY|"`
						echo "\t\t...Hecho." >> $PATH_SQL'/'$LOGFILE
					else
						LINE_OUT=$LINE
					fi
					echo "$LINE_OUT" >> $PATH_SQL'/'$PROGRAM'_reviewed.sql'
				#Si no es linea de declaracion ni cabecera
				else
					#Si contiene el nombre del programa, se actualiza con el sufijo TEST
					TEST_PROGRAM=`echo $LINE |grep -ci $PROGRAM`
					if [[ $TEST_PROGRAM -eq 1 ]]; then
						#Si el nombre del programa no es subcadena de otro nombre, se reemplaza por el valor de PROGRAM_REPLACE
						if [[ `echo $LINE |egrep -ic '[A-Z0-9]+$PROGRAM'` -eq 0 && `echo $LINE |egrep -ic '$PROGRAM[A-Z0-9]+'` -eq 0 && `echo $LINE |egrep -ic "[\_]$PROGRAM"` -eq 0 && `echo $LINE |egrep -ic "$PROGRAM[\_]"` -eq 0 ]]; then
							LINE_OUT=`echo $LINE |sed "s/$PROGRAM/$PROGRAM_REPLACE/g"`
						else
							LINE_OUT=$LINE
						fi
					else
						LINE_OUT=$LINE
					fi
					echo "$LINE_OUT" >> $PATH_SQL'/'$PROGRAM'_reviewed.sql'
				fi
			fi		
			
		done
	#Si el segundo parámetro es "fast" se genera el fichero "*reviewed" temporal como copia del original
	else
		echo "1.- Ejecutado con opcion fast: solo se prueba compilacion." >> $PATH_SQL'/'$LOGFILE
		#Contrucción de nombre valido de programa corregido para compilar
		NAME_PROGRAM $PROGRAM
		#Generación de fichero temporal a compilar
		sed "s/$PROGRAM/$PROGRAM_REPLACE/g" $PATH_SQL'/'$FILE > $PATH_SQL'/'$PROGRAM'_reviewed.sql'
		#Flag "ERROR" a "false" para que continúe el flujo
		ERROR="false"
		
	fi
	
	#Comprobacion de si el PL termina con el caracter "/"
	if [[ "$HEADER" != "fast" ]]; then
		if [[ "$ERROR" == "false" || "$ERROR" == "param" ]]; then
			echo "\tBuscando caracter / al final del fichero." >> $PATH_SQL'/'$LOGFILE
			#Se anade espacio y salto de línea al final del fichero para leer correctamente el carácter "/"
			echo " " >> ${PATH_SQL}'/'${PROGRAM}'_reviewed.sql'
			END_LINE=`cat -v ${PATH_SQL}'/'${PROGRAM}'_reviewed.sql' |tr -d '^M' |tr -d ' ' |grep . |tail -1`
			if [[ `echo "$END_LINE" |grep -c '\/'` -eq 0 ]]; then
				echo "\t\tFalta caracter / al final del fichero." >> $PATH_SQL'/'$LOGFILE
				echo "/" >> ${PATH_SQL}'/'${PROGRAM}'_reviewed.sql'
				echo "\t\t...Hecho." >> $PATH_SQL'/'$LOGFILE
			fi	
		fi	
	fi

	#Compilacion o ejecucion
	if [[ "$ERROR" == "false" ]]; then
		echo "2.- Compilacion de codigo corregido con nombre ${PROGRAM_REPLACE}." >> $PATH_SQL'/'$LOGFILE
		#Llamada a funcion para comprobar si ya existe un objeto con el nombre del que se va a compilar
		TEST_PROGRAM_REPLACE $PROGRAM_REPLACE > /dev/null
		TEST_OBJECT_COUNT="`echo $TEST_OBJECT_COUNT |tr -d '\n'`"
		if [[ $TEST_OBJECT_COUNT -ne 0 ]]; then
	       	#Finalizacion de funcion de barra de proceso
			ANIM_END 2>/dev/null
			echo "\tError. Ya existe en B.DD. un objeto con el nombre ${PROGRAM_REPLACE}." >> $PATH_SQL'/'$LOGFILE
			ERROR="true"
		else
			#Llamada a funcion de compilacion
			ADD_PROGRAM_REPLACE $PATH_SQL $PROGRAM >/dev/null
			#Llamada a funcion de busqueda de errores en la compilacion
			TEST_COMPILE $PROGRAM_REPLACE
			TEST_OBJECT="`echo $TEST_OBJECT |tr -d '\n'`"
			ERROR="false"
		fi
	
	#Comprobacion de si se ha creado el objeto
	TEST_PROGRAM_REPLACE $PROGRAM_REPLACE > /dev/null
	TEST_OBJECT="`echo $TEST_OBJECT |tr -d '\n'`"
	#Ejecucion para fichero de parametrizacion
	elif [[ "$ERROR" == "param" ]]; then
		echo "2.- Ejecucion de fichero de parametrizacion." >> $PATH_SQL'/'$LOGFILE
		#Llamada a funcion de ejecucion
		EXEC_PARAM $PATH_SQL $PROGRAM >> $PATH_SQL'/'$LOGFILE
	fi
	
	#Si se han producido o no errores en la compilacion
	if [[ "$ERROR" == "false" ]]; then
		if [[ `echo $WARN |tr -d '\n'` != "" || "$TEST_OBJECT" == "" || $TEST_OBJECT_COUNT -ne 1 ]]; then 
			echo "\tErrores en compilacion del objeto ${PROGRAM_REPLACE}:" >> $PATH_SQL'/'$LOGFILE
			echo "\t$WARN" >> $PATH_SQL'/'$LOGFILE
			echo "" >> $PATH_SQL'/'$LOGFILE
			echo "3.- Borrado de programa $PROGRAM_REPLACE en B.DD." >> $PATH_SQL'/'$LOGFILE
			RM_PROGRAM_REPLACE $TEST_OBJECT $PROGRAM_REPLACE >/dev/null
			ANIM_END 2>/dev/null
			echo "\tError. Revisar log $PATH_SQL/$LOGFILE."
			ERROR="true"
		#Si no se han producido errores
		elif [[ `echo $WARN |tr -d '\n'` == "" && "$TEST_OBJECT" != "" && $TEST_OBJECT_COUNT -eq 1 ]]; then
			ANIM_END 2>/dev/null
			echo "\tCompilado el objeto ${PROGRAM_REPLACE} sin error." >> $PATH_SQL'/'$LOGFILE
			echo "\tOk."
			echo "\tEnd `date +"%H:%M:%S"`"
			ERROR="false"
		fi
	elif [[ "$ERROR" == "true" ]]; then
		ANIM_END 2>/dev/null
		echo "\tNo se compila el objeto por que existe otro con el mismo nombre." >> $PATH_SQL'/'$LOGFILE
		echo "\tError. Revisar log $PATH_SQL/$LOGFILE."
		ERROR="true"
	elif [[ "$ERROR" == "param" ]]; then
		if [[ `echo $TEST_EXEC_PARAM |grep -c ORA` -ge 1 ]]; then
			ANIM_END 2>/dev/null
			echo "\tSe ha producido error en ejecucion: \n$TEST_EXEC_PARAM\n" >> $PATH_SQL'/'$LOGFILE
			echo "\tError. Revisar log $PATH_SQL/$LOGFILE."
		else
			ANIM_END 2>/dev/null
			echo "\tNo se han producido errores en la ejecucion:\n$TEST_EXEC_PARAM\n" >> $PATH_SQL'/'$LOGFILE
			echo "\tOk."
			echo "\tEnd `date +"%H:%M:%S"`"
		fi		
	elif [[ "$ERROR" == "ddl" ]]; then
		echo "\tNo se compila el objeto por que contiene sentencias DDL." >> $PATH_SQL'/'$LOGFILE
	fi
	
	#Si el objeto "_TEST" se ha creado, se borra
	if [[ "$ERROR" == "false" ]]; then
		echo "3.- Borrado de programa $PROGRAM_REPLACE en B.DD." >> $PATH_SQL'/'$LOGFILE
		#Si el objeto existe, se elimina
		if [[ "$TEST_OBJECT" == "PROCEDURE" || "$TEST_OBJECT" == "FUNCTION" || "$TEST_OBJECT" == "PACKAGE" || "$TEST_OBJECT" == "PACKAGE BODY" ]]; then
			#Llamada a función de borrado
			RM_PROGRAM_REPLACE $TEST_OBJECT $PROGRAM_REPLACE > /dev/null
			echo "\t...Hecho" >> $PATH_SQL'/'$LOGFILE
		else	
			echo "\tNo se encuentran datos del objeto $PROGRAM_REPLACE." >> $PATH_SQL'/'$LOGFILE
		fi
	fi	

	#Renombrado de ficheros: al original se le anade ".old" y al corregido se le nombra como al original 
	#Si es fichero de parametrizacion se sustituyen las sentencias ROLLBACK por COMMIT en el nuevo fichero
	if [[ "$ERROR" == "param" || "$HEADER" == "fast" ]]; then
		echo "3.- Renombrado de ficheros SQL." >> $PATH_SQL'/'$LOGFILE
		echo "\tNo es necesario renombrado de ficheros." >> $PATH_SQL'/'$LOGFILE
		#Borrado de fichero modificado a partir del de parametrizacion
		rm ${PATH_SQL}'/'${PROGRAM}'_reviewed.sql' 2>/dev/null
	elif [[ "$ERROR" == "nosql" || "$ERROR" == "format" || "$ERROR" == "filename" ]]; then
		echo "\tNo se renombra el fichero." >> $PATH_SQL'/'$LOGFILE
	elif [[ "$ERROR" == "ddl" ]]; then
		echo "\tNo se renombra el fichero." >> $PATH_SQL'/'$LOGFILE
	#Fichero de procedimiento, funcion o paquete
	else 
		#Renombrado de ficheros sql para dejar el nuevo con el nombre del viejo
		echo "4.- Renombrado de ficheros SQL." >> $PATH_SQL'/'$LOGFILE
		if [[ "$ERROR" == "false" ]]; then 
			RENAME_SQL $PATH_SQL $FILE >> $PATH_SQL'/'$LOGFILE
			#Se restablece el nombre del programa al original quitando el sufijo "_TEST"
			cat $PATH_SQL'/'$FILE |sed "s/$PROGRAM_REPLACE/$PROGRAM/g" > $PATH_SQL'/'$FILE'.tmp'
			mv $PATH_SQL'/'$FILE'.tmp' $PATH_SQL'/'$FILE 
			echo "\t...Hecho" >> $PATH_SQL'/'$LOGFILE
		elif [[ "$ERROR" == "true" ]]; then
			echo "\tNo se renombran los ficheros." >> $PATH_SQL'/'$LOGFILE
			rm $PATH_SQL'/'${PROGRAM}'_reviewed.sql' 2>/dev/null
		fi	
		echo "" >> $PATH_SQL'/'$LOGFILE	
	fi
done

#Salida por pantalla de los ficheros SQL en el directorio dado
echo ""
echo "**************************************************"
echo "Ficheros SQL en $PATH_SQL despues de procesamiento"
echo "**************************************************"
echo ""
ls -l $PATH_SQL |egrep -i '\.sql$|\.sql\.old$' |grep -v reviewed |awk '{print "-->"$NF}'
echo ""

#Se da la opcion de mostrar el log de salida
OPTION=""
while [[ "$OPTION" != "s" || "$OPTION" != "S" || "$OPTION" != "n" || "$OPTION" != "N" ]]
do
	printf "Deseas ver el log de salida? (S/N): "
	read OPTION
	if [[ "$OPTION" == "s" || "$OPTION" == "S" ]]; then
		more $PATH_SQL'/'$LOGFILE
		break
	elif [[ "$OPTION" == "n" || "$OPTION" == "N" ]]; then
		break
	fi
done

exit 0



