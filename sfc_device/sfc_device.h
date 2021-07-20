$ifndef SFCDEVICE_H;
$define SFCDEVICE_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

/* --- Estructuras ----*/
$typedef struct{
   long	numero_cliente;
   char  codModif[4];
   char  proced[21];
   char  dtFechaModif[20];
   char  sFechaModif[17];
   long  lFechaModif;
   char  datoViejo[56];
   char  datoNuevo[56];
   
   long  nroMedidorRet;
   char  marcaMedidorRet[4];
   char  modeloMedidorRet[3];
   
   long  nroMedidorInst;
   char  marcaMedidorInst[4];
   char  modeloMedidorInst[3];
   
   double lecturaInstalacion;
   double lecturaRetiro;
     
}ClsModif;

$typedef struct{
   long	nroClienteAnterior;
   long  nroClienteActual;
   char  sFechaEvento[11];

   double lecturaInstalacion;
   double lecturaRetiro;
   
}ClsCamTit;


$typedef struct{
   long	numero;
	char	marca[4];
	char	modelo[3];
   char  estado[4];	
	char	med_ubic[4]; 
	char	med_codubic[11];
	long	numero_cliente;
   char	tipo_medidor[2];
   char  estado_sfc[2];
   
   char  fecha_prim_insta[11];
   char  fecha_ult_insta[11];
   float constante;
   int   med_anio;
   
}ClsMedidor;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );

short LeoModif(ClsModif *);
short LeoEstoc(ClsModif *);
void  InicializoModif(ClsModif *);
void  ExtraeMedidores(ClsModif *);
short getDataMedidor(ClsModif, ClsMedidor *, char *);

short  LeoMedidores(ClsMedidor *);
void   InicializaMedidor(ClsMedidor *);
short CargaEstadoSFC(ClsMedidor *);
short	GenerarPlano(FILE *, ClsModif, ClsMedidor, char *);

short LeoCamTit(ClsCamTit *, ClsMedidor *);
void InicializaCamTit(ClsCamTit *);
short GenerarPlanoCT(FILE *, ClsCamTit, ClsMedidor, char *);

short getLecturaFecha(ClsModif *, char *, char *);
short getLecturaCT(ClsCamTit *, char *);

char 	*strReplace(char *, char *, char *);
char	*getEmplazaSAP(char*);
char	*getEmplazaT23(char*);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
