
#!/bin/bash
#From a list with the birthdays info, check if each date matches the system date.
#Requires Zenity.
#Gustavo Tejerina

#System date
DATESYS=`date +"%d/%m"`
DATEFORMAT=`date +"%d %b %Y"`
#Fecha del sistema, más un día, para el preaviso en el día previo
DATESYS_DAY_AFTER=`date --date="+1 day" +"%d/%m"`
DATEFORMAT_DAY_AFTER=`date --date="+1 day" +"%d %b %Y"`

#Loop records in list (bottom)
cat $0 |grep -E '^##' |sed 1,2d |while read REG
do
	#Extracción de fecha de registro
	DATEREG=`echo $REG |awk '{print $NF}'`
	
	#If dates match
	if [ "$DATEREG" == "$DATESYS" ]; then
		NAME=`echo $REG |tr -d '##' |awk '{$NF="";print}' |tr -d '-'`
		zenity --info --text="$DATEFORMAT \n\nHoy es el cumpleaños de \n$NAME"
	#Advice on previous day
	elif [ "$DATEREG" == "$DATESYS_DAY_AFTER" ]; then
		NAME=`echo $REG |tr -d '##' |awk '{$NF="";print}' |tr -d '-'`
                zenity --info --text="$DATEFORMAT_DAY_AFTER \n\nMañana será el cumpleaños de \n$NAME"
	fi
done


#####################Log#######################
##Name	Surname1	Surname2	Date (DD/MM)
##foo		bar		-		15/01
