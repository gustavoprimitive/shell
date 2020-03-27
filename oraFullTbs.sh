#!/bin/ksh
#Detección de los tablespaces de Oracle superiores a un límite porcentual dado, y output de sus datos
#Gustavo Tejerina

dbuser = "system"
dbpass = "manager"

function show_header
{
	printf "\n------------------------------------------------------------------------------\n";
	printf "SID\tPCT.TAB\t\tTABLESPACE\tPCT.DATA\tDATAFILE";                              
	printf "\n------------------------------------------------------------------------------\n";
}

for sid in sid1 sid2 #Nombres de las instancias a comprobar
do
	show_header
	echo "\n$sid:\n"

sqlplus -s $dbuser/$dbpass'@'$sid <<EOF
SET PAGESIZE 0
SET LINESIZE 1000
SET SERVEROUTPUT ON
SET FEEDBACK OFF

DECLARE

  limit NUMBER(2) := 80;
  v_tab VARCHAR2(50);
  CURSOR c_tablespace IS (
    SELECT a.tablespace_name tablespace_name,
           ROUND(((a.bytes - b.bytes) / a.bytes) * 100, 2) percent
      FROM (SELECT tablespace_name, SUM(bytes) bytes
              FROM dba_data_files
             GROUP BY tablespace_name) a,
           (SELECT tablespace_name, SUM(bytes) bytes
              FROM dba_free_space
             GROUP BY tablespace_name) b
     WHERE a.tablespace_name = b.tablespace_name);
  CURSOR c_datafile(v_tab VARCHAR2) IS (
    SELECT tablespace_name,
           file_name || ' ' || DECODE(maxbytes, 0, '(NO AUTOEXTEND)', '(SI AUTOEXTEND)') file_name,
           percent
      FROM (SELECT d.tablespace_name,
                   d.file_name,
                   d.maxbytes,
                   ROUND((d.bytes - NVL(sum(e.bytes),0)) / d.bytes, 4) * 100 percent
              FROM dba_free_space e, dba_data_files d
             WHERE d.file_id = e.file_id (+)
               AND d.tablespace_name = v_tab
             GROUP BY d.tablespace_name, d.file_name, d.bytes, d.maxbytes));

BEGIN

  FOR r_tablespace IN c_tablespace LOOP
    IF (r_tablespace.percent > limit) THEN
    dbms_output.put_line(chr(10)||chr(9)||r_tablespace.percent||'%'||chr(9)||chr(9)||r_tablespace.tablespace_name);
      FOR r_datafile IN c_datafile(r_tablespace.tablespace_name) LOOP
        dbms_output.put_line(chr(9)||chr(9)||chr(9)||chr(9)||chr(9)||r_datafile.percent||'%'||chr(9)||chr(9)||r_datafile.file_name);
      END LOOP;
    END IF;
  END LOOP;

END;
/
EXIT
EOF
done

exit 0