/**********************************************************************************
    Proyecto: Migracion al sistema SALES FORCE
    Aplicacion: sfc_emergencias
    
	Fecha : 10/03/2017

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Extractor que genera el archivo plano para las estructuras de Emergencias
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		<Estado Cliente> : 0=Activos; 1= No Activos; 2= Todos;		
		<Tipo Generacion>: G = Generacion; R = Regeneracion
		
		<Nro.Cliente>: Opcional

*********************************************************************************/
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <synmail.h>

$include "sfc_actuclie.h";

/* Variables Globales */
$long glFechaDesde;
$long glFechaHasta;
$char gsFechaDesdeLarga[17];
$char gsFechaHastaLarga[17];
$char gsFechaFile[9];

$long	glNroCliente;
$int	giEstadoCliente;
int	giTipoGenera;

FILE  *fpLog;
FILE  *fpBajasUnx;

char	sArchBajasUnx[100];
char	sArchBajasAux[100];
char	sArchBajasDos[300];
char	sSoloArchivoBajasUnx[100];

char	sPathSalida[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantProcesada;

char	sMensMail[1024];	

char     gsDesdeFmt[9];
char     gsHastaFmt[9];

/* Variables Globales Host */
$long			lFechaLimiteInferior;

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
int		iFlagMigra=0;
char     sCommand[100];
int      iRcv;
$char    sFechaAyer[11];
$long    lNroCliente;
$long    lAltura;
int      iValidaEmail;
long     lCantInvalidos;
$ClsBaja regBaja;
/*
   strcpy(sCommand, "export LANG=es_ES.UTF-8");
   iRcv=system(sCommand);
*/   
   /*setlocale(LC_ALL, "es_ES.UTF-8");*/
   /*setlocale(LC_ALL, "en_US.ISO8859-1");*/

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}

   /*strcpy(sCommand, setlocale(LC_ALL, "es_ES.UTF8"));*/
	
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
   /*giTipoGenera = atoi(argv[2]);*/
   
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT;
	$SET ISOLATION TO DIRTY READ;
	
	CreaPrepareIni();

   /* Fecha Desde */
   memset(sFechaAyer, '\0', sizeof(sFechaAyer));
   
   $EXECUTE selFechaActual INTO :sFechaAyer;
   
   CargaPeriodoAnalisis(argc, argv, sFechaAyer);

	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
   
   if(! CargaContingente()){
      printf("Error al buscar eventos de actualización.\nSe aborta proceso.");
      exit(1);
   }
   
	if(!AbreArchivos()){
		exit(1);	
	}

   CreaPrepare();

	cantProcesada=0;


	/*********************************************
				AREA CURSOR PPAL
	**********************************************/
   /* REgistro de Bajas */   
/*  CHAU BAJAS   
   $OPEN curBajas;
   
   while(LeoBajas(&regBaja)){
      GeneraBaja(regBaja);
      
      cantProcesada++;
   }
   
   $CLOSE curBajas;
*/      

   /****** Procesa Contactos *****/
/*   
   $BEGIN WORK;
   
   CargoContactos();
      
   $COMMIT WORK;
*/   
      
   $BEGIN WORK;
   if(!RegistraCorrida(cantProcesada)){
      printf("No se pudo registrar la corrida.\n");
   }
   $COMMIT WORK;
   

	FormateaArchivos();
	
	$CLOSE DATABASE;

	$DISCONNECT CURRENT;

	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */

	printf("==============================================\n");
	printf("SALES FORCES - ACTUALIZACIONES CLIENTES\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
    printf("Fecha Desde:                %s \n", gsFechaDesdeLarga);
    printf("Fecha Hasta:                %s \n", gsFechaHastaLarga);
	printf("==============================================\n");
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));						

	hora = time(&hora);
	printf("\nHora de finalizacion del proceso : %s\n", ctime(&hora));

	printf("Fin del proceso OK\n");	

	exit(0);
}	

short AnalizarParametros(argc, argv)
int		argc;
char	* argv[];
{
   char sFechaDesde[11];
   char sFechaHasta[11];
   
   memset(gsDesdeFmt, '\0', sizeof(gsDesdeFmt));
   memset(gsHastaFmt, '\0', sizeof(gsHastaFmt));

   memset(sFechaDesde, '\0', sizeof(sFechaDesde));
   memset(sFechaHasta, '\0', sizeof(sFechaHasta));

	if(argc < 2 || argc > 4){
		MensajeParametros();
		return 0;
	}
   
   if(argc >= 3){
      /* valido fecha desde */
      if(! ValidaFecha(argv[2])){
         printf("Fecha Desde es Invalida.\nFormato correcto dd/mm/aaaa\n");
      }
   }
   
   if(argc == 4){
      /* valida fecha hasta */
      if(! ValidaFecha(argv[3])){
         printf("Fecha Hasta es Invalida.\nFormato correcto dd/mm/aaaa\n");
      }
   }

   strcpy(sFechaDesde, argv[2]);
   strcpy(sFechaHasta, argv[3]);
   
   sprintf(gsDesdeFmt, "%c%c%c%c%c%c%c%c", sFechaDesde[6], sFechaDesde[7],sFechaDesde[8],sFechaDesde[9],
               sFechaDesde[3],sFechaDesde[4], sFechaDesde[0],sFechaDesde[1]);      

   sprintf(gsHastaFmt, "%c%c%c%c%c%c%c%c", sFechaHasta[6], sFechaHasta[7],sFechaHasta[8],sFechaHasta[9],
               sFechaHasta[3],sFechaHasta[4], sFechaHasta[0],sFechaHasta[1]);      
	
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("\t<Base> = synergia.\n");
      printf("\t<Fecha Desde. Opcional> dd/mm/aaaa\n");
      printf("\t<Fecha Hasta. Opcional> dd/mm/aaaa\n");
}

short AbreArchivos()
{
   char  sTitulos[10000];
   char  sFechaFile[9];
   
   memset(sFechaFile, '\0', sizeof(sFechaFile));
   memset(sTitulos, '\0', sizeof(sTitulos));
   
	memset(sArchBajasUnx, '\0', sizeof(sArchBajasUnx));
   memset(sArchBajasAux, '\0', sizeof(sArchBajasAux));
   memset(sArchBajasDos, '\0', sizeof(sArchBajasDos));
	memset(sSoloArchivoBajasUnx, '\0', sizeof(sSoloArchivoBajasUnx));


	memset(sPathSalida,'\0',sizeof(sPathSalida));

   strcpy(sFechaFile, FechaGeneracionFormateada(sFechaFile));
	RutaArchivos( sPathSalida, "SALESF" );

   /*strcpy(sPathSalida, "/home/ldvalle/noti_rep/");*/

	alltrim(sPathSalida,' ');

   /* Armo nombres de archivo */
	strcpy(sSoloArchivoBajasUnx, "T1BAJAS.unx");
	sprintf(sArchBajasUnx, "%s%s", sPathSalida, sSoloArchivoBajasUnx);
   sprintf(sArchBajasAux, "%sT1BAJAS.aux", sPathSalida);
   sprintf(sArchBajasDos, "%sEnel_care_moveout_%s.csv", sPathSalida, sFechaFile);	
	
   /* Abro Archivos*/
	fpBajasUnx=fopen( sArchBajasDos, "w" );
	if( !fpBajasUnx ){
		printf("ERROR al abrir archivo de Bajas %s.\n", sArchBajasDos );
		return 0;
	}

/*   
	fpBajasUnx=fopen( sArchBajasUnx, "w" );
	if( !fpBajasUnx ){
		printf("ERROR al abrir archivo de Bajas %s.\n", sArchBajasUnx );
		return 0;
	}
*/

   strcpy(sTitulos, "\"External ID Suministro\";");
   strcat(sTitulos, "\"Estado del suministro\";");
   strcat(sTitulos, "\"Estado del cliente\";");
   strcat(sTitulos, "\"Fecha de baja\";");
   strcat(sTitulos, "\"External ID del activo\";");
   strcat(sTitulos, "\"Estado del Activo\";");
   strcat(sTitulos, "\"Estado del Activo (Contratacion)\";");
   strcat(sTitulos, "\"External ID del Contrato\";");
   strcat(sTitulos, "\"Estado del contrato\";");
   strcat(sTitulos, "\"Fecha de baja del contrato\";");
   strcat(sTitulos, "\"External ID de la linea de contrato\";");
   strcat(sTitulos, "\"Estado de linea de contrato (contratacion)\";");
   strcat(sTitulos, "\"Estado de la linea de contrato\";\r\n");

   fprintf(fpBajasUnx, sTitulos);

	return 1;	
}

void CerrarArchivos(void)
{
   fclose(fpBajasUnx);
}

void FormateaArchivos(void){
char	sCommand[1000];
int		iRcv, i;
$char	sPathCp[100];
$char sClave[7];
	
	memset(sCommand, '\0', sizeof(sCommand));
	memset(sPathCp, '\0', sizeof(sPathCp));
   strcpy(sClave, "SALEFC");

	
	$EXECUTE selRutaFinal INTO :sPathCp using :sClave;

    if ( SQLCODE != 0 ){
        printf("ERROR.\nSe produjo un error al tratar de recuperar el path destino del archivo.\n");
        exit(1);
    }
   /*strcpy(sPathCp, "/home/ldvalle/noti_in/");*/
	/* ----------- */
/*   
   sprintf(sCommand, "unix2dos %s > %s", sArchBajasUnx, sArchBajasAux);
	iRcv=system(sCommand);

   sprintf(sCommand, "iconv -f WINDOWS-1252 -t UTF-8 %s > %s ", sArchBajasAux, sArchBajasDos);
   
   sprintf(sCommand, "iconv -f WINDOWS-1252 -t UTF-8 %s > %s ", sArchBajasUnx, sArchBajasDos);
   iRcv=system(sCommand);
*/   
	sprintf(sCommand, "chmod 777 %s", sArchBajasDos);
	iRcv=system(sCommand);

	sprintf(sCommand, "mv %s %s", sArchBajasDos, sPathCp);
	iRcv=system(sCommand);
   
/*
   if(iRcv == 0){

      sprintf(sCommand, "rm %s", sArchBajasUnx);
      iRcv=system(sCommand);
   
      sprintf(sCommand, "rm %s", sArchBajasAux);
      iRcv=system(sCommand);
   
      sprintf(sCommand, "rm %s", sArchBajasDos);
      iRcv=system(sCommand);
   }
*/   
}

void CreaPrepareIni(void){
$char sql[10000];
$char sAux[1000];

	memset(sql, '\0', sizeof(sql));
	memset(sAux, '\0', sizeof(sAux));

	/******** Fecha Actual Formateada ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY-1, '%Y%m%d') FROM dual ");
	
	$PREPARE selFechaActualFmt FROM $sql;

	/******** Fecha Actual  ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY - 1, '%d/%m/%Y') FROM dual ");
	
	$PREPARE selFechaActual FROM $sql;	

   /********** Limpiar contingente **********/
   strcpy(sql, "DELETE FROM sf_actuclie ");
   
   $PREPARE delActuClie FROM $sql;

   /******** Altas Puras********/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente, nomencla) ");   
   strcat(sql, "SELECT e.numero_cliente, 'S' ");
   strcat(sql, "FROM estoc e ");
   strcat(sql, "WHERE e.fecha_traspaso BETWEEN ? AND ? ");
   strcat(sql, "AND e.estado_traspaso = 'S' ");
   
   $PREPARE insAltas FROM $sql;
   
   /******** Bajas Puras ********/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente, baja, fecha_evento) "); 
   strcat(sql, "SELECT m.numero_cliente, 'S', m.fecha_modif ");   
   strcat(sql, "FROM modif m ");
   strcat(sql, "WHERE (m.tipo_orden in ('RET', 'SUM') AND m.codigo_modif in ('57', '58')) ");
   strcat(sql, "AND m.fecha_modif BETWEEN ? AND ? ");
   strcat(sql, "AND TRIM(m.ficha) != 'SALESFORCE' ");
        
   $PREPARE insBajas FROM $sql;   
   
   /******** Altas por Cambio Titularidad ********/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente) ");   
   strcat(sql, "SELECT s.numero_cliente ");
   strcat(sql, "FROM est_sol e,solicitud s ");
   strcat(sql, "WHERE s.cam_tit = 'S' ");
   strcat(sql, "AND s.numero_cliente IS NOT NULL ");
   strcat(sql, "AND e.fecha_finalizacion BETWEEN ? AND ? ");
   strcat(sql, "AND s.nro_solicitud = e.nro_solicitud ");
   
   $PREPARE insAltasCT FROM $sql;
   
   /******** Bajas por Cambio Titularidad ********/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente, baja, fecha_evento) ");   
   strcat(sql, "SELECT m.numero_cliente, 'S', m.fecha_modif ");
   strcat(sql, "FROM modif m ");
   strcat(sql, "WHERE ( m.tipo_orden = 'SOL' AND m.codigo_modif = '58' ) ");
   strcat(sql, "AND m.fecha_modif BETWEEN ? AND ? ");
   strcat(sql, "AND TRIM(m.ficha) != 'SALESFORCE' ");

   $PREPARE insBajasCT FROM $sql;
   
   /******** Cambio Tarifa *********/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente) ");   
   strcat(sql, "SELECT m.numero_cliente ");
   strcat(sql, "FROM modif m, cliente c ");
   strcat(sql, "WHERE ( m.tipo_orden = 'MOD' AND m.codigo_modif = '16' ) ");
   strcat(sql, "AND m.fecha_modif BETWEEN ? AND ? ");
   strcat(sql, "AND m.numero_cliente = c.numero_cliente ");
   strcat(sql, "AND TRIM(m.ficha) != 'SALESFORCE' ");
   
/*   
   strcat(sql, "AND ( ");
   strcat(sql, "   ( m.dato_anterior[2] in ('J', 'R') AND m.dato_nuevo[2] = 'G' ) OR ");
   strcat(sql, "   ( m.dato_anterior[2] = 'G' AND m.dato_nuevo[2] in ('J', 'R') ) ");
   strcat(sql, ") ");
*/      
   $PREPARE insTarifas FROM $sql;

   /******** Cambio Potencia ********/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente) ");   
   strcat(sql, "SELECT m.numero_cliente ");
   strcat(sql, "FROM modif m ");
   strcat(sql, "WHERE ( m.tipo_orden = 'MOD' AND m.codigo_modif = '32' ) ");
   strcat(sql, "AND m.fecha_modif BETWEEN ? AND ? ");
   strcat(sql, "AND TRIM(m.ficha) != 'SALESFORCE' ");

   $PREPARE insPotencia FROM $sql;

   /******** Cambio Nombre ********/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente) ");   
   strcat(sql, "SELECT m.numero_cliente ");
   strcat(sql, "FROM modif m ");
   strcat(sql, "WHERE ( m.tipo_orden = 'MOD' AND m.codigo_modif = '4' ) ");
   strcat(sql, "AND m.fecha_modif BETWEEN ? AND ? ");
   strcat(sql, "AND TRIM(m.ficha) != 'SALESFORCE' ");

   $PREPARE insNombre FROM $sql;

   /******* Cambio de Sucursal *******/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente) ");   
   strcat(sql, "SELECT m.numero_cliente ");
   strcat(sql, "FROM modif m ");
   strcat(sql, "WHERE m.fecha_modif BETWEEN ? AND ? ");
   strcat(sql, "AND m.tipo_orden = 'MOD' ");
   strcat(sql, "AND m.codigo_modif = '81' ");
   strcat(sql, "AND TRIM(m.ficha) != 'SALESFORCE' ");
   
   $PREPARE insSucursal FROM $sql;
   
   /******* Cambio direccion suministro *******/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente, nomencla) ");   
   strcat(sql, "SELECT m.numero_cliente, 'S' ");
   strcat(sql, "FROM modif m ");
   strcat(sql, "WHERE m.fecha_modif BETWEEN ? AND ? ");
   strcat(sql, "AND m.tipo_orden = 'MOD' ");
   strcat(sql, "AND m.codigo_modif IN ('79','80','82','83','84','85','86','87','88','90','91','92') ");
   strcat(sql, "AND TRIM(m.ficha) != 'SALESFORCE' ");
   
   $PREPARE insDirSum FROM $sql;

   /******* Cambio direccion postal *******/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente, nomencla) ");   
   strcat(sql, "SELECT m.numero_cliente, 'S' ");
   strcat(sql, "FROM modif m ");
   strcat(sql, "WHERE m.fecha_modif BETWEEN ? AND ? ");
   strcat(sql, "AND m.tipo_orden = 'MOD' ");
   strcat(sql, "AND m.codigo_modif IN ('93', '95','96','97','98','99','100','101','102','103','104') ");
   strcat(sql, "AND TRIM(m.ficha) != 'SALESFORCE' ");

   $PREPARE insDirPost FROM $sql;

   /******* Varios a Saber ******/
/*
  94  CLIENTE.obs_dir
  64  Tipo Documento
  60  Nro.documento
  77   Electrodependencia
  21  Tipo Cliente
  2   ruta lectura
  269 email cliente digital
  76  Clientes VIP
  24  Tarifa Social
  27  EBP
  70, 71, 72, 73, 74 Forma de pago
  7    CUIT
  65   Tipo IVA
  18   Actividad Economica
  * 
  * a partir de la migracion solo se informa lo que sigue
  211 conexion
  67 Acometida
  2   ruta lectura
  201 tension

*/   
/*
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente) ");   
   strcat(sql, "SELECT m.numero_cliente ");
   strcat(sql, "FROM modif m ");
   strcat(sql, "WHERE m.fecha_modif BETWEEN ? AND ? ");
   strcat(sql, "AND m.tipo_orden = 'MOD' ");
   strcat(sql, "AND m.codigo_modif IN ('2','76','77','21','60','64','94','269', '24', '27', ");
   strcat(sql, "'70', '71', '72', '73', '74', '7', '65', '18' ) ");
   strcat(sql, "AND TRIM(m.ficha) != 'SALESFORCE' ");
*/


   $PREPARE insVarios FROM "INSERT INTO sf_actuclie (numero_cliente)
		SELECT m.numero_cliente FROM modif m
		WHERE m.fecha_modif BETWEEN ? AND ?
		AND m.tipo_orden = 'MOD'
		AND m.codigo_modif IN ('211', '67', '2', '201')
		AND TRIM(m.ficha) != 'SALESFORCE' ";
		

   /******** Cambio Datos Medidor *********/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente) ");   
   strcat(sql, "SELECT m.numero_cliente ");
   strcat(sql, "FROM modif m ");
   strcat(sql, "WHERE m.fecha_modif BETWEEN ? AND ? ");
   strcat(sql, "AND m.tipo_orden = 'MOD' ");
   strcat(sql, "AND m.codigo_modif = '303' ");   
   strcat(sql, "AND m.proced = 'CAMMED' ");
   strcat(sql, "AND TRIM(m.ficha) != 'SALESFORCE' ");
   
   $PREPARE insCamMed FROM $sql;
   
   /******* Inversion de Medidor *******/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente) ");   
   strcat(sql, "SELECT m.numero_cliente ");
   strcat(sql, "FROM modif m ");
   strcat(sql, "WHERE m.fecha_modif BETWEEN ? AND ? ");
   strcat(sql, "AND m.tipo_orden = 'MOD' ");
   strcat(sql, "AND m.codigo_modif = '500' ");
   strcat(sql, "AND m.proced = 'INVMED' ");
   strcat(sql, "AND TRIM(m.ficha) != 'SALESFORCE' ");

   $PREPARE insInvMed FROM $sql;

   /********** Alta Medidor **********/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente) ");
   strcat(sql, "SELECT e.numero_cliente ");
   strcat(sql, "FROM estoc e, nucli n, outer modif mo, medid m ");
   strcat(sql, "WHERE e.fecha_puser BETWEEN ? AND  ? ");
   strcat(sql, "AND e.estado_puser ='S' ");
   strcat(sql, "AND e.numero_cliente	= n.numero_cliente ");
   strcat(sql, "AND n.tipo_sum IN ('0','4','7') ");
   strcat(sql, "AND m.numero_cliente	= e.numero_cliente ");
   strcat(sql, "AND m.numero_cliente	= mo.numero_cliente ");
   strcat(sql, "AND mo.tipo_orden IN ( 'MAN' , 'RET' ) ");
   strcat(sql, "AND mo.codigo_modif IN ( '57' , '59' ) ");
   strcat(sql, "AND TRIM(mo.ficha) != 'SALESFORCE' ");
   
   $PREPARE insAltaMed FROM $sql;

   /************ Ingresos Forzados ***********/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente) ");
   strcat(sql, "SELECT t.numero_cliente FROM sfc_tool t ");   

   $PREPARE insForzados FROM $sql;

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

void CreaPrepare(void){
$char sql[10000];
$char sAux[1000];

	memset(sql, '\0', sizeof(sql));
	memset(sAux, '\0', sizeof(sAux));

	/************ FechaLimiteInferior **************/
	strcpy(sql, "SELECT TODAY - t.valor FROM dual d, tabla t ");
	strcat(sql, "WHERE t.nomtabla = 'SAPFAC' ");
	strcat(sql, "AND t.sucursal = '0000' ");
	strcat(sql, "AND t.codigo = 'HISTO' ");
	strcat(sql, "AND t.fecha_activacion <= TODAY ");
	strcat(sql, "AND (t.fecha_desactivac IS NULL OR t.fecha_desactivac > TODAY) ");
		
	$PREPARE selFechaLimInf FROM $sql;

   
   /****** Cursor Bajas *******/
	strcpy(sql, "SELECT DISTINCT numero_cliente, ");
   strcat(sql, "TO_CHAR(fecha_evento, '%Y-%m-%dT%H:%M:00.000Z'), ");
   strcat(sql, "TO_CHAR(fecha_evento, '%Y-%m-%d') ");   
	strcat(sql, "FROM sf_actuclie ");
	strcat(sql, "WHERE baja = 'S' ");
   
   $PREPARE selBajas FROM $sql;
   
   $DECLARE curBajas CURSOR FOR selBajas;

   /********* Registra Corrida *********/
	strcpy(sql, "INSERT INTO sf_actuclie_log ( ");
	strcat(sql, "fecha_corrida, ");
	strcat(sql, "fecha_desde, ");
	strcat(sql, "fecha_hasta, ");
	strcat(sql, "cant_novedades ");
	strcat(sql, ")VALUES( ");
	strcat(sql, "TODAY, ?, ?, ?) ");
   
   $PREPARE insLog FROM $sql;

	/******** Select Path de Archivos ****************/
	strcpy(sql, "SELECT valor_alf ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'PATH' ");
	strcat(sql, "AND codigo = ? ");
	strcat(sql, "AND sucursal = '0000' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND ( fecha_desactivac >= TODAY OR fecha_desactivac IS NULL ) ");

	$PREPARE selRutaFinal FROM $sql;

   /*********** Carga Contactos Cerrados ************/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente, email) ");
	strcat(sql, "SELECT cf_numero_cliente, "); 
	strcat(sql, "TRIM(cf_mail_dir) || '@' || TRIM(cf_mail_server) ");
	strcat(sql, "FROM contacto:ct_contacto_final ");
	strcat(sql, "WHERE cf_fecha_inicio BETWEEN ? AND ? ");
	strcat(sql, "AND cf_numero_cliente > 0 ");
	strcat(sql, "AND cf_mail_dir IS NOT NULL ");
	strcat(sql, "AND TRIM(cf_mail_dir) != ' ' ");
	strcat(sql, "AND cf_rol_inicio NOT IN (SELECT DISTINCT rol FROM sfc_roles) ");
   
   $PREPARE insContactosCerrados FROM $sql;

   /*********** Carga Contactos Abiertos ************/
   strcpy(sql, "INSERT INTO sf_actuclie (numero_cliente, email) ");
	strcat(sql, "SELECT co_numero_cliente, "); 
	strcat(sql, "TRIM(co_mail_dir) || '@' || TRIM(co_mail_server) ");
	strcat(sql, "FROM contacto:ct_contacto ");
	strcat(sql, "WHERE co_fecha_inicio BETWEEN ? AND ? ");
	strcat(sql, "AND co_numero_cliente > 0 ");
	strcat(sql, "AND co_mail_dir IS NOT NULL ");
	strcat(sql, "AND TRIM(co_mail_dir) != ' ' ");
	strcat(sql, "AND co_rol_inicio NOT IN (SELECT DISTINCT rol FROM sfc_roles) ");
   
   $PREPARE insContactosAbiertos FROM $sql;
   
   /******** Borra Tool *********/
   strcpy(sql, "DELETE FROM sfc_tool ");
   
   $PREPARE delTool FROM $sql;      
}


char *FechaGeneracionFormateada( Fecha )
char *Fecha;
{
	$char fmtFecha[9];
	
	memset(fmtFecha,'\0',sizeof(fmtFecha));
	
	$EXECUTE selFechaActualFmt INTO :fmtFecha;
	
	strcpy(Fecha, fmtFecha);
	
   return Fecha;
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
		sprintf(sMensMail,"%sF.Desde:%s;F.Hasta:%s<br>",sMensMail, argv[4], argv[5]);
	}else{
		sprintf( sMensMail, "%sGeneracion<br>", sMensMail );
	}		
	
}
*/


char *strReplace(sCadena, cFind, cRemp)
char sCadena[1000];
char cFind[2];
char cRemp[2];
{
	char sNvaCadena[1000];
	int lLargo;
	int lPos;
	int dPos=0;
	
	lLargo=strlen(sCadena);

	for(lPos=0; lPos<lLargo; lPos++){

		if(sCadena[lPos]!= cFind[0]){
			sNvaCadena[dPos]=sCadena[lPos];
			dPos++;
		}else{
			if(strcmp(cRemp, "")!=0){
				sNvaCadena[dPos]=cRemp[0];	
				dPos++;
			}
		}
	}
	
	sNvaCadena[dPos]='\0';

	return sNvaCadena;
}






short ValidaFecha(stringFecha)
char  *stringFecha;
{
int  error = 0;
long fecha = 0;

   error = rdefmtdate(&fecha, "dd/mm/yyyy", stringFecha);

   switch (error){
      case 0:
         break;	/* OK */
      case -1204:
         printf("Anio Invalido en fecha %s\n", stringFecha);
         return 0;
      case -1205:
         printf("Mes Invalido en fecha %s\n", stringFecha);
         return 0;
      case -1206:
         printf("Dia Invalido en fecha %s\n", stringFecha);
         return 0;
      case -1209:
         printf("A la fecha %s le faltan los delimitadores\n", stringFecha);
         return 0;
      default:
         printf("Fecha %s es inválida\n", stringFecha);
         return 0;
   }

   return 1;
}

void CargaPeriodoAnalisis(argc, argv, sFechaAyer)
int		argc;
char	* argv[];
char  *sFechaAyer;
{
char  sDia[3];
char  sMes[3];
char  sAnio[5];
char  sFechaParam[11];

   memset(sDia, '\0', sizeof(sDia));
   memset(sMes, '\0', sizeof(sMes));
   memset(sAnio, '\0', sizeof(sAnio));
   memset(sFechaParam, '\0', sizeof(sFechaParam));
   
   memset(gsFechaDesdeLarga, '\0', sizeof(gsFechaDesdeLarga));
   memset(gsFechaHastaLarga, '\0', sizeof(gsFechaHastaLarga));
   memset(gsFechaFile, '\0', sizeof(gsFechaFile));

   if(argc >= 3){
      strcpy(sFechaParam, argv[2]);
      sprintf(sDia, "%c%c", sFechaParam[0], sFechaParam[1]);
      sprintf(sMes, "%c%c", sFechaParam[3], sFechaParam[4]);
      sprintf(sAnio, "%c%c%c%c", sFechaParam[6], sFechaParam[7],sFechaParam[8], sFechaParam[9]);
      rdefmtdate(&glFechaDesde, "dd-mm-yyyy", sFechaParam);
   }else{
      sprintf(sDia, "%c%c", sFechaAyer[0], sFechaAyer[1]);
      sprintf(sMes, "%c%c", sFechaAyer[3], sFechaAyer[4]);
      sprintf(sAnio, "%c%c%c%c", sFechaAyer[6], sFechaAyer[7],sFechaAyer[8], sFechaAyer[9]);
      rdefmtdate(&glFechaDesde, "dd/mm/yyyy", sFechaAyer);
   }
   sprintf(gsFechaDesdeLarga, "%s-%s-%s 00:00", sAnio, sMes, sDia);
   sprintf(gsFechaFile, "%s%s%s", sAnio, sMes, sDia);

   memset(sFechaParam, '\0', sizeof(sFechaParam));
   if(argc == 4){
      strcpy(sFechaParam, argv[3]);
      sprintf(sDia, "%c%c", sFechaParam[0], sFechaParam[1]);
      sprintf(sMes, "%c%c", sFechaParam[3], sFechaParam[4]);
      sprintf(sAnio, "%c%c%c%c", sFechaParam[6], sFechaParam[7],sFechaParam[8], sFechaParam[9]);
      sprintf(gsFechaHastaLarga, "%s-%s-%s 23:59", sAnio, sMes, sDia);
      rdefmtdate(&glFechaHasta, "dd/mm/yyyy", sFechaParam);

   }else{
      sprintf(gsFechaHastaLarga, "%s-%s-%s 23:59", sAnio, sMes, sDia);
      glFechaHasta=glFechaDesde;
   }
   
}

short CargaContingente(){
$char sDesde[20];
$char sHasta[20];

   memset(sDesde, '\0', sizeof(sDesde));
   memset(sDesde, '\0', sizeof(sDesde));
   
   sprintf(sDesde, "%s:00", gsFechaDesdeLarga);
   sprintf(sHasta, "%s:59", gsFechaHastaLarga);
   
   /* Limpio Contingente */
   $BEGIN WORK;
   
   $EXECUTE delActuClie;
   
   if(SQLCODE != 0){
      $ROLLBACK WORK;
      printf("Falló limpieza tabla contingente.\n");
      return 0;
   }
   $COMMIT WORK;
   
   /* Altas Puras de clientes */
/*   
   $BEGIN WORK;
   $EXECUTE insAltas USING :glFechaDesde, :glFechaHasta;
   
   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga de altas Puras.\n");
         return 0;
      }
   }
   $COMMIT WORK;
*/   
   /* Bajas Puras Clientes */
/*   
   $BEGIN WORK;
   $EXECUTE insBajas USING :gsFechaDesdeLarga, :gsFechaHastaLarga;

   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga de bajas Puras.\n");
         return 0;
      }
   }
   $COMMIT WORK;
*/   
   /* Altas por Cambio Titularidad */
/*   
   $BEGIN WORK;
   $EXECUTE insAltasCT USING :sDesde, :sHasta;
   
   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga de altas por CT.\n");
         return 0;
      }
   }
   $COMMIT WORK;
*/  
   /* Bajas por Cambio Titularidad */
/*   
   $BEGIN WORK;
   $EXECUTE insBajasCT USING :gsFechaDesdeLarga, :gsFechaHastaLarga;

   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga de bajas por CT.\n");
         return 0;
      }
   }
   $COMMIT WORK;
*/   
   /* Cambio Tarifas */
/*   
   $BEGIN WORK;
   $EXECUTE insTarifas USING :gsFechaDesdeLarga, :gsFechaHastaLarga;

   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga Cambio Tarifas.\n");
         return 0;
      }
   }
   $COMMIT WORK;
*/   
   /* Cambio Potencia */
/*   
   $BEGIN WORK;
   $EXECUTE insPotencia USING :gsFechaDesdeLarga, :gsFechaHastaLarga;

   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga Cambio Potencia.\n");
         return 0;
      }
   }
   $COMMIT WORK;
*/   
   /* Cambio Nombre */
/*   
   $BEGIN WORK;
   $EXECUTE insNombre USING :gsFechaDesdeLarga, :gsFechaHastaLarga;

   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga Cambio Nombre.\n");
         return 0;
      }
   }
   $COMMIT WORK;
*/   
   /* Cambio Sucursal */
/*   
   $BEGIN WORK;
   $EXECUTE insSucursal USING :gsFechaDesdeLarga, :gsFechaHastaLarga;

   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga Cambio Sucursal.\n");
         return 0;
      }
   }
   $COMMIT WORK;
*/   
   /* Cambio Dirección Suministro */
/*   
   $BEGIN WORK;
   $EXECUTE insDirSum USING :gsFechaDesdeLarga, :gsFechaHastaLarga;

   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga Cambio Direccion Suministro.\n");
         return 0;
      }
   }
   $COMMIT WORK;
*/   
   /* Cambio Dirección Postal */
/*   
   $BEGIN WORK;
   $EXECUTE insDirPost USING :gsFechaDesdeLarga, :gsFechaHastaLarga;

   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga Cambio Direccion Postal.\n");
         return 0;
      }
   }
   $COMMIT WORK;
*/   
   /* Cambios Varios 2021 */
   $BEGIN WORK;
   $EXECUTE insVarios USING :gsFechaDesdeLarga, :gsFechaHastaLarga;

   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga Cambio Varios.\n");
         return 0;
      }
   }
   $COMMIT WORK;
   
   /*  Cambio Datos Medidor */
/*   
   $BEGIN WORK;
   $EXECUTE insCamMed USING :gsFechaDesdeLarga, :gsFechaHastaLarga;

   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga Cambio Data Medidor.\n");
         return 0;
      }
   }
   $COMMIT WORK;
*/   
   /* Inversion de Medidor */
/*   
   $BEGIN WORK;
   $EXECUTE insInvMed USING :gsFechaDesdeLarga, :gsFechaHastaLarga;

   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga Inv. Medidor.\n");
         return 0;
      }
   }
   $COMMIT WORK;
*/   
   /* Alta de Medidor */
/*   
   $BEGIN WORK;
   $EXECUTE insAltaMed USING :glFechaDesde, :glFechaHasta;

   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga Inv. Medidor.\n");
         return 0;
      }
   }
   $COMMIT WORK;
*/   
   /* Clientes Forzados */
   $BEGIN WORK;
   $EXECUTE insForzados;

   if(SQLCODE != 0){
      if(SQLCODE != 100){
         $ROLLBACK WORK;
         printf("Falló Carga de forzados.\n");
         return 0;
      }
   }
   $COMMIT WORK;
   
   return 1;
}

short LeoBajas(reg)
$ClsBaja *reg;
{

   InicializaBaja(reg);
   
   $FETCH curBajas INTO :reg->numero_cliente,
                        :reg->sFechaLarga,
                        :reg->sFechaCorta;
   
   if(SQLCODE != 0){
      return 0;
   }
   
   return 1;
}

void InicializaBaja(reg)
$ClsBaja *reg;
{

   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   memset(reg->sFechaLarga, '\0', sizeof(reg->sFechaLarga));
   memset(reg->sFechaCorta, '\0', sizeof(reg->sFechaCorta));
   
}


void GeneraBaja(reg)
ClsBaja  reg;
{
	char	sLinea[1000];
	
	memset(sLinea, '\0', sizeof(sLinea));

   /* External ID Suministro */
   sprintf(sLinea, "\"%ldAR\";", reg.numero_cliente);
   /* Estado del suministro */
   strcat(sLinea, "\"1\";");
   
   /* Estado del cliente */
   strcat(sLinea, "\"1\";");
   
   /* Fecha de baja */
   sprintf(sLinea, "%s\"%s\";", sLinea, reg.sFechaLarga);
   
   /* External ID del activo */
   sprintf(sLinea, "%s\"%ldARG\";", sLinea, reg.numero_cliente);
   
   /* Estado del Activo */
   strcat(sLinea, "\"Unsuscribed\";");
   
   /* Estado del Activo (Contratación) */
   strcat(sLinea, "\"Disconnected\";");
   
   /* External ID del Contrato */
   sprintf(sLinea, "%s\"%ldCTOARG\";", sLinea, reg.numero_cliente);
   
   /* Estado del contrato */
   strcat(sLinea, "\"Inactivated\";");
   
   /* Fecha de baja del contrato */
   sprintf(sLinea, "%s\"%s\";", sLinea, reg.sFechaCorta);
   
   /* External ID de la linea de contrato */
   sprintf(sLinea, "%s\"%ldLCOARG\";", sLinea, reg.numero_cliente);
   
   /* Estado de linea de contrato (contratación) */
   strcat(sLinea, "\"Inactive\";");
   
   /* Estado de la linea de contrato */
	strcat(sLinea, "\"Inactive\"");
   
	strcat(sLinea, "\r\n");
	
	fprintf(fpBajasUnx, sLinea);	

}

short RegistraCorrida(iCant)
$long iCant;
{

   $EXECUTE insLog USING
      :glFechaDesde,
      :glFechaHasta,
      :iCant;
      
   if(SQLCODE != 0)
      return 0;

   return 1;
}

short CargoContactos(void){
$char sDesde[20];
$char sHasta[20];

   memset(sDesde, '\0', sizeof(sDesde));
   memset(sDesde, '\0', sizeof(sDesde));
   
   sprintf(sDesde, "%s:00", gsFechaDesdeLarga);
   sprintf(sHasta, "%s:59", gsFechaHastaLarga);
   
   /* Cargo Contactos cerrados*/
   $EXECUTE insContactosCerrados USING :sDesde, :sHasta;

   if(SQLCODE != 0){
      printf("Falló carga tabla contingente etapa CONTACTOS CERRADOS.\n");
      return 0;
   }

   /* Cargo Contactos Abiertos*/
   $EXECUTE insContactosAbiertos USING :sDesde, :sHasta;

   if(SQLCODE != 0){
      printf("Falló carga tabla contingente etapa CONTACTOS ABIERTOS.\n");
      return 0;
   }

   return 1;
}



short ValidaEmail(eMail)
char    *eMail;
{
    int     i, j, s;
    int     largo=0;
    int     valor=0;
    char    *sResu;
    int     iPos;
    int     iAsc;

    largo=strlen(eMail);
    iPos=0;
    if(largo<=0){
        return 0;
    }

    /* Que no tenga caracteres inválidos */
    valor=0;
    i=0;
    s=0;

    while(i<largo && s==0){
        iAsc=eMail[i];

        if(iAsc >= 1 && iAsc < 45){
            s=1;
        }

        if(iAsc==47)
            s=1;

        if(iAsc >= 58 && iAsc <= 63){
            s=1;
        }

        if(iAsc >= 91 && iAsc <= 96 && iAsc != 95){
            s=1;
        }

        if(iAsc >= 126 && iAsc <= 255){
            s=1;
        }

        i++;

    }

    if(s==1){
        return 0;
   }

    /* Que no termine en punto */
    if(eMail[largo-1]=='.'){
        return 0;
    }


    /* Que solo tenga una @ */
    valor=instr(eMail, "@");
    if(valor != 1){
        return 0;
    }

    /* Que tenga al menos un punto */
    valor=instr(eMail, ".");
    if(valor < 1){
        return 0;
    }

    /* Que no tenga '..' */
    if(strstr(eMail, "..") != NULL){
        return 0;
    }

    /* Que no tenga '.@' */
    if(strstr(eMail, ".@") != NULL){
        return 0;
    }

    /* Que no tenga '@.' */
    if(strstr(eMail, "@.") != NULL){
        return 0;
    }

    return 1;
}

int instr(cadena, patron)
char  *cadena;
char  *patron;
{
   int valor=0;
   int i;
   int largo;
   
   largo = strlen(cadena);
   
   for(i=0; i<largo; i++){
      if(cadena[i]==patron[0])
         valor++;
   }
   return valor;
}
