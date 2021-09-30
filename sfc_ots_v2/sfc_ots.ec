/*********************************************************************************
    Proyecto: Migracion al sistema SALES-FORCES
    Aplicacion: sfc_ots
    
	Fecha : 09/07/2021

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Delta de OTs no generados por peticion de SFCD
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		<Fecha Desde>: dd/mm/aaaa
		<Fecha Hasta>: dd/mm/aaaa
		
********************************************************************************/
#include <locale.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sfc_ots.h";

/* Variables Globales */
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
$ClsOT	regOT;
$long       glFechaDesde;
$long       glFechaHasta;
$char		gsFechaDesdeDT[20];
$char		gsFechaHastaDT[20];

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
printf("Cargando Temporal\n");   
	/****** Cargo Temporal ********/
	$EXECUTE insOts USING :glFechaDesde, :glFechaHasta, :glFechaDesde, :glFechaHasta,:glFechaDesde, :glFechaHasta, :glFechaDesde, :glFechaHasta;
	
	if( SQLCODE != 0){
		printf("Fallo Carga de Temporal\n");
   		exit(1);
	}
printf("Temporal Cargada\n");	
	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
	CreaPrepare2();

   $OPEN curOTS;

   	while(LeoOTS(&regOT)){

   		if (!GenerarPlano(fp, regOT)){

            printf("Fallo GenearPlano\n");
   			exit(1);	
   		}
   		cantProcesada++;
   	}


   	$CLOSE curOTS;
      
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
	printf("OTS\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Eventos Procesados :       %ld \n",cantProcesada);
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
   
   memset(gsFechaDesdeDT, '\0', sizeof(gsFechaDesdeDT));
   memset(gsFechaHastaDT, '\0', sizeof(gsFechaHastaDT));

   
	if(argc != 4){
		MensajeParametros();
		return 0;
	}

  strcpy(sFechaDesde, argv[2]); 
  strcpy(sFechaHasta, argv[3]);
  rdefmtdate(&glFechaDesde, "dd/mm/yyyy", sFechaDesde); 
  rdefmtdate(&glFechaHasta, "dd/mm/yyyy", sFechaHasta);
  
  sprintf(gsFechaDesdeDT, "%c%c%c%c-%c%c-%c%c 00:00:00", sFechaDesde[6], sFechaDesde[7],sFechaDesde[8],sFechaDesde[9],
			  sFechaDesde[3],sFechaDesde[4], sFechaDesde[0],sFechaDesde[1]); 
  
  sprintf(gsFechaHastaDT, "%c%c%c%c-%c%c-%c%c 23:59:59", sFechaHasta[6], sFechaHasta[7],sFechaHasta[8],sFechaHasta[9],
			  sFechaHasta[3],sFechaHasta[4], sFechaHasta[0],sFechaHasta[1]);

  sprintf(gsDesdeFmt, "%c%c%c%c%c%c%c%c", sFechaDesde[6], sFechaDesde[7],sFechaDesde[8],sFechaDesde[9],
			  sFechaDesde[3],sFechaDesde[4], sFechaDesde[0],sFechaDesde[1]);      

  sprintf(gsHastaFmt, "%c%c%c%c%c%c%c%c", sFechaHasta[6], sFechaHasta[7],sFechaHasta[8],sFechaHasta[9],
			  sFechaHasta[3],sFechaHasta[4], sFechaHasta[0],sFechaHasta[1]);      
       
 
	
	return 1;
}

void MensajeParametros(void){
	printf("Error en Parametros.\n");
	printf("	<Base> = synergia.\n");
    printf("	<Fecha Desde> = dd/mm/aaaa.\n");
    printf("	<Fecha Hasta> = dd/mm/aaaa.\n");
      
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

	sprintf( sArchivoUnx  , "%sT1_OTS.unx", sPathSalida );
   sprintf( sArchivoAux  , "%sT1_OTS.aux", sPathSalida );
   sprintf( sArchivoDos  , "%senel_care_workorder_%s_%s.csv", sPathSalida, gsDesdeFmt, gsHastaFmt);

	strcpy( sSoloArchivo, "T1_OTS.unx");

	pFileUnx=fopen( sArchivoUnx, "w" );
	if( !pFileUnx ){
		printf("ERROR al abrir archivo %s.\n", sArchivoUnx );
		return 0;
	}
	
   strcpy(sTitulos, "\"Point Of Delivery\";");
   strcat(sTitulos, "\"Cuenta\";");
   strcat(sTitulos, "\"External ID\";");
   strcat(sTitulos, "\"Order Number\";");
   strcat(sTitulos, "\"Rol\";");
   strcat(sTitulos, "\"Asunto\";");
   strcat(sTitulos, "\"Descripcion\";");
   strcat(sTitulos, "\"Estado\";");
   strcat(sTitulos, "\"Fecha Estado\";");
   strcat(sTitulos, "\"Codigo ISO\";");
   strcat(sTitulos, "\n");
   
   iRcv=fprintf(pFileUnx, sTitulos);
   if(iRcv<0){
      printf("Error al grabar OTs\n");
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

	/******* Prepara Temporal ******/
	$PREPARE insOts FROM "SELECT s.rowid indice, 
		o.mensaje_xnear,
		o.numero_orden, 
		s.osm_nro_orden,
		o.tipo_orden,
		o.tema, 
		o.trabajo,
		s.osm_status, 
		s.osm_desc_status,
		m.ot_motivo,
		o.fecha_inicio,
		s.osm_fecha_status, 
		s.osm_hora_status,
		o.numero_cliente,
		TO_CHAR(s.osm_fecha_status, '%Y-%m-%dT') || TO_CHAR(s.osm_hora_status, '%H:%M:%S.000Z') fecha_sts_fmt,
		LPAD(to_number(s.osm_nro_orden[3,12]), 8, '0') external_id
		FROM ot_sap_mac s, ot_mac m, orden o
		WHERE s.osm_fecha_status BETWEEN ? AND ?
		AND m.ot_nro_orden = s.osm_nro_orden[5,12]
		AND o.mensaje_xnear = m.ot_mensaje_xnear
		AND o.term_dir != 'SALESFORCE'
		UNION
		SELECT s.rowid indice, 
		o.mensaje_xnear, 
		o.numero_orden,
		s.osm_nro_orden,
		o.tipo_orden,
		o.tema, 
		o.trabajo,
		s.osm_status, 
		s.osm_desc_status,
		m.cod_motivo,
		o.fecha_inicio,
		s.osm_fecha_status, 
		s.osm_hora_status,
		o.numero_cliente,
		TO_CHAR(s.osm_fecha_status, '%Y-%m-%dT') || TO_CHAR(s.osm_hora_status, '%H:%M:%S.000Z') fecha_sts_fmt,
		LPAD(to_number(s.osm_nro_orden[3,12]), 8, '0') external_id
		FROM ot_sap_mac s, ot_final m, orden o
		WHERE s.osm_fecha_status BETWEEN ? AND ?
		AND m.otf_nro_orden = s.osm_nro_orden[5,12]
		AND o.mensaje_xnear = m.mensaje_xnear
		AND o.term_dir != 'SALESFORCE'
		UNION
		SELECT s.rowid indice,
		0 mensaje_xear,
		to_char(g.ot_nro_orden) numero_orden,
		s.osm_nro_orden, 
		'GIS' tipo_orden,
		g.ot_anomalia tema, 
		g.ot_tipo_traba trabajo, 
		s.osm_status, 
		s.osm_desc_status, 
		/*m.ot_motivo, */
		g.ot_motivo,
		g.ot_fecha_creacion fecha_inicio, 
		s.osm_fecha_status, 
		s.osm_hora_status,
		g.ot_numero_cliente numero_cliente,
		TO_CHAR(s.osm_fecha_status, '%Y-%m-%dT') || TO_CHAR(s.osm_hora_status, '%H:%M:%S.000Z') fecha_sts_fmt,
		LPAD(to_number(s.osm_nro_orden[3,12]), 8, '0') external_id
		FROM ot_sap_mac s, ot_mac m, ot_gise g
		WHERE s.osm_fecha_status BETWEEN ? AND ?
		AND m.ot_nro_orden = s.osm_nro_orden[5,12]
		AND m.ot_gise = 'S'
		AND g.ot_nro_orden = m.ot_nro_orden
		UNION
		SELECT s.rowid indice,
		0 mensaje_xnear,
		to_char(g.ot_nro_orden) numero_orden,
		s.osm_nro_orden, 
		'GIS' tipo_orden,
		g.ot_anomalia tema, 
		g.ot_tipo_traba trabajo, 
		s.osm_status, 
		s.osm_desc_status, 
		/*m.cod_motivo, */
		g.ot_motivo,
		g.ot_fecha_creacion fecha_inicio, 
		s.osm_fecha_status, 
		s.osm_hora_status,
		g.ot_numero_cliente numero_cliente,
		TO_CHAR(s.osm_fecha_status, '%Y-%m-%dT') || TO_CHAR(s.osm_hora_status, '%H:%M:%S.000Z') fecha_sts_fmt,
		LPAD(to_number(s.osm_nro_orden[3,12]), 8, '0') external_id
		FROM ot_sap_mac s, ot_final m, ot_gise g
		WHERE s.osm_fecha_status BETWEEN ? AND ?
		AND m.otf_nro_orden = s.osm_nro_orden[5,12]
		AND m.otf_gise = 'S'
		AND g.ot_nro_orden = m.otf_nro_orden
		INTO TEMP tempo1 WITH NO LOG ";
		

   /******** Cursor de OTs ****************/
/*   
	$PREPARE selOTS FROM "SELECT DISTINCT om.ot_mensaje_xnear,
	om.ot_nro_orden,
	o.numero_orden,
	o.tipo_orden,
	o.tema,
	o.trabajo,
	o.ident_etapa etapa,
	h1.ots_status,
	h1.ots_fecha_proc,
	om.ot_motivo,
	m.estado,
	s.osm_status,
	ot_numero_cliente,
	s.osm_nro_orden,
	TO_CHAR(h1.ots_fecha_proc, '%Y-%m-%dT%H:%M:%S.000Z')
	FROM ot_mac om, ot_hiseven h1, xnear2:mensaje m, OUTER orden o, outer ot_sap_mac s
	WHERE om.ot_fecha_est BETWEEN ? AND ?
	AND h1.ots_nro_orden = om.ot_nro_orden
	AND h1.ots_fecha_proc between ? and ?
	AND m.mensaje = om.ot_mensaje_xnear
	AND m.rol_creacion not in (SELECT DISTINCT trim(sr.rol) FROM sfc_roles sr)
	AND o.mensaje_xnear = om.ot_mensaje_xnear
	AND s.osm_nro_orden[5,12] = om.ot_nro_orden
	AND s.osm_tipo_ifaz = 'N001'
	UNION
	SELECT DISTINCT otf.mensaje_xnear,
	otf.otf_nro_orden,
	o.numero_orden,
	o.tipo_orden,
	o.tema,
	o.trabajo,
	NVL(o.ident_etapa,'FI') etapa,
	h1.ots_status,
	h1.ots_fecha_proc,
	otf.cod_motivo,
	m.estado,
	s.osm_status,
	otf.numero_cliente,
	s.osm_nro_orden,
	TO_CHAR(h1.ots_fecha_proc, '%Y-%m-%dT%H:%M:%S.000Z')
	FROM ot_final otf, ot_hiseven h1, xnear2:mensaje m, OUTER orden o, outer ot_sap_mac s
	WHERE fecha_ot_final BETWEEN ? AND ?
	AND h1.ots_nro_orden = otf.otf_nro_orden
	AND h1.ots_fecha_proc BETWEEN ? AND ?
	AND m.mensaje = otf.mensaje_xnear
	and m.rol_creacion not in (SELECT DISTINCT trim(sr.rol) FROM sfc_roles sr)
	AND o.mensaje_xnear = otf.mensaje_xnear
	AND s.osm_nro_orden[5,12] = otf.otf_nro_orden
	AND s.osm_tipo_ifaz = 'N001'
	ORDER BY 1, 9 ";
	
	$DECLARE curOTS CURSOR WITH HOLD FOR selOTS;

*/	
/*
select * from tempo1
order by mensaje_xnear

select t1.* from tempo1 t1
where t1.indice = (select max(t2.indice) from tempo1 t2
        where t2.osm_nro_orden =t1.osm_nro_orden)
order by mensaje_xnear        
 
*/	

	/******** Select Path de Archivos ****************/
	strcpy(sql, "SELECT valor_alf ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'PATH' ");
	strcat(sql, "AND codigo = ? ");
	strcat(sql, "AND sucursal = '0000' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND ( fecha_desactivac >= TODAY OR fecha_desactivac IS NULL ) ");

	$PREPARE selRutaPlanos FROM $sql;

	/******** Descripcion de Motivos ****************/
	$PREPARE selMotivoOt FROM "SELECT TRIM(descripcion) FROM tabla
		WHERE nomtabla = ?
		AND sucursal = '0000'
		AND codigo = ?
		AND fecha_activacion <= TODAY
		AND (fecha_desactivac > TODAY OR fecha_desactivac IS NULL) ";

	/****** Texton Segen ********/
	$PREPARE selTexton FROM "SELECT pagina, texton FROM xnear2:pagina
		WHERE mensaje = ?
		AND servidor = 1
		ORDER BY pagina ";
			
	$DECLARE curTexton CURSOR FOR selTexton;
}

void CreaPrepare2(void){
$char sql[10000];
$char sAux[1000];

	memset(sql, '\0', sizeof(sql));
	memset(sAux, '\0', sizeof(sAux));

	/******** cursor de OTs *******/
	$PREPARE selOTS FROM "SELECT t1.mensaje_xnear, 
		t1.osm_nro_orden, 
		t1.tipo_orden,
		t1.tema, 
		t1.trabajo,
		t1.osm_status, 
		t1.osm_desc_status,
		t1.ot_motivo,
		t1.fecha_inicio,
		t1.osm_fecha_status, 
		t1.osm_hora_status,
		t1.numero_cliente,
		t1.fecha_sts_fmt,
		t1.external_id
		FROM tempo1 t1
		WHERE t1.indice = (select max(t2.indice) from tempo1 t2
			where t2.osm_nro_orden =t1.osm_nro_orden)		
		ORDER BY 1 ";
		
	$DECLARE curOTS CURSOR WITH HOLD FOR selOTS;

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



short LeoOTS(reg)
$ClsOT *reg;
{
	$ClsTexton regTex;
	$char sTipoOt[7];

	InicializaOT(reg);

	$FETCH curOTS INTO
		:reg->nro_mensaje,
		:reg->sap_nro_ot,
		:reg->tipo_orden,
		:reg->tema,
		:reg->trabajo,
		:reg->sap_status,
		:reg->desc_status,
		:reg->ot_cod_motivo,
		:reg->fecha_inicio,
		:reg->fecha_status,
		:reg->hora_status,
		:reg->numero_cliente,
		:reg->fecha_evento_fmt,
		:reg->external_id;
	
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de OTs !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			
	alltrim(reg->sap_nro_ot, ' ');
	alltrim(reg->tipo_orden, ' ');
	alltrim(reg->tema, ' ');
	alltrim(reg->trabajo, ' ');
	alltrim(reg->sap_status, ' ');
	alltrim(reg->desc_status, ' ');
	alltrim(reg->ot_cod_motivo, ' ');
	alltrim(reg->fecha_inicio, ' ');
	alltrim(reg->hora_status, ' ');
	alltrim(reg->fecha_evento_fmt, ' ');
   
   memset(sTipoOt, '\0', sizeof(sTipoOt));
   
   if(strcmp(reg->tipo_orden, "GIS")!=0){
	   if(strcmp(reg->tipo_orden , "OT")==0 || strcmp(reg->tipo_orden , "OC")==0){ 
			strcpy(sTipoOt, "OTMOSO");
	   }else if(strcmp(reg->tipo_orden, "MAN")==0){
			strcpy(sTipoOt, "OTMOMA");
	   }else if(strcmp(reg->tipo_orden, "RET")==0){
			strcpy(sTipoOt, "OTMORE");
	   }

	   $EXECUTE selMotivoOt INTO :reg->descri_motivo USING :sTipoOt, :reg->ot_cod_motivo;

		if(SQLCODE != 0){
			if(SQLCODE == 100){
				strcpy(sTipoOt, "TRABAJ");
				
				$EXECUTE selMotivoOt INTO :reg->descri_motivo USING :sTipoOt, :reg->trabajo;
			}else{
				printf("Mensaje %ld OT %s motivo %s. Error al buscar motivo\n", reg->nro_mensaje, reg->sap_nro_ot, reg->ot_cod_motivo);
			}
		}
   }else{
	   sprintf(reg->descri_motivo, "Motivo GISE %s", reg->ot_cod_motivo);
   }
   
   alltrim(reg->descri_motivo, ' ');

    if( reg->nro_mensaje > 0){     
		$OPEN curTexton USING :reg->nro_mensaje;

		while(LeoTexton(&regTex)){

			if(regTex.iPag==1){
				strcpy(reg->sTexton, regTex.sTexto);
			}else{
				sprintf(reg->sTexton, "%s%s", reg->sTexton, regTex.sTexto);
			}
		}

		$CLOSE curTexton;
	}
	
	return 1;	
}

void InicializaOT(reg)
$ClsOT	*reg;
{

	rsetnull(CLONGTYPE, (char *) &(reg->nro_mensaje));
	memset(reg->nro_orden, '\0', sizeof(reg->nro_orden));
	memset(reg->sap_nro_ot, '\0', sizeof(reg->sap_nro_ot));
	memset(reg->tipo_orden, '\0', sizeof(reg->tipo_orden));
	memset(reg->tema, '\0', sizeof(reg->tema));
	memset(reg->trabajo, '\0', sizeof(reg->trabajo));
	memset(reg->sap_status, '\0', sizeof(reg->sap_status));
	memset(reg->desc_status, '\0', sizeof(reg->desc_status));
	memset(reg->ot_cod_motivo, '\0', sizeof(reg->ot_cod_motivo));
	memset(reg->fecha_inicio, '\0', sizeof(reg->fecha_inicio));
	rsetnull(CLONGTYPE, (char *) &(reg->fecha_status));
	memset(reg->ot_cod_motivo, '\0', sizeof(reg->hora_status));
	rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
	memset(reg->fecha_evento_fmt, '\0', sizeof(reg->fecha_evento_fmt));
	memset(reg->external_id, '\0', sizeof(reg->external_id));

	memset(reg->descri_motivo, '\0', sizeof(reg->descri_motivo));
	memset(reg->sTexton, '\0', sizeof(reg->sTexton));

}

short LeoTexton(reg)
$ClsTexton *reg;
{
	$char sTexto[102];
	memset(sTexto, '\0', sizeof(sTexto));
	
	InicializaTexton(reg);
	
	$FETCH curTexton INTO :reg->iPag, :sTexto;
	
	if (SQLCODE != 0 ){
		return 0;
	}

	strcpy(sTexto, strReplace(sTexto, "þ", " "));
	strcpy(sTexto, strReplace(sTexto, "\"", "´"));
	strcpy(sTexto, strReplace(sTexto, ",", " "));
	strcpy(sTexto, strReplace(sTexto, "\r", " "));
	strcpy(sTexto, strReplace(sTexto, "\n", " "));

	strcpy(sTexto, strReplace2(sTexto, 13, 32));
	strcpy(sTexto, strReplace2(sTexto, 254, 32));
	
	alltrim(sTexto, ' ');
	
	strcpy(reg->sTexto, sTexto);
	
	return 1;
}

void InicializaTexton(reg)
$ClsTexton *reg;
{
	rsetnull(CINTTYPE, (char *) &(reg->iPag));
	memset(reg->sTexto, '\0', sizeof(reg->sTexto));
}


short GenerarPlano(fp, reg)
FILE 		*fp;
$ClsOT		reg;
{
	char	sLinea[15000];	
	int   	iRcv;
	long 	lNroOrden;

   
	memset(sLinea, '\0', sizeof(sLinea));

   /* Point Of Delivery */
   sprintf(sLinea, "\"%ldAR\";", reg.numero_cliente);
   
   /* Cuenta */
   sprintf(sLinea, "%s\"%ldARG\";",sLinea, reg.numero_cliente);   
   
   /* External ID */
   /*sprintf(sLinea, "%s\"%08ldWOARG\";", sLinea, reg.nro_mensaje);*/
   sprintf(sLinea, "%s\"%sWOARG\";", sLinea, reg.external_id);
   
   /* Order Number */
   /*sprintf(sLinea, "%s\"%08ld\";", sLinea, reg.nro_mensaje);*/
   sprintf(sLinea, "%s\"%s\";", sLinea, reg.sap_nro_ot);
   
   /* Rol */
   strcat(sLinea, "\"\";");
   
   /* Asunto */
   sprintf(sLinea, "%s\"%s\";", sLinea, reg.descri_motivo);

   /* Descripcion */
   if(strcmp(reg.sTexton, "")!=0){
		sprintf(sLinea, "%s\"%s\";", sLinea, reg.sTexton);
   }else{
		strcat(sLinea, "\"\";");
   }

   /* Estado */
/*   
   if(strcmp(reg.sap_status, "")!=0){
		sprintf(sLinea, "%s\"%s\";", sLinea, reg.sap_status);
   }else{
		sprintf(sLinea, "%s\"%s\";", sLinea, reg.histo_status);
   }
*/
	sprintf(sLinea, "%s\"%s\";", sLinea, reg.desc_status);

   /* Fecha Estado */
   sprintf(sLinea, "%s\"%s\";", sLinea, reg.fecha_evento_fmt);

   /* Codigo ISO */
   strcat(sLinea, "\"ARS\";");


	strcat(sLinea, "\n");

printf("segen [%ld] \n", reg.nro_mensaje);	
fflush(stdin);	

	iRcv=fprintf(fp, sLinea);

   if(iRcv<0){
      printf("Error al grabar OTs\n");
      exit(1);
   }
   
   fflush(fp);	
	
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
char sCadena[1000];
char cFind[2];
char cRemp[2];
{

    char *p = sCadena;
    
    while (*p != '\0') {
        if (*p == cFind[0])
            *p = cRemp[0];
        p++;
    }
    
    strcat(sCadena, "\0");
    
    return sCadena;
}

static char *strReplace2(sCadena, cFind, cRemp)
char sCadena[1000];
int cFind;
int cRemp;
{
    char *p = sCadena;
    
    while (*p != '\0') {
        if (*p == cFind)
            *p = cRemp;
        p++;
    }
    
   return sCadena;
}

