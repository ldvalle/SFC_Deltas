/*********************************************************************************
    Proyecto: Migracion al sistema SALES-FORCES
    Aplicacion: sfc_device
    
	Fecha : 03/01/2018

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura DEVICE (medidores)
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		
********************************************************************************/
#include <locale.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sfc_device.h";

/* Variables Globales */
int   giTipoCorrida;

FILE	*pFileMedidorUnx;

char	sArchMedidorUnx[100];
char	sArchMedidorAux[100];
char	sArchMedidorDos[100];
char	sSoloArchivoMedidor[100];

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
$ClsMedidor	regMedidor;
$long glFechaDesde;
$long glFechaHasta;
$char dtDesde[17];
$char dtHasta[17];
$char dtDesdeG[20];
$char dtHastaG[20];

char	sMensMail[1024];	

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
FILE	*fp;
int		iFlagMigra=0;
int 	iFlagEmpla=0;
$ClsModif   regModif;
$ClsCamTit  regCamTit;

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
   setlocale(LC_ALL, "es_ES.UTF-8");
   setlocale(LC_NUMERIC, "en_US");
   
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT 600;
	$SET ISOLATION TO DIRTY READ;
	
   CreaPrepare();

	/* *********************************************
				INICIO AREA DE PROCESO
	********************************************** */
	if(!AbreArchivos()){
		exit(1);	
	}

	cantProcesada=0;
	cantPreexistente=0;
	iContaLog=0;

	/*********************************************
				AREA CURSOR ESTOC
	**********************************************/
   $OPEN curEstoc USING :glFechaDesde, :glFechaHasta;

   while(LeoEstoc(&regModif)){
      if(getDataMedidor(regModif, &regMedidor, "I")){
			/* Le tengo que buscar la lectura tipo 7 */
			if(! getLecturaFecha(&regModif, "NVO", "I")){
				exit(1);	
			}
   		if (!GenerarPlano(pFileMedidorUnx, regModif, regMedidor, "I")){
            printf("Fallo GenearPlano\n");
   			exit(1);	
   		}
         cantProcesada++;
      }
   }

   $CLOSE curEstoc;
	
	/*********************************************
				AREA CURSOR MODIF
	**********************************************/
   if( giTipoCorrida != 4){
      $OPEN curModif USING :dtDesde, :dtHasta;
   
      while(LeoModif(&regModif)){
         if(regModif.nroMedidorRet > 0){
				/* levantar la lectura tipo  5 con la fecha modif */
            if(getDataMedidor(regModif, &regMedidor, "R")){
					if(! getLecturaFecha(&regModif, "MOD", "R")){
						exit(1);	
					}
					
         		if (!GenerarPlano(pFileMedidorUnx, regModif, regMedidor, "R")){
                  printf("Fallo GenearPlano\n");
         			exit(1);	
         		}
               cantProcesada++;
            }
         }
         
         if(regModif.nroMedidorInst > 0){
				/* levantar la lectura tipo  6 con la fecha modif */
            if(getDataMedidor(regModif, &regMedidor, "I")){
					if(! getLecturaFecha(&regModif, "MOD", "I")){
						exit(1);	
					}					
         		if (!GenerarPlano(pFileMedidorUnx, regModif, regMedidor, "I")){
                  printf("Fallo GenearPlano\n");
         			exit(1);	
         		}
               cantProcesada++;
            }
         }
         
      }
   
      $CLOSE curModif;
   }
   
   /*************************/
   /* Cambio de Titularidad */
   /*************************/
   
   $OPEN curCamTit USING :dtDesdeG, :dtHastaG;
   
   while(LeoCamTit(&regCamTit, &regMedidor)){
		/* La ultima lectura del cliente antecesor */
		if(!getLecturaCT(&regCamTit, "R")){
			exit(1);
		}
      if(! GenerarPlanoCT(pFileMedidorUnx, regCamTit, regMedidor, "R")){
         printf("Fallo GenearPlanoCT R\n");
   		exit(1);	
      }
      cantProcesada++;
		/* La lectura tipo 7 del cliente sucesor */
		if(!getLecturaCT(&regCamTit, "I")){
			exit(1);
		}		
      if(! GenerarPlanoCT(pFileMedidorUnx, regCamTit, regMedidor, "I")){
         printf("Fallo GenearPlanoCT I\n");
   		exit(1);	
      }
      cantProcesada++;
      
   }

   $CLOSE curCamTit;
   
      
/*
   if(giTipoCorrida != 3){
	  $OPEN curMedidores;
   }else{
	  $OPEN curMedidores USING :glFechaDesde, :glFechaHasta;   
   }

	fp=pFileMedidorUnx;

	while(LeoMedidores(&regMedidor)){
      if(!CargaEstadoSFC(&regMedidor)){
         printf("Fallo CargaEstadoSFC\n");
         exit(1);
      }
		if (!GenerarPlano(fp, regMedidor)){
         printf("Fallo GenearPlano\n");
			exit(1);	
		}
					
		cantProcesada++;
	}
	
	$CLOSE curMedidores;
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
	printf("DEVICE\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Medidores Procesados :       %ld \n",cantProcesada);
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

   memset(dtDesde, '\0', sizeof(dtDesde));
   memset(dtHasta, '\0', sizeof(dtHasta));

   memset(dtDesdeG, '\0', sizeof(dtDesdeG));
   memset(dtHastaG, '\0', sizeof(dtHastaG));

	if(argc < 3 || argc >5 ){
		MensajeParametros();
		return 0;
	}

   giTipoCorrida = atoi(argv[2]);

   if(argc == 5){
      giTipoCorrida= atoi(argv[2]);/* Modo Delta 3 */
      strcpy(sFechaDesde, argv[3]); 
      strcpy(sFechaHasta, argv[4]);
      
      sprintf(gsDesdeFmt, "%c%c%c%c%c%c%c%c", sFechaDesde[6], sFechaDesde[7],sFechaDesde[8],sFechaDesde[9],
                  sFechaDesde[3],sFechaDesde[4], sFechaDesde[0],sFechaDesde[1]);      

      sprintf(gsHastaFmt, "%c%c%c%c%c%c%c%c", sFechaHasta[6], sFechaHasta[7],sFechaHasta[8],sFechaHasta[9],
                  sFechaHasta[3],sFechaHasta[4], sFechaHasta[0],sFechaHasta[1]);      

      sprintf(dtDesde, "%c%c%c%c-%c%c-%c%c 00:00", sFechaDesde[6], sFechaDesde[7],sFechaDesde[8],sFechaDesde[9],
                  sFechaDesde[3],sFechaDesde[4], sFechaDesde[0],sFechaDesde[1]);      

      sprintf(dtHasta, "%c%c%c%c-%c%c-%c%c 23:59", sFechaHasta[6], sFechaHasta[7],sFechaHasta[8],sFechaHasta[9],
                  sFechaHasta[3],sFechaHasta[4], sFechaHasta[0],sFechaHasta[1]);      

      sprintf(dtDesdeG, "%s:00", dtDesde);
      sprintf(dtHastaG, "%s:59", dtHasta);
      
      rdefmtdate(&glFechaDesde, "dd/mm/yyyy", sFechaDesde); 
      rdefmtdate(&glFechaHasta, "dd/mm/yyyy", sFechaHasta); 
   }else{
      glFechaDesde=-1;
      glFechaHasta=-1;
   }
   
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
      printf("	<Tipo Corrida> 0=Normal, 1=Reducida, 3=Delta.\n");
      printf("	<Fecha Desde (Opcional)> dd/mm/aaaa.\n");
      printf("	<Fecha Hasta (Opcional)> dd/mm/aaaa.\n");
      
}

short AbreArchivos()
{
   char  sTitulos[10000];
   $char sFecha[9];
   int   iRcv;
   
   memset(sTitulos, '\0', sizeof(sTitulos));
	
	memset(sArchMedidorUnx,'\0',sizeof(sArchMedidorUnx));
	memset(sArchMedidorAux,'\0',sizeof(sArchMedidorAux));
   memset(sArchMedidorDos,'\0',sizeof(sArchMedidorDos));
   memset(sFecha,'\0',sizeof(sFecha));
	memset(sSoloArchivoMedidor,'\0',sizeof(sSoloArchivoMedidor));

	memset(sPathSalida,'\0',sizeof(sPathSalida));

   FechaGeneracionFormateada(sFecha);
   
	RutaArchivos( sPathSalida, "SALESF" );
   
	alltrim(sPathSalida,' ');

	sprintf( sArchMedidorUnx  , "%sT1DEVICE.unx", sPathSalida );
   sprintf( sArchMedidorAux  , "%sT1DEVICE.aux", sPathSalida );
   sprintf( sArchMedidorDos  , "%senel_care_device_t1_%s_%s.csv", sPathSalida, gsDesdeFmt, gsHastaFmt);

	strcpy( sSoloArchivoMedidor, "T1DEVICE.unx");

	pFileMedidorUnx=fopen( sArchMedidorUnx, "w" );
	if( !pFileMedidorUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchMedidorUnx );
		return 0;
	}
	
   strcpy(sTitulos,"\"Marca Medidor\";\"Modelo Medidor\";\"Nro.Medidor\";\"Propiedad Medidor\";\"Tipo Medidor\";\"Punto de Suministro\";\"External ID\";\"Estado Medidor\";\"Constante\";\"Fecha Instalacion\";\"Fecha Retiro\";\"Fecha Fabricacion\";\n");

   iRcv=fprintf(pFileMedidorUnx, sTitulos);
   if(iRcv<0){
      printf("Error al grabar DEVICE\n");
      exit(1);
   }
   
      
	return 1;	
}

void CerrarArchivos(void)
{
	fclose(pFileMedidorUnx);

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

   sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchMedidorUnx, sArchMedidorAux);
	iRcv=system(sCommand);

   sprintf(sCommand, "iconv -f WINDOWS-1252 -t UTF-8 %s > %s ", sArchMedidorAux, sArchMedidorDos);
   iRcv=system(sCommand);
   
	sprintf(sCommand, "chmod 777 %s", sArchMedidorDos);
	iRcv=system(sCommand);

	
	sprintf(sCommand, "cp %s %s", sArchMedidorDos, sPathCp);
	iRcv=system(sCommand);
  
   sprintf(sCommand, "rm %s", sArchMedidorUnx);
   iRcv=system(sCommand);

   sprintf(sCommand, "rm %s", sArchMedidorAux);
   iRcv=system(sCommand);

   sprintf(sCommand, "rm %s", sArchMedidorDos);
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

   /****** Cursor Modif *****/
   $PREPARE selModif FROM "SELECT numero_cliente, 
      codigo_modif, 
      TRIM(proced), 
      fecha_modif,
      TO_CHAR(fecha_modif, '%Y-%m-%d'), 
      TRIM(dato_anterior), 
      TRIM(dato_nuevo),
      DATE(fecha_modif) 
      FROM modif
      WHERE fecha_modif BETWEEN ? AND ?
      AND codigo_modif IN (59, 500)
      ORDER BY fecha_modif ASC ";
   
   $DECLARE curModif CURSOR FOR selModif;   
    
   /****** Cursor Alta Pura *****/    
   $PREPARE selEstoc FROM "SELECT e.numero_cliente,
      TO_CHAR(e.fecha_traspaso, '%Y-%m-%d'),
      m.numero_medidor,
      m.marca_medidor,
      m.modelo_medidor
      FROM estoc e, medid m
      WHERE e.fecha_traspaso BETWEEN ? AND ?
      AND m.numero_cliente = e.numero_cliente
      AND m.estado = 'I' ";
      
   $DECLARE curEstoc CURSOR FOR selEstoc;
    
	/******** Cursor Principal  SFC *************/
/*   
	strcpy(sql, "SELECT me.med_numero, "); 
	strcat(sql, "me.mar_codigo, "); 
	strcat(sql, "me.mod_codigo, "); 
	strcat(sql, "me.med_estado, ");
	strcat(sql, "me.med_ubic, ");
	strcat(sql, "me.med_codubic, ");
	strcat(sql, "me.numero_cliente, ");
	strcat(sql, "mo.tipo_medidor, ");
	strcat(sql, "TO_CHAR(m.fecha_prim_insta, '%Y-%m-%d'), ");
	strcat(sql, "TO_CHAR(m.fecha_ult_insta, '%Y-%m-%d'), ");
	strcat(sql, "m.constante, ");
	strcat(sql, "me.med_anio ");
   
	strcat(sql, "FROM medid m, medidor me, modelo mo ");
if(giTipoCorrida == 1){
   strcat(sql, ", migra_sf ma ");
}

	strcat(sql, "WHERE m.estado = 'I' ");
   
if(giTipoCorrida == 3){
	strcat(sql, "AND fecha_ult_insta BETWEEN ? AND ? ");
}   
	strcat(sql, "AND me.med_numero = m.numero_medidor ");
	strcat(sql, "AND me.mar_codigo = m.marca_medidor ");
	strcat(sql, "AND me.mod_codigo = m.modelo_medidor ");
     
	strcat(sql, "AND me.cli_tarifa = 'T1' "); 
	strcat(sql, "AND me.mar_codigo NOT IN ('000', 'AGE') "); 
	strcat(sql, "AND me.med_anio != 2019 "); 
	strcat(sql, "AND mo.mar_codigo = me.mar_codigo "); 
	strcat(sql, "AND mo.mod_codigo = me.mod_codigo "); 
if(giTipoCorrida == 1){
   strcat(sql, "AND ma.numero_cliente = m.numero_cliente ");
}   
*/
   
	$PREPARE selMedidor FROM "SELECT DISTINCT me.med_numero,
      me.mar_codigo,
      me.mod_codigo,
      me.med_estado,
      me.med_ubic, 
      me.med_codubic, 
      mo.tipo_medidor, 
      TO_CHAR(m.fecha_prim_insta, '%Y-%m-%d'), 
      TO_CHAR(m.fecha_ult_insta, '%Y-%m-%d'), 
      m.constante, 
      me.med_anio 
      FROM medid m, medidor me, modelo mo 
      WHERE m.numero_medidor = ?
      AND m.marca_medidor  = ?
      AND m.modelo_medidor = ?
      AND me.med_numero = m.numero_medidor 
      AND me.mar_codigo = m.marca_medidor 
      AND me.mod_codigo = m.modelo_medidor 
      AND mo.mar_codigo = me.mar_codigo  
      AND mo.mod_codigo = me.mod_codigo ";  

	$PREPARE selMedidorCamTit FROM "SELECT first 1 me.med_numero,
      me.mar_codigo,
      me.mod_codigo,
      me.med_estado,
      me.med_ubic, 
      me.med_codubic, 
      mo.tipo_medidor, 
      TO_CHAR(m.fecha_prim_insta, '%Y-%m-%d'), 
      TO_CHAR(m.fecha_ult_insta, '%Y-%m-%d'), 
      m.constante, 
      me.med_anio 
      FROM medid m, medidor me, modelo mo 
      WHERE m.numero_cliente = ?
      AND me.med_numero = m.numero_medidor 
      AND me.mar_codigo = m.marca_medidor 
      AND me.mod_codigo = m.modelo_medidor 
      AND mo.mar_codigo = me.mar_codigo  
      AND mo.mod_codigo = me.mod_codigo ";  
	
	/******** Select Path de Archivos ****************/
	strcpy(sql, "SELECT valor_alf ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'PATH' ");
	strcat(sql, "AND codigo = ? ");
	strcat(sql, "AND sucursal = '0000' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND ( fecha_desactivac >= TODAY OR fecha_desactivac IS NULL ) ");

	$PREPARE selRutaPlanos FROM $sql;

   /******** Cursor Cambio Titularidad ********/
   $PREPARE selCamTit FROM "SELECT s.cta_ant, s.numero_cliente, TO_CHAR(e.fecha_finalizacion, '%Y-%m-%d') 
      FROM est_sol e, solicitud s
      WHERE s.cam_tit = 'S' 
      AND s.numero_cliente IS NOT NULL 
      AND e.fecha_finalizacion BETWEEN ? AND ?
      AND s.nro_solicitud = e.nro_solicitud ";
 
   $DECLARE curCamTit CURSOR FOR selCamTit;   
   
   /* Lecturas del medidor */
   $PREPARE selLectuTipo FROM "SELECT corr_facturacion, tipo_lectura, lectura_facturac FROM hislec
		WHERE numero_cliente = ?
		AND tipo_lectura = ? ";

   $PREPARE selLectuTipoFecha1 FROM "SELECT h1.corr_facturacion, h1.tipo_lectura, h1.lectura_facturac FROM hislec h1
		WHERE h1.numero_cliente = ?
		AND h1.tipo_lectura = ? 
		AND h1.fecha_lectura = (SELECT MIN(h2.fecha_lectura) FROM hislec h2 WHERE h2.numero_cliente = h1.numero_cliente
			AND h2.tipo_lectura = h1.tipo_lectura
			AND h2.fecha_lectura >= ?) ";
			
   $PREPARE selLectuTipoFecha2 FROM "SELECT h1.corr_facturacion, h1.tipo_lectura, h1.lectura_facturac FROM hislec h1
		WHERE h1.numero_cliente = ?
		AND h1.tipo_lectura = ? 
		AND h1.fecha_lectura = (SELECT MAX(h2.fecha_lectura) FROM hislec h2 WHERE h2.numero_cliente = h1.numero_cliente
			AND h2.tipo_lectura = h1.tipo_lectura
			AND h2.fecha_lectura <= ?) ";			
   
   $PREPARE selUltimaLectu FROM "SELECT FIRST 1 h.corr_facturacion, h.tipo_lectura, h.lectura_facturac FROM cliente c, hislec h
		WHERE c.numero_cliente = ?
		AND h.numero_cliente = c.numero_cliente
		AND h.corr_facturacion = c.corr_facturacion
		AND h.fecha_lectura = (SELECT MAX(h2.fecha_lectura) FROM hislec h2
			WHERE h2.numero_cliente = c.numero_cliente
			AND h2.corr_facturacion = c.corr_facturacion) ";
		
	$PREPARE selLectuRefac FROM "SELECT h1.lectura_rectif FROM hislec_refac h1
		WHERE h1.numero_cliente = ?
		AND h1.corr_facturacion = ?
		AND h1.tipo_lectura = ?
		AND h1.corr_hislec_refac = (SELECT MAX(h2.corr_hislec_refac) FROM hislec_refac h2
		WHERE h2.numero_cliente = h1.numero_cliente
			AND h2.corr_facturacion = h1.corr_facturacion
			AND h2.tipo_lectura = h1.tipo_lectura ) ";
			
			
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

short LeoMedidores(regMed)
$ClsMedidor *regMed;
{
	InicializaMedidor(regMed);

	$FETCH curMedidores into
		:regMed->numero,
		:regMed->marca,
		:regMed->modelo,
		:regMed->estado,	
		:regMed->med_ubic, 
		:regMed->med_codubic,
		:regMed->numero_cliente,
		:regMed->tipo_medidor,
		:regMed->fecha_prim_insta,
		:regMed->fecha_ult_insta,
		:regMed->constante,
		:regMed->med_anio;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de Medidores !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

	
	return 1;	
}

void InicializaMedidor(regMed)
$ClsMedidor	*regMed;
{
   rsetnull(CLONGTYPE, (char *) &(regMed->numero));
	memset(regMed->marca, '\0', sizeof(regMed->marca));
	memset(regMed->modelo, '\0', sizeof(regMed->modelo));
   memset(regMed->estado, '\0', sizeof(regMed->estado));
	memset(regMed->med_ubic, '\0', sizeof(regMed->med_ubic));
	memset(regMed->med_codubic, '\0', sizeof(regMed->med_codubic));
	rsetnull(CLONGTYPE, (char *) &(regMed->numero_cliente));
	memset(regMed->tipo_medidor, '\0', sizeof(regMed->tipo_medidor));
   memset(regMed->estado_sfc, '\0', sizeof(regMed->estado_sfc));
   memset(regMed->fecha_prim_insta, '\0', sizeof(regMed->fecha_prim_insta));
   memset(regMed->fecha_ult_insta, '\0', sizeof(regMed->fecha_ult_insta));
	rsetnull(CFLOATTYPE, (char *) &(regMed->constante));
	rsetnull(CINTTYPE, (char *) &(regMed->med_anio));
	
}

short CargaEstadoSFC(regMed)
$ClsMedidor *regMed;
{

   switch(regMed->estado[0]){
      case 'Z':
      case 'U':
         /* No Disponible*/
         strcpy(regMed->estado_sfc, "R");
         break;
      default:
      	switch(regMed->med_ubic[0]){
      		case 'C':	/* En el cliente*/
               strcpy(regMed->estado_sfc, "I");
               break;
            case 'D':  /* Bodega */
            case 'L':  /* Laboratorio */
            case 'F':  /* En Fabrica */
               strcpy(regMed->estado_sfc, "R");
               break;
            case 'O':  /* Contratista */
            case 'S':	/* En Sucursal */
               strcpy(regMed->estado_sfc, "D");
               break;
         }
         break;
   }
	
	return 1;
}

short GenerarPlano(fp, regMod, regMed, accion)
FILE 				*fp;
ClsModif       regMod;
$ClsMedidor		regMed;
char           accion[2];
{
	char	sLinea[1000];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));
	
   /* Marca Medidor */
   sprintf(sLinea, "\"%s\";", regMed.marca);
   
   /* Modelo Medidor */
   sprintf(sLinea, "%s\"%s\";", sLinea, regMed.modelo);
   
   /* Nro.Medidor */
   sprintf(sLinea, "%s\"%ld\";", sLinea, regMed.numero);
   
   /* Propiedad */
   strcat(sLinea, "\"C\";");
   
   /* Tipo Medidor */
   if(regMed.tipo_medidor[0]=='R'){
      strcat(sLinea, "\"REAC\";");
   }else{
      strcat(sLinea, "\"ACTI\";");
   }
   
   /* Punto Suministro */
   sprintf(sLinea, "%s\"%ldAR\";", sLinea, regMod.numero_cliente);
/*   
   if(regMed.med_ubic[0]=='C'){
      if(regMed.numero_cliente > 0){
         sprintf(sLinea, "%s\"%ldAR\";", sLinea, regMed.numero_cliente);
      }else{
         strcat(sLinea, "\"\";");
      }
   }else{
      strcat(sLinea, "\"\";");
   }
*/
   
   /* External ID */
   sprintf(sLinea, "%s\"%ld%09ld%s%sDEVARG\";", sLinea, regMod.numero_cliente, regMed.numero, regMed.marca, regMed.modelo);
   
   /* Estado Medidor */
   if(accion[0]=='R'){
      strcat(sLinea, "\"R\";");
   }else{
      strcat(sLinea, "\"I\";");
   }   
/*   
   sprintf(sLinea, "%s\"%s\";", sLinea, regMed.estado_sfc);
*/

   /* Constante */
   sprintf(sLinea, "%s\"%.02f\";", sLinea, regMed.constante);
   
   /* Fecha Instalacion */
   if(accion[0]!='R'){
      sprintf(sLinea, "%s\"%s\";", sLinea, regMod.sFechaModif);
   }else{
      strcat(sLinea, "\"\";");
   }
   
   /* Fecha Retiro */
   if(accion[0]=='R'){
      sprintf(sLinea, "%s\"%s\";", sLinea, regMod.sFechaModif);
   }else{
      strcat(sLinea, "\"\";");
   }
   
   /* Fecha Fabricación */
   sprintf(sLinea, "%s\"%d\";", sLinea, regMed.med_anio);
	
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv<0){
      printf("Error al grabar DEVICE\n");
      exit(1);
   }
   	

	
	return 1;
}


short GenerarPlanoCT(fp, regCT, regMed, accion)
FILE 				*fp;
ClsCamTit      regCT;
$ClsMedidor		regMed;
char           accion[2];
{
	char	sLinea[1000];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));
	
   /* Marca Medidor */
   sprintf(sLinea, "\"%s\";", regMed.marca);
   
   /* Modelo Medidor */
   sprintf(sLinea, "%s\"%s\";", sLinea, regMed.modelo);
   
   /* Nro.Medidor */
   sprintf(sLinea, "%s\"%ld\";", sLinea, regMed.numero);
   
   /* Propiedad */
   strcat(sLinea, "\"C\";");
   
   /* Tipo Medidor */
   if(regMed.tipo_medidor[0]=='R'){
      strcat(sLinea, "\"REAC\";");
   }else{
      strcat(sLinea, "\"ACTI\";");
   }
   
   /* Punto Suministro */
   if(accion[0]=='R'){
      sprintf(sLinea, "%s\"%ldAR\";", sLinea, regCT.nroClienteAnterior);
   }else{
      sprintf(sLinea, "%s\"%ldAR\";", sLinea, regCT.nroClienteActual);
   }
   
   /* External ID */
   if(accion[0]=='R'){
      sprintf(sLinea, "%s\"%ld%09ld%s%sDEVARG\";", sLinea, regCT.nroClienteAnterior, regMed.numero, regMed.marca, regMed.modelo);
   }else{
      sprintf(sLinea, "%s\"%ld%09ld%s%sDEVARG\";", sLinea, regCT.nroClienteActual, regMed.numero, regMed.marca, regMed.modelo);
   }
   
   /* Estado Medidor */
   if(accion[0]=='R'){
      strcat(sLinea, "\"R\";");
   }else{
      strcat(sLinea, "\"I\";");
   }   

   /* Constante */
   sprintf(sLinea, "%s\"%.02f\";", sLinea, regMed.constante);
   
   /* Fecha Instalacion */
   if(accion[0]!='R'){
      sprintf(sLinea, "%s\"%s\";", sLinea, regCT.sFechaEvento);
   }else{
      strcat(sLinea, "\"\";");
   }
   
   /* Fecha Retiro */
   if(accion[0]=='R'){
      sprintf(sLinea, "%s\"%s\";", sLinea, regCT.sFechaEvento);
   }else{
      strcat(sLinea, "\"\";");
   }
   
   /* Fecha Fabricación */
   sprintf(sLinea, "%s\"%d\";", sLinea, regMed.med_anio);
	
	strcat(sLinea, "\n");
	
	iRcv=fprintf(fp, sLinea);
   if(iRcv<0){
      printf("Error al grabar DEVICE\n");
      exit(1);
   }
   	

	
	return 1;
}


short LeoModif(reg)
$ClsModif   *reg;
{
   InicializoModif(reg);
   
   $FETCH curModif INTO :reg->numero_cliente,
      :reg->codModif,
      :reg->proced,
      :reg->dtFechaModif,
      :reg->sFechaModif,
      :reg->datoViejo,
      :reg->datoNuevo,
      :reg->lFechaModif;
   
   if(SQLCODE != 0){
      return 0;
   }   
   
   alltrim(reg->codModif, ' ');
   alltrim(reg->proced, ' ');
   alltrim(reg->datoViejo, ' ');
   alltrim(reg->sFechaModif, ' ');
   alltrim(reg->dtFechaModif, ' ');
   
   ExtraeMedidores(reg);
   
   
   return 1;
}

short LeoEstoc(reg)
$ClsModif   *reg;
{
   InicializoModif(reg);
   
   $FETCH curEstoc INTO :reg->numero_cliente,
      :reg->sFechaModif,
      :reg->nroMedidorInst,
      :reg->marcaMedidorInst,
      :reg->modeloMedidorInst;
  
   if(SQLCODE != 0){
      return 0;
   }   
   
   alltrim(reg->sFechaModif, ' ');
   
   return 1;
}


void InicializoModif(reg)
$ClsModif   *reg;
{

   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   memset(reg->codModif, '\0', sizeof(reg->codModif));
   memset(reg->proced, '\0', sizeof(reg->proced));
   memset(reg->dtFechaModif, '\0', sizeof(reg->dtFechaModif));
   memset(reg->sFechaModif, '\0', sizeof(reg->sFechaModif));
   memset(reg->datoViejo, '\0', sizeof(reg->datoViejo));
   memset(reg->datoNuevo, '\0', sizeof(reg->datoNuevo));      
   rsetnull(CLONGTYPE, (char *) &(reg->nroMedidorRet));
   memset(reg->marcaMedidorRet, '\0', sizeof(reg->marcaMedidorRet));
   memset(reg->modeloMedidorRet, '\0', sizeof(reg->modeloMedidorRet));      
   rsetnull(CLONGTYPE, (char *) &(reg->nroMedidorInst));
   memset(reg->marcaMedidorInst, '\0', sizeof(reg->marcaMedidorInst));
   memset(reg->modeloMedidorInst, '\0', sizeof(reg->modeloMedidorInst));      
   
   rsetnull(CDOUBLETYPE, (char *) &(reg->lecturaInstalacion));
   rsetnull(CDOUBLETYPE, (char *) &(reg->lecturaRetiro));
	rsetnull(CLONGTYPE, (char *) &(reg->lFechaModif));
}

void ExtraeMedidores(reg)
ClsModif *reg;
{
const char patronInv[4]=" | ";
const char patronManser[2]="-";

char    sNro[10];
char    sMarca[4];
char    sModelo[3];
char    *token;


   if(strcmp(reg->codModif, "59")==0 && strcmp(reg->proced, "MANSER")==0){
      /* MANSER */
      if(strlen(reg->datoViejo)>0){
          token=strtok(reg->datoViejo, patronManser);
          reg->nroMedidorRet = atol(token);
          token=strtok(NULL, patronManser);
          alltrim(token, ' ');
          strcpy(reg->marcaMedidorRet, token);
          token=strtok(NULL, patronManser);
          alltrim(token, ' ');
          strcpy(reg->modeloMedidorRet, token);
      }
      
      if(strlen(reg->datoNuevo)>0){
          token=strtok(reg->datoNuevo, patronManser);
          reg->nroMedidorInst = atol(token);
          token=strtok(NULL, patronManser);
          alltrim(token, ' ');
          strcpy(reg->marcaMedidorInst, token);
          token=strtok(NULL, patronManser);
          alltrim(token, ' ');
          strcpy(reg->modeloMedidorInst, token);
      }   
         
   }else{
      /* INVERSION */
      if(strlen(reg->datoViejo)>0){
          token=strtok(reg->datoViejo, patronInv);
          reg->nroMedidorRet = atol(token);
          token=strtok(NULL, patronInv);
          alltrim(token, ' ');
          strcpy(reg->marcaMedidorRet, token);
          token=strtok(NULL, patronInv);
          alltrim(token, ' ');
          strcpy(reg->modeloMedidorRet, token);
      }
      
      if(strlen(reg->datoNuevo)>0){
          token=strtok(reg->datoNuevo, patronInv);
          reg->nroMedidorInst = atol(token);
          token=strtok(NULL, patronInv);
          alltrim(token, ' ');
          strcpy(reg->marcaMedidorInst, token);
          token=strtok(NULL, patronInv);
          alltrim(token, ' ');
          strcpy(reg->modeloMedidorInst, token);
      }   
      
      
   }


}

short getDataMedidor(regMod, regMed, accion)
$ClsModif   regMod;
$ClsMedidor *regMed;
char        accion[2];
{

$long lNroMedidor;
$char sMarca[4];
$char sModelo[3];

   if(accion[0]=='R'){
      lNroMedidor=regMod.nroMedidorRet;
      strcpy(sMarca, regMod.marcaMedidorRet);
      strcpy(sModelo, regMod.modeloMedidorRet);
   }else{
      lNroMedidor=regMod.nroMedidorInst;
      strcpy(sMarca, regMod.marcaMedidorInst);
      strcpy(sModelo, regMod.modeloMedidorInst);
   }

	InicializaMedidor(regMed);

	$EXECUTE selMedidor INTO
		:regMed->numero,
		:regMed->marca,
		:regMed->modelo,
		:regMed->estado,	
		:regMed->med_ubic, 
		:regMed->med_codubic,
		:regMed->tipo_medidor,
		:regMed->fecha_prim_insta,
		:regMed->fecha_ult_insta,
		:regMed->constante,
		:regMed->med_anio
   USING :lNroMedidor,
         :sMarca,
         :sModelo;
	
    if ( SQLCODE != 0 ){
		printf("Error al leer Medidor %ld %s %s de cliente %ld!!!\nProceso Abortado.\n", lNroMedidor, sMarca, sModelo, regMod.numero_cliente);
		return 0;	
    }			

   return 1;
}

short LeoCamTit(regTit, regMed)
$ClsCamTit  *regTit;
$ClsMedidor *regMed;
{
   
   InicializaCamTit(regTit);

   $FETCH curCamTit INTO :regTit->nroClienteAnterior,
                        :regTit->nroClienteActual,
                        :regTit->sFechaEvento;
   
   if(SQLCODE != 0)
      return 0;
      
      
   /*  Recuperar el medidor  */
   $EXECUTE selMedidorCamTit INTO
		:regMed->numero,
		:regMed->marca,
		:regMed->modelo,
		:regMed->estado,	
		:regMed->med_ubic, 
		:regMed->med_codubic,
		:regMed->tipo_medidor,
		:regMed->fecha_prim_insta,
		:regMed->fecha_ult_insta,
		:regMed->constante,
		:regMed->med_anio
   USING :regTit->nroClienteActual;
   
   if(SQLCODE != 0){
      printf("No pude recuperar medidor para cliente %ld\n", regTit->nroClienteActual);
   }
   
   return 1;
}

void InicializaCamTit(reg)
$ClsCamTit  *reg;
{
   rsetnull(CLONGTYPE, (char *) &(reg->nroClienteAnterior));
   rsetnull(CLONGTYPE, (char *) &(reg->nroClienteActual));
   memset(reg->sFechaEvento, '\0', sizeof(reg->sFechaEvento));
   
   rsetnull(CDOUBLETYPE, (char *) &(reg->lecturaInstalacion));
   rsetnull(CDOUBLETYPE, (char *) &(reg->lecturaRetiro));   
}

short getLecturaFecha(reg, modulo, tipo)
$ClsModif *reg;
char		modulo[4];
char		tipo[1];
{
	$int  iCorrFactu;
	$int  iTipoLectu;
	$double  dLectura;
	$int  iParTipo;
	$long lFecha;
	
   rsetnull(CDOUBLETYPE, (char *) &(reg->lecturaInstalacion));
   rsetnull(CDOUBLETYPE, (char *) &(reg->lecturaRetiro)); 	
	
	rsetnull(CINTTYPE, (char *) &(iCorrFactu));
	rsetnull(CINTTYPE, (char *) &(iTipoLectu));
	rsetnull(CDOUBLETYPE, (char *) &(dLectura));
	rsetnull(CLONGTYPE, (char *) &(lFecha));
	
	if(strcmp(modulo,"NVO")==0){
		iParTipo=7;
		$EXECUTE selLectuTipo INTO :iCorrFactu, :iTipoLectu, :dLectura
			USING :reg->numero_cliente,
					:iParTipo;
	}else if(strcmp(modulo,"MOD")==0){
		switch(tipo[0]){
			case 'I':
				iParTipo=6;
				break;
			case 'R':
				iParTipo=5;
				break;
		}


		/*rdefmtdate(&lFecha, "yyyy-mm-dd HH:MM", reg->dtFechaModif); char a long
		printf("Fechas [%s] [%ld]\n", reg->dtFechaModif, reg->lFechaModif);
		*/
		lFecha = reg->lFechaModif + 7;

		$EXECUTE selLectuTipoFecha1 INTO :iCorrFactu, :iTipoLectu, :dLectura
			USING :reg->numero_cliente,
					:iParTipo,
					:reg->lFechaModif;
					
		if(SQLCODE == 100){
			rsetnull(CDOUBLETYPE, (char *) &(dLectura));
			
			$EXECUTE selLectuTipoFecha2 INTO :iCorrFactu, :iTipoLectu, :dLectura
				USING :reg->numero_cliente,
						:iParTipo,
						:reg->lFechaModif;			
		}
	}

	if(SQLCODE != 0){
		printf("No se encontró lectura para cliente %ld Modulo %s\n", reg->numero_cliente, modulo);
		return 1;
	}

	switch(tipo[0]){
		case 'I':
			reg->lecturaInstalacion = dLectura;
			break;
			
		case 'R':
			reg->lecturaRetiro = dLectura;
			break;
	}
	
	/* Me fijo si fué actualizada */
	rsetnull(CDOUBLETYPE, (char *) &(dLectura));
	
	$EXECUTE selLectuRefac INTO :dLectura 
		USING :reg->numero_cliente,
				:iCorrFactu,
				:iTipoLectu;

	if(SQLCODE == 0){
		switch(tipo[0]){
			case 'I':
				reg->lecturaInstalacion = dLectura;
				break;
				
			case 'R':
				reg->lecturaRetiro = dLectura;
				break;
		}		
	}
		
	return 1;
}

short getLecturaCT(reg, tipo)
$ClsCamTit *reg;
$char		tipo[2];
{
	$int  iCorrFactu;
	$int  iTipoLectu;
	$double  dLectura;
	$int  iParTipo;
	$long lFecha;
	$long lNroCliente;
	
   rsetnull(CDOUBLETYPE, (char *) &(reg->lecturaInstalacion));
   rsetnull(CDOUBLETYPE, (char *) &(reg->lecturaRetiro)); 	
	
	rsetnull(CINTTYPE, (char *) &(iCorrFactu));
	rsetnull(CINTTYPE, (char *) &(iTipoLectu));
	rsetnull(CDOUBLETYPE, (char *) &(dLectura));
	rsetnull(CLONGTYPE, (char *) &(lFecha));
	rsetnull(CLONGTYPE, (char *) &(lNroCliente));
	
	switch(tipo[0]){
		case 'I':
			iParTipo=7;
			lNroCliente = reg->nroClienteActual;
			
			$EXECUTE selLectuTipo INTO :iCorrFactu, :iTipoLectu, :dLectura
				USING :reg->nroClienteActual,
						:iParTipo;			
			
			break;
		case 'R':
			lNroCliente = reg->nroClienteAnterior;
			
			$EXECUTE selUltimaLectu INTO :iCorrFactu, :iTipoLectu, :dLectura
				USING :reg->nroClienteAnterior;
				
			break;
	}
	
	if(SQLCODE != 0){
		if(tipo[0]=='I'){
			printf("No se encontró lectura para cliente Actual %ld\n", reg->nroClienteActual);
		}else{
			printf("No se encontró lectura para cliente Anterior %ld\n", reg->nroClienteAnterior);
		}
		return 1;
	}

	switch(tipo[0]){
		case 'I':
			reg->lecturaInstalacion = dLectura;
			break;
			
		case 'R':
			reg->lecturaRetiro = dLectura;
			break;
	}
	
	/* Me fijo si fué actualizada */
	rsetnull(CDOUBLETYPE, (char *) &(dLectura));
	
	$EXECUTE selLectuRefac INTO :dLectura 
		USING :lNroCliente,
				:iCorrFactu,
				:iTipoLectu;

	if(SQLCODE == 0){
		switch(tipo[0]){
			case 'I':
				reg->lecturaInstalacion = dLectura;
				break;
				
			case 'R':
				reg->lecturaRetiro = dLectura;
				break;
		}		
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


