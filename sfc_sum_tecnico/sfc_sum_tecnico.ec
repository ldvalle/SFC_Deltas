/*********************************************************************************
    Proyecto: Migracion al sistema SALES-FORCES
    Aplicacion: sfc_sum_tecnico
    
	Fecha : 19/07/2021

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para la estructura suministro
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		<Tipo Corrida>: 0 = Normal; 1 = Reducida
		
********************************************************************************/
#include <locale.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sfc_sum_tecnico.h";

/* Variables Globales */
int   giTipoCorrida;
FILE	*pFileUnx;

char	sArchivoUnx[100];
char	sArchivoAux[100];
char	sArchivoDos[100];
char	sSoloArchivo[100];

char	sArchLog[100];
char	sPathSalida[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantProcesada;
long 	cantPreexistente;
long	iContaLog;

char  gsDesdeFmt[9];
char  gsHastaFmt[9];

/* Variables Globales Host */
$ClsTecni	regTecni;
$long       glFechaDesde;
$long       glFechaHasta;

char	sMensMail[1024];	

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
FILE	*fp;
int		iFlagMigra=0;
int 	iFlagEmpla=0;
$long lNroCliente;

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
   setlocale(LC_ALL, "en_US.UTF-8");
   setlocale(LC_NUMERIC, "en_US");
   
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT 600;
	$SET ISOLATION TO DIRTY READ;
	
   CreaPrepare();

	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
	if(!AbreArchivos()){
		exit(1);	
	}

	cantProcesada=0;
	cantPreexistente=0;
	iContaLog=0;
	
   fp=pFileUnx;
	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
   $OPEN curSum;

   	while(LeoSuministro(&regTecni)){
   		if (!GenerarPlano(fp, regTecni)){
            printf("Fallo GenearPlano\n");
   			exit(1);	
   		}
   		cantProcesada++;
   	}
   	
   	$CLOSE curSum;
      
/*      
   }
   			
   $CLOSE curClientes;      
*/   
	CerrarArchivos();

	FormateaArchivos();

	$CLOSE DATABASE;

	$DISCONNECT CURRENT;

	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */

/*	
	if(! EnviarMail(sArchResumenDos, sArchControlDos)){
		printf("Error al enviar mail con lista de respaldo.\n");
		printf("El mismo se pueden extraer manualmente en..\n");
		printf("     [%s]\n", sArchResumenDos);
	}else{
		sprintf(sCommand, "rm -f %s", sArchResumenDos);
		iRcv=system(sCommand);			
	}
*/
	printf("==============================================\n");
	printf("CONVENIOS\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Clientes Procesados :       %ld \n",cantProcesada);
	printf("==============================================\n");
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));						

	hora = time(&hora);
	printf("\nHora de finalizacion del proceso : %s\n", ctime(&hora));

	if(iContaLog>0){
		printf("Existen registros en el archivo de log.\nFavor de revisar.\n");	
	}
	printf("Fin del proceso OK\n");	

	exit(0);
}	

short AnalizarParametros(argc, argv)
int		argc;
char	* argv[];
{
   char  sFechaDesde[11];
   char  sFechaHasta[11];
   
   memset(sFechaDesde, '\0', sizeof(sFechaDesde));
   memset(sFechaHasta, '\0', sizeof(sFechaHasta));

   memset(gsDesdeFmt, '\0', sizeof(gsDesdeFmt));
   memset(gsHastaFmt, '\0', sizeof(gsHastaFmt));
   
	if(argc != 2){
		MensajeParametros();
		return 0;
	}
	
	return 1;
}

void MensajeParametros(void){
	printf("Error en Parametros.\n");
	printf("	<Base> = synergia.\n");
}

short AbreArchivos()
{
   char  sTitulos[10000];
   $char sFecha[9];
   int   iRcv;
   
   memset(sTitulos, '\0', sizeof(sTitulos));
	
	memset(sArchivoUnx,'\0',sizeof(sArchivoUnx));
	memset(sArchivoAux,'\0',sizeof(sArchivoAux));
   memset(sArchivoDos,'\0',sizeof(sArchivoDos));
	memset(sSoloArchivo,'\0',sizeof(sSoloArchivo));
	memset(sFecha,'\0',sizeof(sFecha));

	memset(sPathSalida,'\0',sizeof(sPathSalida));

   FechaGeneracionFormateada(sFecha);
   
	RutaArchivos( sPathSalida, "SALESF" );
   
	alltrim(sPathSalida,' ');

	sprintf( sArchivoUnx  , "%sT1SUMINISTROS.unx", sPathSalida );
   sprintf( sArchivoAux  , "%sT1SUMINISTROS.aux", sPathSalida );
   sprintf( sArchivoDos  , "%senel_care_supplies_%s_%s.csv", sPathSalida, gsDesdeFmt, gsHastaFmt);

	strcpy( sSoloArchivo, "T1SUMINISTROS.unx");

	pFileUnx=fopen( sArchivoUnx, "w" );
	if( !pFileUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchivoUnx );
		return 0;
	}
	
   strcpy(sTitulos, "\"External Id\";");
   strcat(sTitulos, "\"Fases\";");
   strcat(sTitulos, "\"Transformador\";");
   strcat(sTitulos, "\"Alimentador\";");
   strcat(sTitulos, "\"Tipo Lectura\";");
   strcat(sTitulos, "\"Ruta Lectura\";");
   strcat(sTitulos, "\"Subestacion\";");
   strcat(sTitulos, "\"Tipo Instalacion - Acometida\";");
   strcat(sTitulos, "\"Conexion\";");
   strcat(sTitulos, "\n");
   
   iRcv=fprintf(pFileUnx, sTitulos);
   if(iRcv<0){
      printf("Error al grabar SUMINISTROS\n");
      exit(1);
   }
   
      
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileUnx);

}

void FormateaArchivos(void){
char	sCommand[1000];
int	iRcv, i;
$char	sPathCp[100];
$char sClave[7];
	
	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));
   strcpy(sClave, "SALEFC");
   	
	$EXECUTE selRutaPlanos INTO :sPathCp using :sClave;

   if ( SQLCODE != 0 ){
     printf("ERROR.\nSe produjo un error al tratar de recuperar el path destino del archivo.\n");
     exit(1);
   }

   sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchivoUnx, sArchivoAux);
	iRcv=system(sCommand);

   sprintf(sCommand, "iconv -f WINDOWS-1252 -t UTF-8 %s > %s ", sArchivoAux, sArchivoDos);
   iRcv=system(sCommand);
   
/*
   sprintf(sCommand, "unix2dos %s | tr -d '\26' > %s", sArchivoUnx, sArchivoDos);
	iRcv=system(sCommand);
   
	sprintf(sCommand, "chmod 777 %s", sArchivoDos);
	iRcv=system(sCommand);
*/	
	sprintf(sCommand, "cp %s %s", sArchivoDos, sPathCp);
	iRcv=system(sCommand);
  
   sprintf(sCommand, "rm %s", sArchivoUnx);
   iRcv=system(sCommand);

   sprintf(sCommand, "rm %s", sArchivoAux);
   iRcv=system(sCommand);

   sprintf(sCommand, "rm %s", sArchivoDos);
   iRcv=system(sCommand);
	
}

void CreaPrepare(void){
$char sql[10000];
$char sAux[1000];

	memset(sql, '\0', sizeof(sql));
	memset(sAux, '\0', sizeof(sAux));

	/******** Fecha Actual Formateada ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY, '%Y%m%d') FROM dual ");
	
	$PREPARE selFechaActualFmt FROM $sql;

	/******** Fecha Actual  ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY, '%d/%m/%Y') FROM dual ");
	
	$PREPARE selFechaActual FROM $sql;	

	/******** Cursor Suministros  ****************/	
	$PREPARE selSuministro FROM "SELECT DISTINCT c.numero_cliente, 
		LPAD(c.sector, 3, '0') || LPAD(c.zona, 5, '0') || LPAD(c.correlativo_ruta, 5, '0') ruta,
		t.nro_subestacion, 
		tec_alimentador, 
		tec_centro_trans, 
		t.codigo_voltaje, 
		t.tipo_conexion, 
		t.acometida
		FROM sf_actuclie s, cliente c, tecni t
		WHERE c.numero_cliente = s.numero_cliente
		AND t.numero_cliente = c.numero_cliente ";

	$DECLARE curSum CURSOR FOR selSuministro;
	
	/******** Select Path de Archivos ****************/
	strcpy(sql, "SELECT valor_alf ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'PATH' ");
	strcat(sql, "AND codigo = ? ");
	strcat(sql, "AND sucursal = '0000' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND ( fecha_desactivac >= TODAY OR fecha_desactivac IS NULL ) ");

	$PREPARE selRutaPlanos FROM $sql;


}

void FechaGeneracionFormateada( Fecha )
char *Fecha;
{
	$char fmtFecha[9];
	
	memset(fmtFecha,'\0',sizeof(fmtFecha));
	
	$EXECUTE selFechaActualFmt INTO :fmtFecha;
	
	strcpy(Fecha, fmtFecha);
	
}

void RutaArchivos( ruta, clave )
$char ruta[100];
$char clave[7];
{

	$EXECUTE selRutaPlanos INTO :ruta using :clave;

    if ( SQLCODE != 0 ){
        printf("ERROR.\nSe produjo un error al tratar de recuperar el path destino del archivo.\n");
        exit(1);
    }
}

long getCorrelativo(sTipoArchivo)
$char		sTipoArchivo[11];
{
$long iValor=0;

	$EXECUTE selCorrelativo INTO :iValor using :sTipoArchivo;
	
    if ( SQLCODE != 0 ){
        printf("ERROR.\nSe produjo un error al tratar de recuperar el correlativo del archivo tipo %s.\n", sTipoArchivo);
        exit(1);
    }	
    
    return iValor;
}


short LeoSuministro(reg)
$ClsTecni *reg;
{
	InicializaTecni(reg);

	$FETCH curSum INTO
		:reg->numero_cliente,
		:reg->ruta_lectura,
		:reg->nro_subestacion,
		:reg->alimentador,
		:reg->centro_trans,
		:reg->codigo_voltaje,
		:reg->tipo_conexion,
		:reg->acometida;
			
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Lecturas !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			
   
   alltrim(reg->nro_subestacion, ' ');
   alltrim(reg->alimentador, ' ');
   alltrim(reg->centro_trans, ' ');
   alltrim(reg->codigo_voltaje, ' ');
   alltrim(reg->tipo_conexion, ' ');
   alltrim(reg->acometida, ' ');
   
            
	return 1;	
}

void InicializaTecni(reg)
$ClsTecni	*reg;
{

   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));

   memset(reg->ruta_lectura, '\0', sizeof(reg->ruta_lectura));
   memset(reg->nro_subestacion, '\0', sizeof(reg->nro_subestacion));
   memset(reg->alimentador, '\0', sizeof(reg->alimentador));
   memset(reg->centro_trans, '\0', sizeof(reg->centro_trans));
   memset(reg->codigo_voltaje, '\0', sizeof(reg->codigo_voltaje)); 
   memset(reg->tipo_conexion, '\0', sizeof(reg->tipo_conexion));
   memset(reg->acometida, '\0', sizeof(reg->acometida));
}


short GenerarPlano(fp, reg)
FILE 			*fp;
$ClsTecni		reg;
{
	char	sLinea[1000];	
	int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));

   /* External Id */
   sprintf(sLinea, "\"%ldAR\";", reg.numero_cliente );
   
   
   
	/* Tipo de Conexión/Fase */
	if(reg.codigo_voltaje[0]=='1') {
		strcat(sLinea, "\"MF\";");
	}else{
		strcat(sLinea, "\"TF\";");
	}
	
	/* Numero de transformador */
	sprintf(sLinea, "%s\"%s\";", sLinea, reg.centro_trans);
	
	/* Numero de alimentador */
	sprintf(sLinea, "%s\"%s\";", sLinea, reg.alimentador);
	
	/* Tipo de lectura */
	strcat(sLinea, "\"11\";");
	
	/* Ruta de lectura */
	sprintf(sLinea, "%s\"%s\";", sLinea, reg.ruta_lectura);
	
	/* Subestación eléctrica */
	sprintf(sLinea, "%s\"%s\";", sLinea, reg.nro_subestacion);
	
	/* Tipo de Instalacion / Acometida */
	sprintf(sLinea, "%s\"%s\";", sLinea, reg.acometida);
	
	/* Conexión */
    sprintf(sLinea, "%s\"%s\";", sLinea, reg.tipo_conexion);

	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
	
   if(iRcv<0){
      printf("Error al grabar SUMINISTROS\n");
      exit(1);
   }
   	

	
	return 1;
}


/****************************
		GENERALES
*****************************/

void command(cmd,buff_cmd)
char *cmd;
char *buff_cmd;
{
   FILE *pf;
   char *p_aux;
   pf =  popen(cmd, "r");
   if (pf == NULL)
       strcpy(buff_cmd, "E   Error en ejecucion del comando");
   else
       {
       strcpy(buff_cmd,"\n");
       while (fgets(buff_cmd + strlen(buff_cmd),512,pf))
           if (strlen(buff_cmd) > 5000)
              break;
       }
   p_aux = buff_cmd;
   *(p_aux + strlen(buff_cmd) + 1) = 0;
   pclose(pf);
}

/*
short EnviarMail( Adjunto1, Adjunto2)
char *Adjunto1;
char *Adjunto2;
{
    char 	*sClave[] = {SYN_CLAVE};
    char 	*sAdjunto[3]; 
    int		iRcv;
    
    sAdjunto[0] = Adjunto1;
    sAdjunto[1] = NULL;
    sAdjunto[2] = NULL;

	iRcv = synmail(sClave[0], sMensMail, NULL, sAdjunto);
	
	if(iRcv != SM_OK){
		return 0;
	}
	
    return 1;
}

void  ArmaMensajeMail(argv)
char	* argv[];
{
$char	FechaActual[11];

	
	memset(FechaActual,'\0', sizeof(FechaActual));
	$EXECUTE selFechaActual INTO :FechaActual;
	
	memset(sMensMail,'\0', sizeof(sMensMail));
	sprintf( sMensMail, "Fecha de Proceso: %s<br>", FechaActual );
	if(strcmp(argv[1],"M")==0){
		sprintf( sMensMail, "%sNovedades Monetarias<br>", sMensMail );		
	}else{
		sprintf( sMensMail, "%sNovedades No Monetarias<br>", sMensMail );		
	}
	if(strcmp(argv[2],"R")==0){
		sprintf( sMensMail, "%sRegeneracion<br>", sMensMail );
		sprintf(sMensMail,"%sOficina:%s<br>",sMensMail, argv[3]);
		sprintf(sMensMail,"%sF.Desde:%s|F.Hasta:%s<br>",sMensMail, argv[4], argv[5]);
	}else{
		sprintf( sMensMail, "%sGeneracion<br>", sMensMail );
	}		
	
}
*/


static char *strReplace(sCadena, cFind, cRemp)
char *sCadena;
char cFind[2];
char cRemp[2];
{
	char sNvaCadena[1000];
	int lLargo;
	int lPos;

	memset(sNvaCadena, '\0', sizeof(sNvaCadena));
	
	lLargo=strlen(sCadena);

    if (lLargo == 0)
    	return sCadena;

	for(lPos=0; lPos<lLargo; lPos++){

       if (sCadena[lPos] != cFind[0]) {
       	sNvaCadena[lPos]=sCadena[lPos];
       }else{
	       if(strcmp(cRemp, "")!=0){
	       		sNvaCadena[lPos]=cRemp[0];  
	       }else {
	            sNvaCadena[lPos]=' ';   
	       }
       }
	}

	return sNvaCadena;
}


