/*********************************************************************************
    Proyecto: Migracion al sistema SALES-FORCES
    Aplicacion: sfc_asset2
    
	Fecha : 25/07/2021

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		
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

$include "sfc_asset2.h";

/* Variables Globales */
int   giTipoCorrida;

FILE	*pFileAsset;
FILE	*pFileCase;
FILE	*pFileCtasCto;

char	sArchivoAssetUnx[100];
char	sArchivoAssetAux[100];
char	sArchivoAssetDos[100];
char	sSoloArchivoAsset[100];

char	sArchivoCaseUnx[100];
char	sArchivoCaseAux[100];
char	sArchivoCaseDos[100];
char	sSoloArchivoCase[100];

char	sArchivoCtasCtoUnx[100];
char	sArchivoCtasCtoAux[100];
char	sArchivoCtasCtoDos[100];
char	sSoloArchivoCtasCto[100];

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
$ClsCliente	regCliente;
$long       glFechaDesde;
$long       glFechaHasta;

char	sMensMail[1024];	

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
int		iFlagMigra=0;
int 	iFlagEmpla=0;
$long 	lNroCliente;

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
	
	/*********************************************
				AREA CURSOR PPAL
	**********************************************/

   $OPEN curClientes;

   while(LeoCliente(&regCliente)){
		if (!GenerarPlanoAsset(regCliente)){
			printf("Fallo GenearPlano Asset\n");
			exit(1);	
		}
/*
		if (!GenerarPlanoCtasCto(regCliente)){
			printf("Fallo GenearPlano CtasCto\n");
			exit(1);	
		}
*/
   		cantProcesada++;
   	}
    			
   $CLOSE curClientes;      

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
	printf("Asset 2\n");
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
   
	if(argc != 3){
		MensajeParametros();
		return 0;
	}
	
   giTipoCorrida=atoi(argv[2]);
   
   if(argc==5){
      strcpy(sFechaDesde, argv[3]); 
      strcpy(sFechaHasta, argv[4]);
      rdefmtdate(&glFechaDesde, "dd/mm/yyyy", sFechaDesde); 
      rdefmtdate(&glFechaHasta, "dd/mm/yyyy", sFechaHasta);
      
      sprintf(gsDesdeFmt, "%c%c%c%c%c%c%c%c", sFechaDesde[6], sFechaDesde[7],sFechaDesde[8],sFechaDesde[9],
                  sFechaDesde[3],sFechaDesde[4], sFechaDesde[0],sFechaDesde[1]);      

      sprintf(gsHastaFmt, "%c%c%c%c%c%c%c%c", sFechaHasta[6], sFechaHasta[7],sFechaHasta[8],sFechaHasta[9],
                  sFechaHasta[3],sFechaHasta[4], sFechaHasta[0],sFechaHasta[1]);      
       
   }else{
      glFechaDesde=-1;
      glFechaDesde=-1;
   }
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
		printf("	<Tipo Corrida> 0=total, 1=Reducida, 3=Delta.\n");
}

short AbreArchivos()
{
   char  sTitulos[10000];
   $char sFecha[9];
   int   iRcv;
   
   /*  ------ ASSET ------- */
	memset(sTitulos, '\0', sizeof(sTitulos));
	
	memset(sArchivoAssetUnx,'\0',sizeof(sArchivoAssetUnx));
	memset(sArchivoAssetAux,'\0',sizeof(sArchivoAssetAux));
	memset(sArchivoAssetDos,'\0',sizeof(sArchivoAssetDos));
	memset(sSoloArchivoAsset,'\0',sizeof(sSoloArchivoAsset));
	memset(sFecha,'\0',sizeof(sFecha));

	memset(sPathSalida,'\0',sizeof(sPathSalida));

	FechaGeneracionFormateada(sFecha);

	RutaArchivos( sPathSalida, "SALESF" );

	alltrim(sPathSalida,' ');

	sprintf( sArchivoAssetUnx  , "%sT1ASSET2.unx", sPathSalida );
	sprintf( sArchivoAssetAux  , "%sT1ASSET2.aux", sPathSalida );
	sprintf( sArchivoAssetDos  , "%senel_care_assetii_t1_%s_%s.csv", sPathSalida, gsDesdeFmt, gsHastaFmt);

	strcpy( sSoloArchivoAsset, "T1ASSET2.unx");

	pFileAsset=fopen( sArchivoAssetUnx, "w" );
	if( !pFileAsset ){
		printf("ERROR al abrir archivo %s.\n", sArchivoAssetUnx );
		return 0;
	}

   strcpy(sTitulos, "\"Identificador activo\";");
   strcat(sTitulos, "\"Tipo cliente\";");
   strcat(sTitulos, "\"Potencia\";");
   strcat(sTitulos, "\"Tipo suministro\";");
   strcat(sTitulos, "\"Clase servicio\";");
   strcat(sTitulos, "\"Tarifa\";");
   strcat(sTitulos, "\"Valor tension\";");
   strcat(sTitulos, "\"Tipo tension\";");
   strcat(sTitulos, "\"Nivel\";");
   strcat(sTitulos, "\n");
   
   iRcv=fprintf(pFileAsset, sTitulos);
   if(iRcv<0){
      printf("Error al grabar ASSET2\n");
      exit(1);
   }
   
   /*  ------ CASE ------- */
/*   
	memset(sTitulos, '\0', sizeof(sTitulos));
	
	memset(sArchivoCaseUnx,'\0',sizeof(sArchivoCaseUnx));
	memset(sArchivoCaseAux,'\0',sizeof(sArchivoCaseAux));
	memset(sArchivoCaseDos,'\0',sizeof(sArchivoCaseDos));
	memset(sSoloArchivoCase,'\0',sizeof(sSoloArchivoCase));
	memset(sFecha,'\0',sizeof(sFecha));

	memset(sPathSalida,'\0',sizeof(sPathSalida));

	FechaGeneracionFormateada(sFecha);

	RutaArchivos( sPathSalida, "SALESF" );

	alltrim(sPathSalida,' ');

	sprintf( sArchivoCaseUnx  , "%sT1CASE.unx", sPathSalida );
	sprintf( sArchivoCaseAux  , "%sT1CASE.aux", sPathSalida );
	sprintf( sArchivoCaseDos  , "%senel_care_case_t1_%s_%s.csv", sPathSalida, gsDesdeFmt, gsHastaFmt);

	strcpy( sSoloArchivoCase, "T1CASE.unx");

	pFileCase=fopen( sArchivoCaseUnx, "w" );
	if( !pFileCase){
		printf("ERROR al abrir archivo %s.\n", sArchivoCaseUnx );
		return 0;
	}

   strcpy(sTitulos, "\"Numero de orden\";");
   strcat(sTitulos, "\"Motivo\";");
   strcat(sTitulos, "\"Submotivo\";");
   strcat(sTitulos, "\"Estado\";");
   strcat(sTitulos, "\"Origen del caso\";");
   strcat(sTitulos, "\"Fecha/Hora de apertura\";");
   strcat(sTitulos, "\"Fecha Vencimiento\";");
   strcat(sTitulos, "\"Fecha/Hora de cierre\";");
   strcat(sTitulos, "\"Nombre del contacto\";");
   strcat(sTitulos, "\"Suministro\";");
   strcat(sTitulos, "\"Nombre de la cuenta\";");
   strcat(sTitulos, "\"Descripcion\";");
   strcat(sTitulos, "\"Migrado\";");
   strcat(sTitulos, "\"Observaciones\";");
   strcat(sTitulos, "\"Tipo Atencion Interna\";");
   strcat(sTitulos, "\"External Id\";");
   
   
   strcat(sTitulos, "\n");
   
   iRcv=fprintf(pFileCase, sTitulos);
   if(iRcv<0){
      printf("Error al grabar CASE\n");
      exit(1);
   }
*/      
   /*  ------ CTAS CONTACTO ------- */
/*   
	memset(sTitulos, '\0', sizeof(sTitulos));
	
	memset(sArchivoCtasCtoUnx,'\0',sizeof(sArchivoCtasCtoUnx));
	memset(sArchivoCtasCtoAux,'\0',sizeof(sArchivoCtasCtoAux));
	memset(sArchivoCtasCtoDos,'\0',sizeof(sArchivoCtasCtoDos));
	memset(sSoloArchivoCtasCto,'\0',sizeof(sSoloArchivoCtasCto));
	memset(sFecha,'\0',sizeof(sFecha));

	memset(sPathSalida,'\0',sizeof(sPathSalida));

	FechaGeneracionFormateada(sFecha);

	RutaArchivos( sPathSalida, "SALESF" );

	alltrim(sPathSalida,' ');

	sprintf( sArchivoCtasCtoUnx  , "%sT1CTASCTO.unx", sPathSalida );
	sprintf( sArchivoCtasCtoAux  , "%sT1CTASCTO.aux", sPathSalida );
	sprintf( sArchivoCtasCtoDos  , "%senel_care_ctascto_t1_%s_%s.csv", sPathSalida, gsDesdeFmt, gsHastaFmt);

	strcpy( sSoloArchivoAsset, "T1CTASCTO.unx");

	pFileCtasCto=fopen( sArchivoCtasCtoUnx, "w" );
	if( !pFileCtasCto ){
		printf("ERROR al abrir archivo %s.\n", sArchivoCtasCtoUnx );
		return 0;
	}

   strcpy(sTitulos, "\"Activo\";");
   strcat(sTitulos, "\"Contacto\";");
   strcat(sTitulos, "\"Cuenta\";");
   strcat(sTitulos, "\"Directo\";");
   strcat(sTitulos, "\"Fecha Finalizacion\";");
   strcat(sTitulos, "\"Fecha Inicio\";");
   strcat(sTitulos, "\"Funcionales\";");
   strcat(sTitulos, "\n");
   
   iRcv=fprintf(pFileCtasCto, sTitulos);
   if(iRcv<0){
      printf("Error al grabar CTAS_CTO\n");
      exit(1);
   }
*/      
      
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileAsset);
/*
	fclose(pFileCase);
	fclose(pFileCtasCto);
*/
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

	/* asset */
	sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchivoAssetUnx, sArchivoAssetAux);
	iRcv=system(sCommand);

	sprintf(sCommand, "iconv -f WINDOWS-1252 -t UTF-8 %s > %s ", sArchivoAssetAux, sArchivoAssetDos);
	iRcv=system(sCommand);

	sprintf(sCommand, "cp %s %s", sArchivoAssetDos, sPathCp);
	iRcv=system(sCommand);

	sprintf(sCommand, "rm %s", sArchivoAssetUnx);
	iRcv=system(sCommand);

	sprintf(sCommand, "rm %s", sArchivoAssetAux);
	iRcv=system(sCommand);

	sprintf(sCommand, "rm %s", sArchivoAssetDos);
	iRcv=system(sCommand);
	
	/* case */
/*	
	memset(sCommand, '\0', sizeof(sCommand));
	
	sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchivoCaseUnx, sArchivoCaseAux);
	iRcv=system(sCommand);

	sprintf(sCommand, "iconv -f WINDOWS-1252 -t UTF-8 %s > %s ", sArchivoCaseAux, sArchivoCaseDos);
	iRcv=system(sCommand);

	sprintf(sCommand, "cp %s %s", sArchivoCaseDos, sPathCp);
	iRcv=system(sCommand);

	sprintf(sCommand, "rm %s", sArchivoCaseUnx);
	iRcv=system(sCommand);

	sprintf(sCommand, "rm %s", sArchivoCaseAux);
	iRcv=system(sCommand);

	sprintf(sCommand, "rm %s", sArchivoCaseDos);
	iRcv=system(sCommand);
*/	
	
	/* ctas cto */
/*	
	memset(sCommand, '\0', sizeof(sCommand));
	
	sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchivoCtasCtoUnx, sArchivoCtasCtoAux);
	iRcv=system(sCommand);

	sprintf(sCommand, "iconv -f WINDOWS-1252 -t UTF-8 %s > %s ", sArchivoCtasCtoAux, sArchivoCtasCtoDos);
	iRcv=system(sCommand);

	sprintf(sCommand, "cp %s %s", sArchivoCtasCtoDos, sPathCp);
	iRcv=system(sCommand);

	sprintf(sCommand, "rm %s", sArchivoCtasCtoUnx);
	iRcv=system(sCommand);

	sprintf(sCommand, "rm %s", sArchivoCtasCtoAux);
	iRcv=system(sCommand);

	sprintf(sCommand, "rm %s", sArchivoCtasCtoDos);
	iRcv=system(sCommand);
*/	
	
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

	/******** Cursor CLIENTES  ****************/
	strcpy(sql, "SELECT c.numero_cliente, ");
	strcat(sql, "c.potencia_inst_fp, ");
	strcat(sql, "c.potencia_contrato, ");
	strcat(sql, "TRIM(t1.descripcion) tipo_suministro, ");
	strcat(sql, "TRIM(t2.descripcion) tipo_cliente, ");

	strcat(sql, "CASE ");
	strcat(sql, "	WHEN c.tarifa IN ('1RM', 'PRM') THEN 'Residencial' ");
	strcat(sql, "	WHEN c.tarifa = 'APM' AND c.tipo_sum = 6 THEN 'Alumbrado Publico No Medido' ");
	strcat(sql, "	WHEN c.tarifa = 'APM' AND c.tipo_sum != 6 THEN 'Alumbrado Publico Medido' ");
	strcat(sql, "	WHEN c.tarifa = '1GM' AND c.tipo_sum = 6 THEN 'General No Medido' ");
	strcat(sql, "	WHEN c.tarifa = '1GM' AND c.tipo_sum != 6 THEN 'General Medido' ");
	strcat(sql, "	ELSE c.tarifa || ' No Transformada' ");
	strcat(sql, "END desc_tarifa, ");
	
	strcat(sql, "TRIM(t4.descripcion) voltaje, ");
	strcat(sql, "m.clave_montri ");
	strcat(sql, "FROM cliente c, tabla t1, sf_transforma t2, tabla t3, OUTER (tecni t, tabla t4), medid m ");
if(giTipoCorrida==1){	
   strcat(sql, ", migra_sf ma ");
}   
	strcat(sql, "WHERE c.estado_cliente = 0 ");
/*
	strcat(sql, "AND c.tipo_sum NOT IN ( 1, 5 ) ");
	strcat(sql, "AND c.tipo_cliente NOT IN ( 'CP', 'IP', 'JP', 'JU', 'LO', 'LS', 'OC' ) ");
	strcat(sql, "AND c.tarifa NOT IN ( '1GB', '1JB', '1JM', '1RB', 'PGM', 'PJM', 'PRB' ) ");
*/	
	strcat(sql, "AND t1.nomtabla = 'TIPSUM' ");
	strcat(sql, "AND t1.sucursal = '0000' ");
	strcat(sql, "AND t1.codigo = c.tipo_sum ");
	strcat(sql, "AND t1.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t1.fecha_desactivac IS NULL OR t1.fecha_desactivac > TODAY) ");
	strcat(sql, "AND t2.clave = 'TIPCLI3' ");
	strcat(sql, "AND t2.cod_mac = c.tipo_cliente ");
	strcat(sql, "AND t3.nomtabla = 'TARIFA' ");
	strcat(sql, "AND t3.sucursal = '0000' ");
	strcat(sql, "AND t3.codigo = c.tarifa ");
	strcat(sql, "AND t3.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t3.fecha_desactivac IS NULL OR t3.fecha_desactivac > TODAY) ");
	strcat(sql, "AND t.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND t4.nomtabla = 'VOLTA' ");
	strcat(sql, "AND t4.sucursal = '0000' ");
	strcat(sql, "AND t4.codigo = t.codigo_voltaje ");
	strcat(sql, "AND t4.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t4.fecha_desactivac IS NULL OR t4.fecha_desactivac > TODAY) ");
	strcat(sql, "AND m.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND m.estado = 'I' ");

if(giTipoCorrida==1){
   strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");
}


	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;

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



short LeoCliente(reg)
$ClsCliente *reg;
{
	InicializaCliente(reg);

	$FETCH curClientes INTO
      :reg->numero_cliente,
      :reg->potencia_inst_fp,
      :reg->potencia_contrato,
      :reg->tipo_suministro,
      :reg->tipo_cliente,
      :reg->desc_tarifa,
      :reg->voltaje,
      :reg->clave_montri;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Clientes !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			
   
   alltrim(reg->tipo_suministro, ' ');
   alltrim(reg->tipo_cliente, ' ');
   alltrim(reg->desc_tarifa, ' ');
   alltrim(reg->voltaje, ' ');
   alltrim(reg->clave_montri, ' ');
   
            
	return 1;	
}

void InicializaCliente(reg)
$ClsCliente	*reg;
{

   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CDOUBLETYPE, (char *) &(reg->potencia_inst_fp));
   rsetnull(CDOUBLETYPE, (char *) &(reg->potencia_contrato));
   
   memset(reg->tipo_suministro, '\0', sizeof(reg->tipo_suministro));
   memset(reg->tipo_cliente, '\0', sizeof(reg->tipo_cliente));
   memset(reg->desc_tarifa, '\0', sizeof(reg->desc_tarifa));
   memset(reg->voltaje, '\0', sizeof(reg->voltaje));
   memset(reg->clave_montri, '\0', sizeof(reg->clave_montri));

}


short GenerarPlanoAsset(reg)
$ClsCliente		reg;
{
	char	sLinea[1000];	
	int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));

	/* Identificador activo */
	sprintf(sLinea, "\"%ld\";", reg.numero_cliente );
	
	/* Tipo cliente */
	strcat(sLinea, "\"Tarifa T1\";");
	   
	/* Potencia */
	if(reg.potencia_inst_fp > 0.00){
		sprintf(sLinea, "%s\"%.02lf\";", sLinea, reg.potencia_inst_fp);
	}else{
		sprintf(sLinea, "%s\"%.02lf\";", sLinea, reg.potencia_contrato);
	}
	
	
	/* Tipo suministro */
	sprintf(sLinea, "%s\"%s\";", sLinea, reg.tipo_suministro);
	
	/* Clase servicio */
	sprintf(sLinea, "%s\"%s\";", sLinea, reg.tipo_cliente);
	
	/* Tarifa */
	sprintf(sLinea, "%s\"%s\";", sLinea, reg.desc_tarifa);
	
	/* Valor tension */
	sprintf(sLinea, "%s\"%s\";", sLinea, reg.voltaje);
	
	/* Tipo tension */
	strcat(sLinea, "\"Baja Tension\";");
	
	/* Nivel */
	if(reg.clave_montri[0]=='M') {
		strcat(sLinea, "\"Monofasico\";");
	}else{
		strcat(sLinea, "\"Trifasico\";");
	}

	strcat(sLinea, "\n");
	
	iRcv=fprintf(pFileAsset, sLinea);
   if(iRcv<0){
      printf("Error al grabar ASSET2\n");
      exit(1);
   }
   	

	
	return 1;
}

short GenerarPlanoCtasCto(reg)
$ClsCliente		reg;
{
	char	sLinea[1000];	
	int   iRcv;
   
	memset(sLinea, '\0', sizeof(sLinea));

	/* Activo */
	sprintf(sLinea, "\"X\";" );
	
	/* Contacto */
	sprintf(sLinea, "%s\"%ld\";", sLinea, reg.numero_cliente );
	
	/* Cuenta */
	sprintf(sLinea, "%s\"%ld\";", sLinea, reg.numero_cliente );
	
	/* Directo */
	strcat(sLinea, "\"X\";");
	
	/* Fecha Finalizacion */
	strcat(sLinea, "\"\";");
	
	/* Fecha inicio */
	strcat(sLinea, "\"\";");
	
	/* Funcionales */
	strcat(sLinea, "\"\";");


	strcat(sLinea, "\n");
	
	iRcv=fprintf(pFileCtasCto, sLinea);
   if(iRcv<0){
      printf("Error al grabar CtasContacto\n");
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


