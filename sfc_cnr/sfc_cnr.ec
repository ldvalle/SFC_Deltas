/*********************************************************************************
    Proyecto: Migracion al sistema SALES-FORCES
    Aplicacion: sfc_cnr
    
	Fecha : 03/01/2018

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructura Diciplina de Mercado (CNR)
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
      <Tipo Corrida> 0=Normal 1=Reducida
		
********************************************************************************/
#include <locale.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sfc_cnr.h";

/* Variables Globales */
int   giTipoCorrida;
FILE	*pFileUnx;

char	sArchUnx[100];
char	sArchAux[100];
char	sArchDos[100];
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
$ClsCnr	regCnr;
$long    glFechaDesde;
$long    glFechaHasta;
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
long     iFactu;


	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
   setlocale(LC_ALL, "en_US.UTF-8");
   
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

   $OPEN curCNR USING :glFechaDesde, :glFechaHasta, :glFechaDesde, :glFechaHasta;

   while(LeoCnr(&regCnr)){
		if (!GenerarPlano(fp, regCnr)){
         printf("Fallo GenearPlano\n");
			exit(1);	
		}
   	
      cantProcesada++;
   }
   			
   $CLOSE curCNR;      
   
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
	printf("CNR\n");
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
   
	if(argc < 3 || argc > 5){
		MensajeParametros();
		return 0;
	}
	
   memset(sFechaDesde, '\0', sizeof(sFechaDesde));
   memset(sFechaHasta, '\0', sizeof(sFechaHasta));

   memset(gsDesdeFmt, '\0', sizeof(gsDesdeFmt));
   memset(gsHastaFmt, '\0', sizeof(gsHastaFmt));
   
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
      glFechaHasta=-1;
   }
   
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
      printf("	<Tipo Corrida> = 0=Total, 1=Reducida, 3=Delta.\n");
      printf("	<Fecha Desde (Opcional)> dd/mm/aaaa.\n");
      printf("	<Fecha Hasta (Opcional)> dd/mm/aaaa.\n");
}

short AbreArchivos()
{
   char  sTitulos[10000];
   $char sFecha[9];
   
   memset(sTitulos, '\0', sizeof(sTitulos));
	
	memset(sArchUnx,'\0',sizeof(sArchUnx));
	memset(sArchAux,'\0',sizeof(sArchAux));
   memset(sArchDos,'\0',sizeof(sArchDos));
	memset(sSoloArchivo,'\0',sizeof(sSoloArchivo));
	
   memset(sFecha,'\0',sizeof(sFecha));
   
	memset(sPathSalida,'\0',sizeof(sPathSalida));

   FechaGeneracionFormateada(sFecha);
   
	RutaArchivos( sPathSalida, "SALESF" );
   
	alltrim(sPathSalida,' ');

	sprintf( sArchUnx  , "%sT1DICIPLINA.unx", sPathSalida );
   sprintf( sArchAux  , "%sT1DICIPLINA.aux", sPathSalida );
   sprintf( sArchDos  , "%senel_care_marketdiscipline_t1_%s_%s.csv", sPathSalida, gsDesdeFmt, gsHastaFmt);

	strcpy( sSoloArchivo, "T1DICIPLINA.unx");

	pFileUnx=fopen( sArchUnx, "w" );
	if( !pFileUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchUnx );
		return 0;
	}

   strcpy(sTitulos,"\"Suministro\";");
   strcat(sTitulos, "\"Nro. Expediente\";");
   strcat(sTitulos, "\"Fecha creación expediente\";");
   strcat(sTitulos, "\"Condicion del expediente\";");
   strcat(sTitulos, "\"Año del expediente\";");
   strcat(sTitulos, "\"Fecha Inicio\";");
   strcat(sTitulos, "\"Fecha Fin\";");
   strcat(sTitulos, "\"Fecha inicio energía\";");
   strcat(sTitulos, "\"Fecha fin energía\";");
   strcat(sTitulos, "\"Estado\";");
   strcat(sTitulos, "\"Monto Expediente\";");
   strcat(sTitulos, "\"Cantidad de cuotas\";");
   strcat(sTitulos, "\"Número de medidor\";");
   strcat(sTitulos, "\"External Id\";");
   strcat(sTitulos, "\"Tipo Anomalia\";");
   strcat(sTitulos, "\"Nro.de Acta\";");

   strcat(sTitulos, "\n");
      
   fprintf(pFileUnx, sTitulos);
      
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

   sprintf(sCommand, "unix2dos %s | tr -d '\32' > %s", sArchUnx, sArchAux);
	iRcv=system(sCommand);

   sprintf(sCommand, "iconv -f WINDOWS-1252 -t UTF-8 %s > %s ", sArchAux, sArchDos);
   iRcv=system(sCommand);
   
	sprintf(sCommand, "chmod 777 %s", sArchDos);
	iRcv=system(sCommand);

	
	sprintf(sCommand, "cp %s %s", sArchDos, sPathCp);
	iRcv=system(sCommand);
  
   sprintf(sCommand, "rm %s", sArchUnx);
   iRcv=system(sCommand);

   sprintf(sCommand, "rm %s", sArchAux);
   iRcv=system(sCommand);

   sprintf(sCommand, "rm %s", sArchDos);
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

	/******** Cursor CLIENTES  ****************/	
	strcpy(sql, "SELECT c.numero_cliente FROM cliente c ");
if(giTipoCorrida==1){	
   strcat(sql, ", migra_sf ma ");
}
	
	strcat(sql, "WHERE c.estado_cliente = 0 ");
   strcat(sql, "AND c.tipo_sum != 5 ");
	/*strcat(sql, "AND c.tipo_sum NOT IN (5, 6) ");*/
	/*strcat(sql, "AND c.sector NOT IN (81, 82, 85, 88, 90) ");*/
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");	
if(giTipoCorrida==1){
   strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");
}

	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;

   /******** Cursor CNR Viejos ****************/
	strcpy(sql, "SELECT c.sucursal, ");
	strcat(sql, "c.nro_expediente, ");
	strcat(sql, "c.ano_expediente, ");
	strcat(sql, "TO_CHAR(c.fecha_deteccion, '%Y-%m-%dT%H:%M:%S.000Z'), ");
	strcat(sql, "TO_CHAR(c.fecha_inicio, '%Y-%m-%dT%H:%M:%S.000Z'), "); 
	strcat(sql, "TO_CHAR(c.fecha_finalizacion, '%Y-%m-%dT%H:%M:%S.000Z'), "); 
	strcat(sql, "c.numero_cliente, ");
	strcat(sql, "c.nro_solicitud, ");
	strcat(sql, "c.cod_estado, ");
	strcat(sql, "t1.descripcion, ");
   strcat(sql, "c.tipo_expediente, ");
   strcat(sql, "TRIM(c.cod_anomalia) || '-' || TRIM(ac.descripcion), ");
   strcat(sql, "i.sucursal_rol, ");
   strcat(sql, "i.nro_inspeccion ");
	strcat(sql, "FROM cnr_new c, tabla t1, OUTER inspecc:in_anom_comercial ac, OUTER inspecc:in_inspeccion i ");

if(giTipoCorrida==1){	
   strcat(sql, ", migra_sf ma ");
}

	strcat(sql, "WHERE c.fecha_inicio BETWEEN ? AND ? ");
   strcat(sql, "AND c.cod_estado != '99' ");
	strcat(sql, "AND t1.nomtabla = 'CNRRE' ");
	strcat(sql, "AND t1.sucursal = '0000' ");
	strcat(sql, "AND t1.codigo = c.cod_estado ");
	strcat(sql, "AND t1.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t1.fecha_desactivac IS NULL OR t1.fecha_desactivac >TODAY) ");
	strcat(sql, "AND ac.codigo = c.cod_anomalia ");
	strcat(sql, "AND i.nro_solicitud = c.in_solicitud_ap ");

if(giTipoCorrida==1){
   strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");
}
   
   strcat(sql , "UNION " );
   
 	strcat(sql, "SELECT c.sucursal, ");
	strcat(sql, "c.nro_expediente, ");
	strcat(sql, "c.ano_expediente, ");
	strcat(sql, "TO_CHAR(c.fecha_deteccion, '%Y-%m-%dT%H:%M:%S.000Z'), ");
	strcat(sql, "TO_CHAR(c.fecha_inicio, '%Y-%m-%dT%H:%M:%S.000Z'), "); 
	strcat(sql, "TO_CHAR(c.fecha_finalizacion, '%Y-%m-%dT%H:%M:%S.000Z'), "); 
	strcat(sql, "c.numero_cliente, ");
	strcat(sql, "c.nro_solicitud, ");
	strcat(sql, "c.cod_estado, ");
	strcat(sql, "t1.descripcion, ");
   strcat(sql, "c.tipo_expediente, ");
   strcat(sql, "TRIM(c.cod_anomalia) || '-' || TRIM(ac.descripcion), ");
   strcat(sql, "i.sucursal_rol, ");
   strcat(sql, "i.nro_inspeccion ");
	strcat(sql, "FROM cnr_new c, tabla t1, OUTER inspecc:in_anom_comercial ac, OUTER inspecc:in_inspeccion i ");   
   
if(giTipoCorrida==1){	
   strcat(sql, ", migra_sf ma ");
}

	strcat(sql, "WHERE c.fecha_finalizacion BETWEEN ? AND ? ");
    strcat(sql, "AND c.cod_estado != '99' ");
	strcat(sql, "AND t1.nomtabla = 'CNRRE' ");
	strcat(sql, "AND t1.sucursal = '0000' ");
	strcat(sql, "AND t1.codigo = c.cod_estado ");
	strcat(sql, "AND t1.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t1.fecha_desactivac IS NULL OR t1.fecha_desactivac >TODAY) ");
	strcat(sql, "AND ac.codigo = c.cod_anomalia ");
	strcat(sql, "AND i.nro_solicitud = c.in_solicitud_ap ");	

if(giTipoCorrida==1){
   strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");
} 
/*   
	$PREPARE selCnr FROM $sql;
	
	$DECLARE curCNR CURSOR WITH HOLD FOR selCnr;
*/
   /************ Período ultimo calculo ************/
	strcpy(sql, "SELECT FIRST 1 TO_CHAR(fecha_desde, '%Y-%m-%dT%H:%M:%S.000Z'), ");
	strcat(sql, "TO_CHAR(fecha_hasta, '%Y-%m-%dT%H:%M:%S.000Z'), ");
   strcat(sql, "total_calculo, ");
	strcat(sql, "MAX(fecha_calculo) ");
	strcat(sql, "FROM cnr_calculo "); 
	strcat(sql, "WHERE sucursal = ? ");
	strcat(sql, "AND ano_expediente = ? ");
	strcat(sql, "AND nro_expediente = ? ");
	strcat(sql, "GROUP BY 1,2,3 ");
	strcat(sql, "ORDER BY 1,2,3 ");
   
   $PREPARE selPeriodo FROM $sql;

	/********CNRs NUEVOS*******/
	strcpy(sql, "SELECT c.sucursal, ");
	strcat(sql, "c.nro_expediente, ");
	strcat(sql, "c.ano_expediente, ");
	strcat(sql, "TO_CHAR(c.fecha_deteccion, '%Y-%m-%dT%H:%M:%S.000Z'), ");
	strcat(sql, "TO_CHAR(c.fecha_inicio, '%Y-%m-%dT%H:%M:%S.000Z'), "); 
	strcat(sql, "TO_CHAR(c.fecha_finalizacion, '%Y-%m-%dT%H:%M:%S.000Z'), "); 
	strcat(sql, "TO_CHAR(c.fecha_estado, '%Y-%m-%dT%H:%M:%S.000Z'), "); 
	strcat(sql, "c.numero_cliente, ");
	strcat(sql, "c.nro_solicitud, ");
	strcat(sql, "c.cod_estado, ");
	strcat(sql, "t1.descripcion, ");
	strcat(sql, "ac.categoria, ");
	strcat(sql, "TRIM(c.cod_anomalia) || '-' || TRIM(ac.descripcion1), ");
	strcat(sql, "i.sucursal_rol, ");
	strcat(sql, "i.nro_inspeccion, ");
	strcat(sql, "c.fecha_desde_periodo, ");
	strcat(sql, "c.fecha_hasta_periodo, ");
	strcat(sql, "c.monto_facturado ");
	strcat(sql, "FROM cnr_new c, tabla t1, OUTER anomalias_cnr ac, OUTER inspecc:in_inspeccion i ");

if(giTipoCorrida==1){	
   strcat(sql, ", migra_sf ma ");
}

	strcat(sql, "WHERE c.fecha_inicio BETWEEN ? AND ? ");
   strcat(sql, "AND c.cod_estado != '99' ");
	strcat(sql, "AND t1.nomtabla = 'CNRRE' ");
	strcat(sql, "AND t1.sucursal = '0000' ");
	strcat(sql, "AND t1.codigo = c.cod_estado ");
	strcat(sql, "AND t1.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t1.fecha_desactivac IS NULL OR t1.fecha_desactivac >TODAY) ");
	strcat(sql, "AND ac.codigo2 = c.cod_anomalia ");
	strcat(sql, "AND i.nro_solicitud = c.in_solicitud_ap ");

if(giTipoCorrida==1){
   strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");
}
   
   strcat(sql , "UNION " );
	
	strcpy(sql, "SELECT c.sucursal, ");
	strcat(sql, "c.nro_expediente, ");
	strcat(sql, "c.ano_expediente, ");
	strcat(sql, "TO_CHAR(c.fecha_deteccion, '%Y-%m-%dT%H:%M:%S.000Z'), ");
	strcat(sql, "TO_CHAR(c.fecha_inicio, '%Y-%m-%dT%H:%M:%S.000Z'), "); 
	strcat(sql, "TO_CHAR(c.fecha_finalizacion, '%Y-%m-%dT%H:%M:%S.000Z'), "); 
	strcat(sql, "TO_CHAR(c.fecha_estado, '%Y-%m-%dT%H:%M:%S.000Z'), "); 
	strcat(sql, "c.numero_cliente, ");
	strcat(sql, "c.nro_solicitud, ");
	strcat(sql, "c.cod_estado, ");
	strcat(sql, "t1.descripcion, ");
	strcat(sql, "ac.categoria, ");
	strcat(sql, "TRIM(c.cod_anomalia) || '-' || TRIM(ac.descripcion1), ");
	strcat(sql, "i.sucursal_rol, ");
	strcat(sql, "i.nro_inspeccion, ");
	strcat(sql, "c.fecha_desde_periodo, ");
	strcat(sql, "c.fecha_hasta_periodo, ");
	strcat(sql, "c.monto_facturado ");
	strcat(sql, "FROM cnr_new c, tabla t1, OUTER anomalias_cnr ac, OUTER inspecc:in_inspeccion i ");

if(giTipoCorrida==1){	
   strcat(sql, ", migra_sf ma ");
}

	strcat(sql, "WHERE date(c.fecha_estado) BETWEEN ? AND ? ");
	strcat(sql, "AND t1.nomtabla = 'CNRRE' ");
	strcat(sql, "AND t1.sucursal = '0000' ");
	strcat(sql, "AND t1.codigo = c.cod_estado ");
	strcat(sql, "AND t1.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t1.fecha_desactivac IS NULL OR t1.fecha_desactivac >TODAY) ");
	strcat(sql, "AND ac.codigo2 = c.cod_anomalia ");
	strcat(sql, "AND i.nro_solicitud = c.in_solicitud_ap ");

if(giTipoCorrida==1){
   strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");
}

	$PREPARE selCnr FROM $sql;
	
	$DECLARE curCNR CURSOR WITH HOLD FOR selCnr;
	
   /************ Sel Medidor ************/
	strcpy(sql, "SELECT marca_medidor, ");
	strcat(sql, "modelo_medidor, ");
	strcat(sql, "numero_medidor ");
	strcat(sql, "FROM medid ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND estado = 'I' ");
   
   $PREPARE selMedidor FROM $sql;
   
   /************ Sel Solicitud ************/
	strcpy(sql, "SELECT numero_cliente FROM solicitud ");
	strcat(sql, "WHERE nro_solicitud = ? ");
   
   $PREPARE selSolicitud FROM $sql;
   
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


short LeoCnr(reg)
$ClsCnr *reg;
{
$long lCorrRefactu;
$int  iCantidad;


	InicializaCnr(reg);

	$FETCH curCnr INTO
      :reg->sucursal,
      :reg->nro_expediente,
      :reg->ano_expediente,
      :reg->fecha_deteccion,
      :reg->fecha_inicio, 
      :reg->fecha_finalizacion, 
      :reg->fecha_estado,
      :reg->numero_cliente,
      :reg->nro_solicitud,
      :reg->cod_estado,
      :reg->descripcion,
      :reg->tipo_expediente,
      :reg->anomalia,
      :reg->sucur_inspeccion,
      :reg->nro_inspeccion,
      :reg->sFechaDesdePeriCalcu,
      :reg->sFechaHastaPeriCalcu,
      :reg->total_calculo;
   	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de CNR !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			
   
   
   /* datos del medidor */
   
   if(reg->numero_cliente > 0){
      $EXECUTE selMedidor INTO :reg->marca_medidor,
                               :reg->modelo_medidor,
                               :reg->numero_medidor
                          USING :reg->numero_cliente;
                          
      if ( SQLCODE != 0 ){
         if(SQLCODE != 100){
            printf("Error leyendo medid para cliente %ld\n", reg->numero_cliente);
         }
      }         
      
   }else{
      if(reg->nro_solicitud > 0){
         $EXECUTE selSolicitud INTO :reg->numero_cliente
                              USING :reg->nro_solicitud;
                              
         if(SQLCODE == 0){
            if(reg->numero_cliente > 0){
               $EXECUTE selMedidor INTO :reg->marca_medidor,
                                        :reg->modelo_medidor,
                                        :reg->numero_medidor
                                   USING :reg->numero_cliente;
                                   
               if ( SQLCODE != 0 ){
                  if(SQLCODE != 100){
                     printf("Error leyendo medid para cliente %ld\n", reg->numero_cliente);
                  }
               }         
            }
         }                              
      }
   
   }
   
   alltrim(reg->descripcion, ' ');
   alltrim(reg->anomalia, ' ');
   
	return 1;	
}

void InicializaCnr(reg)
$ClsCnr	*reg;
{
	
   memset(reg->sucursal, '\0', sizeof(reg->sucursal));
   rsetnull(CLONGTYPE, (char *) &(reg->nro_expediente));
   rsetnull(CINTTYPE, (char *) &(reg->ano_expediente));
   memset(reg->fecha_deteccion, '\0', sizeof(reg->fecha_deteccion));
   memset(reg->fecha_inicio, '\0', sizeof(reg->fecha_inicio)); 
   memset(reg->fecha_finalizacion, '\0', sizeof(reg->fecha_finalizacion)); 
   memset(reg->fecha_estado, '\0', sizeof(reg->fecha_estado)); 
   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CLONGTYPE, (char *) &(reg->nro_solicitud));
   memset(reg->cod_estado, '\0', sizeof(reg->cod_estado));
   memset(reg->descripcion, '\0', sizeof(reg->descripcion));
   
   memset(reg->sFechaDesdePeriCalcu, '\0', sizeof(reg->sFechaDesdePeriCalcu));
   memset(reg->sFechaHastaPeriCalcu, '\0', sizeof(reg->sFechaHastaPeriCalcu));
   rsetnull(CDOUBLETYPE, (char *) &(reg->total_calculo));
   rsetnull(CLONGTYPE, (char *) &(reg->numero_medidor));
   memset(reg->marca_medidor, '\0', sizeof(reg->marca_medidor));
   memset(reg->modelo_medidor, '\0', sizeof(reg->modelo_medidor));
   memset(reg->tipo_expediente, '\0', sizeof(reg->tipo_expediente));

   memset(reg->anomalia, '\0', sizeof(reg->anomalia));
   memset(reg->sucur_inspeccion, '\0', sizeof(reg->sucur_inspeccion));
   rsetnull(CLONGTYPE, (char *) &(reg->nro_inspeccion));
   
}



short GenerarPlano(fp, reg)
FILE 				*fp;
$ClsCnr		reg;
{
	char	sLinea[1000];
   int   iRcv;	

	memset(sLinea, '\0', sizeof(sLinea));

   /* Suministro */
   sprintf(sLinea, "%s\"%ldAR\";", sLinea, reg.numero_cliente);
   
   /* Nro. Expediente */
   sprintf(sLinea, "%s\"%ld\";", sLinea, reg.nro_expediente);
   
   /* Fecha creación expediente */
   /*sprintf(sLinea, "%s\"%s\";", sLinea, reg.fecha_inicio);*/
   sprintf(sLinea, "%s\"%s\";", sLinea, reg.fecha_deteccion);
   
   /* Condicion del expediente */
   alltrim(reg.tipo_expediente, ' ');
	if(strcmp(reg.tipo_expediente, "AV")==0){
		strcat(sLinea, "\"Anomalia Visible\";");
	}else if(strcmp(reg.tipo_expediente, "ANV")==0){
		strcat(sLinea, "\"Anomalia No Visible\";");
	}else{
		strcat(sLinea, "\"Anomalia Tecnica\";");
	}
   
   /* Año del expediente */
   sprintf(sLinea, "%s\"%ld\";", sLinea, reg.ano_expediente);
   
   /* Fecha Inicio */
   sprintf(sLinea, "%s\"%s\";", sLinea, reg.fecha_inicio);
   
   /* Fecha Fin */
   if(strcmp(reg.fecha_finalizacion, "")!=0){
      sprintf(sLinea, "%s\"%s\";", sLinea, reg.fecha_finalizacion);
   }else{
      strcat(sLinea, "\"\";");
   }
   
   /* Fecha inicio energía */
   if(strcmp(reg.sFechaDesdePeriCalcu, "")!=0){
      sprintf(sLinea, "%s\"%s\";", sLinea, reg.sFechaDesdePeriCalcu);
   }else{
      strcat(sLinea, "\"\";");
   }
   
   /* Fecha fin energía */
   if(strcmp(reg.sFechaHastaPeriCalcu, "")!=0){
      sprintf(sLinea, "%s\"%s\";", sLinea, reg.sFechaHastaPeriCalcu);
   }else{
      strcat(sLinea, "\"\";");
   }
   
   /* Estado */
   sprintf(sLinea, "%s\"%s\";", sLinea, reg.cod_estado);
   
   /* Monto Expediente */
   if(!risnull(CDOUBLETYPE, (char *) &reg.total_calculo) && reg.total_calculo > 0){
      sprintf(sLinea, "%s\"%.02lf\";", sLinea, reg.total_calculo);
   }else{
      strcat(sLinea, "\"\";");
   }
   
   /* Cantidad de cuotas */
   strcat(sLinea, "\"\";");
   
   /* Número de medidor */
   sprintf(sLinea, "%s\"%ld%09ld%s%sDEVARG\";", sLinea, reg.numero_cliente, reg.numero_medidor, reg.marca_medidor, reg.modelo_medidor);
   
   /* External Id */
   sprintf(sLinea, "%s\"%d%s%ldMDARG\";", sLinea, reg.ano_expediente, reg.sucursal, reg.nro_expediente);


	/* Tipo Anomalia */
	sprintf(sLinea, "%s\"%s\";", sLinea, reg.anomalia);
	
	/* Nro.de Acta */
	sprintf(sLinea, "%s\"%s-%ld\";", sLinea, reg.sucur_inspeccion, reg.nro_inspeccion);

	strcat(sLinea, "\n");
		
	iRcv=fprintf(fp, sLinea);
   if(iRcv<0){
      printf("Error al grabar en archivo MarketDicipline.\n");
      exit(1);
   }
	
	return 1;
}


/*****************************
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


