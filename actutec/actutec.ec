/*
 *  actutec.ec  - Actualiza tabla TECNI
 *
 *  Creado por:
 *      Gaston D. Vast (Seta Sistemas)
 *
 *  Creado el:
 *      23/08/2002
 *
 *  Descripcion:
 *
 *      Actualiza tabla TECNI con los datos provenientes
 *      de un archivo de texto (tecnimac.txt) que se
 *      encuentran en el directorio indicado por el
 *      campo valor_alf de la tabla TABLA para nomtab = "PATH"
 *      y sucursal = "0000".
 *
 *      Solo procesa el primer archivo que satisfaga el 
 *      patron de busqueda, actualmente que empiece con "TECNI"
 *      y que tenga extension ".MAC".
 *
 *      Solo se actualizan los registros que se encuentren en
 *      la tabla TECNI para el correlativo obtenido en el
 *      archivo de texto indicado.
 *
 *  $Log:   /usr/pvcs/Proyectos/synergia/medid/esqlc/actutec/actutec.ecv  $
 * 
 *    Rev 1.13   24 Sep 2021 15:25:06   ldvalle
 * MIGRACION. Se registra en MODIF algunas modificaciones de data tecnica
 *  
 *    Rev 1.12   10 Sep 2014 15:25:06   aarrien
 * ME159 - Se preparan sentencias y otras modif para mejorar perf.
 * 
 *    Rev 1.11   25 Feb 2013 15:36:38   pablop
 * ER1382 - Se agrega nivel de aislamiento COMMITTED READ
 * 
 *    Rev 1.10   25 Feb 2013 14:01:26   pablop
 * ER1382 - No se lockean tablas en forma exclusiva. Se agrega tiempo de espera. Se hacen transacciones parciales
 *
 *    Rev 1.9   06 Feb 2013 11:46:36   pablop
 * ER1379 - Si x ó y no tiene valores coherentes no se actualiza UBICA_GEO_CLIENTE
 * 
 *    Rev 1.8   24 Feb 2011 14:58:46   djohnson
 *       OMxxxx - Se agregan 2 nuevos datos al archivo de entrada (x, y),
 * 		       Se calcula la latitud y longitud y se updetea la tabla ubica_geo_cliente
 * 			   con esos datos.
 * 
 *    Rev 1.7   16 Dec 2003 11:05:30   gvast
 * Se agrega que los archivos deben empezar con TECNI ademas de la extension .MAC - ME028
 * 
 *    Rev 1.6   16 May 2003 11:43:12   amfernan
 * Referencia: ER423
 * Se modifico el caracter apostrofo de los campos de las descripciones de calles
 * y localidad: tec_nom_calle, tec_entre_calle1, tec_entre_calle2, tec_localidad
 * en el insert de la tabla TECNI (updTecni).
 * 
 *    Rev 1.6   15 May 2003 13:07:12   amf  Ref: ER423
 * Se agrego la funcion cambia_caracter para cambiar los apostrofo de los 
 * campos de las descripciones de calles y localidad: 
 * tec_nom_calle, tec_entre_calle1, tec_entre_calle2, tec_localidad
 * en el insert de la tabla TECNI. (updTecni)
 *
 *    Rev 1.5   23 Jan 2003 16:27:42   gvast
 * Se agregan seis campos de codigo no actualizados en la version previa.
 * 
 *    Rev 1.4   07 Oct 2002 11:35:22   gvast
 * Se agrega lockeo exclusivo a la tabla TECNI
 * 
 *    Rev 1.3   13 Sep 2002 14:59:08   gvast
 * se modifica metodo de validacion de extension de archivo
 *
 *    Rev 1.1   06 Sep 2002 16:15:40   gvast
 * Se agrega actualizacion del campo tec_nom_subest
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <time.h>
#include <sqlerror.h>
#include <ustring.h>

EXEC SQL include sqltypes ;

#ifndef     TRUE
    #define     TRUE    1
#endif

#ifndef     FALSE
    #define     FALSE   0
#endif

#define BORRAR(x)   memset(&x, 0, sizeof x)

#define F_PATERN    ".MAC"      /* Extension */
#define F_NAMPAT    "TECNI"     /* Comienzo - (ME028) by GDV */

#define MAXLINELEN  512

/* Variables host globales */
EXEC SQL BEGIN DECLARE SECTION;

    /* Estructura para Registro Medidores */
    typedef struct {
        string  tec_subestacion[4];
        string  tec_alimentador[12];
        string  tec_centro_trans[21];
        string  tec_fase[2];
        long    tec_acometida;
        string  tec_tipo_instala[21];
        string  tec_nom_calle[26];
        string  tec_nro_dir[7];
        string  tec_piso_dir[7];
        string  tec_depto_dir[7];
        string  tec_entre_calle1[26];
        string  tec_entre_calle2[26];
        string  tec_manzana[6];
        string  tec_barrio[26];
        string  tec_localidad[26];
        string  tec_partido[26];
        string  tec_sucursal[26];
        string  tec_nom_subest[26];
        /* Nuevos ~~~~~~~~~~~~~~~~ */
        string  tec_cod_calle[7];
        string  tec_cod_entre[7];
        string  tec_cod_ycalle[7];
        string  tec_cod_suc[5];
        string  tec_cod_part[4];
        string  tec_cod_local[4];
        double	Ugeo_x; /*DJOHNSON*/
        double	Ugeo_y; /*DJOHNSON*/
    } T_Tec;

EXEC SQL END DECLARE SECTION;

/* variable globales ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

FILE *fp1;              /* Archivo de entrada */

#define MAXCAMP     30  /* Cantidad de campos */

/* Nombres de campos (Referencias) 
 * La cantidad de items debe coincidir con MAXCAMP */
enum  campos_tecni {
        SISTEMA=1,  RUE,        TARIFA,     ESTADO,
        CTMTBT,     ID_ALIM,    SSEE,       TIPO_INST,
        FASE,       COD_ACOM,   NOM_BARRIO, COD_CALLE,
        NOM_CALLE,  NRO_DIR,    PISO_DIR,   DEPTO_DIR,
        COD_ENTRE,  NOM_ENTRE,  COD_YCALLE, NOM_YCALLE,
        MANZANA,    SUCURSAL,   DES_SUC,    PARTIDO,
        DES_PAR,    LOCALIDAD,  DES_LOC,    NOM_SUBEST,
        U_GEO_X,	U_GEO_Y
    };

/* Declaracion de funciones utilizadas ~~~~~~~~~~~~~~~~ */
int  getPath(char *cPath);
long getCampos(char *cReg, T_Tec *pTec);
int  fndTecni(long pRue);
void updTecni(long pRue, T_Tec pTec);
char *gv_strtok(char *s1, char *s2);
int  gv_strpat(char *string1 ,char *string2);
int  getArchivo(char *cDir, char *cPat, char *cFile);
char * cambia_caracter(char * cad, char * caracter);
void Upd_Ubica_Geo_Cliente(long pRue, T_Tec pTec);/*DJOHNSON OMxxxx 22/02/2011*/
void RegCambios(long pRue, T_Tec pTec);  /* LDVALLE MIGRACION 24/09/2021*/
/* ----------------------------------------------------- */
/* Comienzo */
void
main(int argc, char **argv)
{
    EXEC SQL BEGIN DECLARE SECTION;
        char    cDB[128];
        string  xcPath[512];
        T_Tec   rTec;
    EXEC SQL END DECLARE SECTION;

    char    cFile[512];
    char    cLinea[MAXLINELEN];
    long    nRue = 0;
    long    lCantReg = 0;

    if (argc != 2) {
        printf("Formato:\n\t%s <database>\n", argv[0]);
        exit(1);
    }

    /* Toma base de datos de parametro */
    memset(cDB, 0, sizeof(cDB));
    strcpy(cDB, argv[1]);

    EXEC SQL WHENEVER ERROR CALL SqlError ;
    EXEC SQL CONNECT TO :cDB ;
	EXEC SQL SET ISOLATION TO DIRTY READ;
    EXEC SQL SET LOCK MODE TO WAIT 120;

    /* Obtiene path */
    if (getPath(xcPath) != 0) {
        printf("No pudo encontrar el path para el archivo!\n");
        exit(1);
    }

    /* Obtiene nombre del primer archivo .MAC */
    if (getArchivo(xcPath, F_PATERN, cFile) != 0) {
        printf("No pudo encontrar ningun archivo que comience con %s y de extension %s\n",
                F_NAMPAT, F_PATERN);
        exit(1);
    }

    /* Abre archivos de Reporte y Bitacora */
    fp1 = fopen(cFile, "r");
    if (fp1 == NULL) {
        printf("No pudo abrir el archivo de Entrada = %s\n", cFile);
        exit(1);
    }

    EXEC SQL BEGIN WORK ;
    
    /* Recorre archivo de entrada */
    while (fgets(cLinea, MAXLINELEN, fp1) != NULL)
    {
		/* PDP - ER1382 - Hago transacciones parciales */
		if (!(++lCantReg % 10000))
		{
			EXEC SQL COMMIT WORK;
			EXEC SQL BEGIN WORK;
		}
        
        /* Blanquea registro a cargar */
        BORRAR(rTec);

        /* coloca campos leidos en estructura */
        nRue = getCampos(cLinea, &rTec);
        
        if (fndTecni(nRue) > 0) {
			RegCambios(nRue, rTec); /* Migracion SDF 09/2021 */

            updTecni(nRue, rTec);
            /* PDP - ER1379 - Si x ó y no tiene valores coherentes no actualizo UBICA_GEO_CLIENTE */
            if (rTec.Ugeo_x >= 1 && rTec.Ugeo_y >= 1)
                Upd_Ubica_Geo_Cliente(nRue, rTec);

        } else {
            ; /* Si no encuentra el RUE no lo agrega */
        }

        /* Leer proxima linea */
    }

    EXEC SQL COMMIT WORK ; 
    EXEC SQL DISCONNECT CURRENT ;

    fclose(fp1);    /* cierra entrada */

    exit(0);
}

/* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */
/* Obtiene el primer archivo del directorio indicado */
int
getArchivo(char *cDir, char *cPat, char *cFile)
{
	DIR *dp;
	struct dirent *drp;
	struct stat finfo;
	
    char cNombre[512];
	char cFullName[512];
	int  nCont   = 0;
	int  nResult = 0;

	/* Se abre el directorio y se verifica si existe */
	if ((dp = opendir(cDir)) == NULL)
	{
		fprintf(stderr, "Error: No se pudo acceder al directorio %s\n", cDir);
		exit(1);
	}

	/* Recorre hasta el final la lista de archivos del
	 * directorio seleccionado. */
	while ((drp = readdir(dp)) != NULL)
	{
        memset(cNombre, 0, sizeof cNombre);

		/* Se ignora la referencia a si mismo y al directorio padre. */
		strcpy(cNombre, (char *) drp->d_name);
		if (strcmp(cNombre, "." ) == 0 ||
		    strcmp(cNombre, "..") == 0)  continue;

		/* arma nombre de archivo con ruta completa
		 * para que lo pueda ubicar stat() */
        memset(cFullName, 0, sizeof cFullName);

        /* Ignora los que no empienzan con "TECNI" - (ME028) by GDV */
        if (strncmp(cNombre, F_NAMPAT, 5) != 0)
            continue;

        /* Verifica si el path pasado termina con '/' */
        if (cDir[strlen(cDir)-1] == '/')
		    sprintf(cFullName, "%s%s", cDir, cNombre);
		else
		    sprintf(cFullName, "%s/%s", cDir, cNombre);

		if (stat(cFullName, &finfo) == -1)
		{
			fprintf(stderr, "Error de acceso a %s\n", cNombre);
			exit(1);
		}

		/* No lista directorios, solo archivos
		 * Aqui se puede modificar para que busque
		 * dentro del directorio que encuentre */
		if ((finfo.st_mode & S_IFMT) == S_IFDIR)
			continue;

        /* Verifica si es del Tipo (extension) buscado */
        if (gv_strpat(cPat, cNombre) == TRUE) {
    		++nCont;
    		break;
        } else {
            continue;
        }
	}

	closedir(dp);

    if (nCont > 0)
        nResult = 0;
    else
        nResult = -1;

    strcpy(cFile, cFullName);

	return (nResult);

}

/* Obtiene el PATH para los archivos de datos, de la tabla TABLA */
int
getPath(char *cPath)
{
    EXEC SQL BEGIN DECLARE SECTION;
       string   xcPath[51];
    EXEC SQL END DECLARE SECTION;

    int nResult = 0;

    memset(xcPath, 0, sizeof xcPath);

    EXEC SQL
        SELECT  valor_alf
        INTO    :xcPath
        FROM    TABLA
        WHERE   nomtabla = 'PATH'
        AND     codigo   = 'TECNI'
        AND     sucursal = '0000';

    strcpy(cPath, xcPath);

    if (sqlca.sqlerrd[2] > 0)
        nResult = 0;                /* OK */
    else
        nResult = -1;               /* Error */

    return  (nResult);

}

/* Obtiene los campos del archivo y los coloca en una estructura */
long
getCampos(char *cReg, T_Tec *pTec)
{
    EXEC SQL BEGIN DECLARE SECTION;
        long    xnRue;
    EXEC SQL END DECLARE SECTION;

    char *p;
    int  i = 0;
    int  nSuc = 0;
    char cSuc[5];

    p = gv_strtok(cReg, "|");

    /* Carga variables con campos correspondientes */
    do
    {
        i++;

        if (i>MAXCAMP) break;

        switch (i)
        {
            case    RUE:
                xnRue = atoi(p);
                break;

            case    SSEE:
                strcpy(pTec->tec_subestacion, p);
                break;

            case    ID_ALIM:
                strcpy(pTec->tec_alimentador, p);
                break;

            case    CTMTBT:
                strcpy(pTec->tec_centro_trans, p);
                break;

            case    FASE:
                strcpy(pTec->tec_fase, p);
                break;

            case    COD_ACOM:
                pTec->tec_acometida = atol(p);
                break;

            case    TIPO_INST:
                strcpy(pTec->tec_tipo_instala, p);
                break;

            case    NOM_CALLE:
                strcpy(pTec->tec_nom_calle, p);
                break;

            case    NRO_DIR:
                strcpy(pTec->tec_nro_dir, p);
                break;

            case    PISO_DIR:
                strcpy(pTec->tec_piso_dir, p);
                break;

            case    DEPTO_DIR:
                strcpy(pTec->tec_depto_dir, p);
                break;

            case    NOM_ENTRE:
                strcpy(pTec->tec_entre_calle1, p);
                break;

            case    NOM_YCALLE:
                strcpy(pTec->tec_entre_calle2, p);
                break;

            case    MANZANA:
                strcpy(pTec->tec_manzana, p);
                break;

            case    NOM_BARRIO:
                strcpy(pTec->tec_barrio, p);
                break;

            case    DES_LOC:
                strcpy(pTec->tec_localidad, p);
                break;

            case    DES_PAR:
                strcpy(pTec->tec_partido, p);
                break;

            case    DES_SUC:
                strcpy(pTec->tec_sucursal, p);
                break;

            case    NOM_SUBEST:
                strcpy(pTec->tec_nom_subest, p);
                break;
            /* Nuevos ~~~~~~~~~~~~~~~~~~~~~~~~ */
            case    COD_CALLE:
                strcpy(pTec->tec_cod_calle, p);
                break;

            case    COD_ENTRE:
                strcpy(pTec->tec_cod_entre, p);
                break;
            
            case    COD_YCALLE:
                strcpy(pTec->tec_cod_ycalle, p);
                break;

            case    SUCURSAL:
                nSuc = atoi(p);
                memset(cSuc, 0, sizeof(cSuc));
                sprintf(cSuc, "%04d", nSuc);
                strcpy(pTec->tec_cod_suc, cSuc);
                break;
            
            case    PARTIDO:
                strcpy(pTec->tec_cod_part, p);
                break;

            case    LOCALIDAD:
                strcpy(pTec->tec_cod_local, p);
                break;
                
            case    U_GEO_X:
                pTec->Ugeo_x = atof(p);
                break;
                
            case    U_GEO_Y:
                pTec->Ugeo_y = atof(p);
                break;
                
            default:
            ;
        }

        /* separa proximo campo */
        p = gv_strtok('\0', "|");

    } while (p);

    return (xnRue);
}

/* Busca Rue en tabla Tecni */
int
fndTecni(long pRue)
{
    EXEC SQL BEGIN DECLARE SECTION;
        long    xnRue;
        long    xnRow;
    EXEC SQL END DECLARE SECTION;
    int nResult = 0;

    xnRow = 0;
    xnRue = pRue;
	
	return 1; /* no es necesario buscar */

    EXEC SQL
        SELECT  ROWID
        INTO    :xnRow
        FROM    TECNI
        WHERE   NUMERO_CLIENTE = :xnRue;

    nResult = sqlca.sqlerrd[2];

    return (nResult);
}

void
updTecni(long pRue, T_Tec pTec)
{
    EXEC SQL BEGIN DECLARE SECTION;
        T_Tec   rTec;
        long    xnRue;
    EXEC SQL END DECLARE SECTION;
	static int iPrepUpdTecni = 0;

    BORRAR(rTec);

    rTec  = pTec;
    xnRue = pRue;

    cambia_caracter(rTec.tec_nom_calle,   "'");
    cambia_caracter(rTec.tec_entre_calle1,"'");
    cambia_caracter(rTec.tec_entre_calle2,"'");
    cambia_caracter(rTec.tec_localidad,   "'");    

	if (!iPrepUpdTecni)
	{
		EXEC SQL PREPARE updTecni FROM
			"UPDATE tecni
				SET tec_subestacion  = ?,
                    tec_alimentador  = ?,
                    tec_centro_trans = ?,
                    tec_fase         = ?,
                    tec_acometida    = ?,
                    tec_tipo_instala = ?,
                    tec_nom_calle    = ?,
                    tec_nro_dir      = ?,
                    tec_piso_dir     = ?,
                    tec_depto_dir    = ?,
                    tec_entre_calle1 = ?,
                    tec_entre_calle2 = ?,
                    tec_manzana      = ?,
                    tec_barrio       = ?,
                    tec_localidad    = ?,
                    tec_partido      = ?,
                    tec_sucursal     = ?,
                    tec_nom_subest   = ?,
                    tec_cod_calle    = ?,
                    tec_cod_entre    = ?,
                    tec_cod_ycalle   = ?,
                    tec_cod_suc      = ?,
                    tec_cod_part     = ?,
                    tec_cod_local    = ? 
             WHERE  numero_cliente   = ?";

		iPrepUpdTecni = 1;
	}
    EXEC SQL EXECUTE updTecni
			USING :rTec.tec_subestacion  ,
                  :rTec.tec_alimentador  ,
                  :rTec.tec_centro_trans ,
                  :rTec.tec_fase         ,
                  :rTec.tec_acometida    ,
                  :rTec.tec_tipo_instala ,
                  :rTec.tec_nom_calle    ,
                  :rTec.tec_nro_dir      ,
                  :rTec.tec_piso_dir     ,
                  :rTec.tec_depto_dir    ,
                  :rTec.tec_entre_calle1 ,
                  :rTec.tec_entre_calle2 ,
                  :rTec.tec_manzana      ,
                  :rTec.tec_barrio       ,
                  :rTec.tec_localidad    ,
                  :rTec.tec_partido      ,
                  :rTec.tec_sucursal     ,
                  :rTec.tec_nom_subest   ,
                  :rTec.tec_cod_calle    ,
                  :rTec.tec_cod_entre    ,
                  :rTec.tec_cod_ycalle   ,
                  :rTec.tec_cod_suc      ,
                  :rTec.tec_cod_part     ,
                  :rTec.tec_cod_local    ,
				  :xnRue;
}

/*****************************************************************
* Descripcion   : Funciona practicamente en forma identica a la funcion
*				  strtok (ver man strtok), excepto en los casos en los
*				  que tenemos una secuencia de separadores sin datos en
*				  en medio. En ese caso, la funcion retorna una cadena
*				  vacia por cada separador.
*
* Entradas      : s1 = string inicial, s2 = delimitador
*
* Return Values : Retorna un puntero al proximo token
******************************************************************/
char *
gv_strtok(char *s1, char *s2)
{
	char *token=NULL;
	char *next_sep=NULL;
	static char *string;

	if (s1!=NULL) string = s1;

	if (string == NULL) return NULL;

	/*************************************************
	* busco la primer ocurrencia en string de alguno *
	* de los separadores contenidos en la cadena s2. *
	*************************************************/
	if ((next_sep = strpbrk(string,s2)) != NULL) {
		token = string;
		string = next_sep+1;
		*next_sep = '\0';
	/**************************************************
	* si no encuentro un separador, y aun no estoy al *
	* final de la cadena, retorno lo que resta de esa *
	* cadena .                                        *
	**************************************************/
	} else if (*string != '\0') {
		token = string;
		string = NULL;
	/******************************************************
	* si estoy al final de la cadena, entonces inicializo *
	* la variable string y retorno token en NULL.         *
	******************************************************/
	} else string = NULL;

	return token;
}

/*******************************************************************************
* devuelve :    TRUE si la extension string1 se encuentra en string2
*               en caso contrario devuelve FALSE
*******************************************************************************/
int
gv_strpat(char *string1 ,char *string2)
{
    int nlen_str1, nlen_str2;
    int nResult = 0;
    int nPos    = 0;
    char cTemp[128];

    memset(cTemp, 0, sizeof cTemp);

    nlen_str1 = strlen(string1);
    nlen_str2 = strlen(string2);
    nPos = nlen_str2 - nlen_str1;

    if (nPos <= 0) {
        nResult = FALSE;
    } else {
        strncpy(cTemp,(string2+nPos),nlen_str1);

        if (strcmp(cTemp, string1) == 0)
            nResult = TRUE;
        else
            nResult = FALSE;
    }

	return nResult;
}

/* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

/*******************************************************************************
* Retorna una cadena recibida como parametro, y cambia las comillas ("'") 
* por acento para evitar errores de acceso a la base de datos
*******************************************************************************/
char * cambia_caracter(char * cad, char * caracter)
{
    char *paux;
    paux = NULL;
    
    while ( paux = (strstr(cad, caracter)) )
        *paux = '`';
           
    return cad;
}

/* ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ */

void Upd_Ubica_Geo_Cliente(long pRue, T_Tec pTec)
{
    EXEC SQL BEGIN DECLARE SECTION;
        T_Tec   rTec;
        long    xnRue;
        char	sLat[18];
        char	sLon[18];
    EXEC SQL END DECLARE SECTION;
	static int iPrepUGC = 0;

    BORRAR(rTec);
    rTec  = pTec;
    xnRue = pRue;
	
	/*llamada al SP que convierte 'x' 'y' en latitud y longitud*/
	$EXECUTE PROCEDURE retorna_lat_lon(:rTec.Ugeo_x, :rTec.Ugeo_y) 
				INTO  :sLat, :sLon;
	if (!iPrepUGC)
	{
 		EXEC SQL PREPARE updUGC FROM
				"UPDATE ubica_geo_cliente
 				    SET tipo_tarifa    = 'T1',
 						x              = ?,
 						y              = ?,
 						lat            = ?,
 						lon            = ?,
 						fecha_registro = CURRENT
 				 WHERE  numero_cliente = ?
 				   AND  origen         = 'SIS_TEC'";
		
		iPrepUGC = 1;
	}
    EXEC SQL EXECUTE updUGC
			USING	
					:rTec.Ugeo_x,
					:rTec.Ugeo_y,
					:sLat,
					:sLon,
					:xnRue;

}

void RegCambios(pRue, pTec)
$long 	pRue;
$T_Tec	pTec;
{
	static int iPrepSelDataCli = 0;
	static int iPrepRegCambioDataCli = 0;
	
	$char	tec_centro_trans[21];
	$char	tec_alimentador[12];
	$char	tec_subestacion[4];
	$char	sDatoVjo[56];
	$char	sDatoNvo[56];

	int iFlag=0;
	
	memset(tec_centro_trans, '\0', sizeof(tec_centro_trans));
	memset(tec_alimentador, '\0', sizeof(tec_alimentador));
	memset(tec_subestacion, '\0', sizeof(tec_subestacion));

	memset(sDatoVjo, '\0', sizeof(sDatoVjo));
	memset(sDatoNvo, '\0', sizeof(sDatoNvo));
	
	if (!iPrepSelDataCli){
		$PREPARE selDataCli FROM "SELECT tec_subestacion, tec_alimentador,  tec_centro_trans 
			FROM tecni WHERE numero_cliente = ? ";
			
		iPrepSelDataCli = 1;
	}
	
	if (!iPrepRegCambioDataCli){
		$PREPARE regCambiosData FROM "INSERT INTO modif(numero_cliente, tipo_orden, ficha, fecha_modif, tipo_cliente, 
		codigo_modif, dato_anterior, dato_nuevo, proced, dir_ip)VALUES(
		?, 'MOD', 'CERTA', CURRENT, 'A', '700', ?, ?, 'ACTUTEC', '192.9.120.1') ";
			
		iPrepRegCambioDataCli = 1;
	}
	
	$EXECUTE selDataCli INTO :tec_subestacion, :tec_alimentador, :tec_centro_trans USING :pRue;
	
	if(SQLCODE == 0){
		
		alltrim(tec_subestacion, ' ');
		alltrim(tec_alimentador, ' ');
		alltrim(tec_centro_trans, ' ');
		alltrim(pTec.tec_subestacion, ' ');
		alltrim(pTec.tec_alimentador, ' ');
		alltrim(pTec.tec_centro_trans, ' ');
		
		if(strcmp(tec_subestacion, pTec.tec_subestacion)!=0){
			sprintf(sDatoVjo, "SUBESTACION-%s", tec_subestacion);
			sprintf(sDatoNvo, "SUBESTACION-%s", pTec.tec_subestacion);
			iFlag=1;
		}else if(strcmp(tec_alimentador, pTec.tec_alimentador)!=0){
			sprintf(sDatoVjo, "ALIMENTADOR-%s", tec_alimentador);
			sprintf(sDatoNvo, "ALIMENTADOR-%s", pTec.tec_alimentador);
			iFlag=1;
		}else if(strcmp(tec_centro_trans, pTec.tec_centro_trans)!=0){
			sprintf(sDatoVjo, "CENTRO_TRANS-%s", tec_centro_trans);
			sprintf(sDatoNvo, "CENTRO_TRANS-%s", pTec.tec_centro_trans);
			iFlag=1;
		}
		
		if(iFlag==1){
			$EXECUTE regCambiosData USING :pRue, :sDatoVjo, :sDatoNvo;
		}
	}
	
}

