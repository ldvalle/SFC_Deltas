$ifndef SFCCNR_H;
$define SFCCNR_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

/* --- Estructuras ---*/

$typedef struct{
   char  sucursal[5];
   long  nro_expediente;
   int   ano_expediente;
   char  fecha_deteccion[25];
   char  fecha_inicio[25]; 
   char  fecha_finalizacion[25]; 
   char  fecha_estado[25];
   long  numero_cliente;
   long  nro_solicitud;
   char  cod_estado[3];
   char  descripcion[51];
   char  tipo_expediente[4];
   char  anomalia[60];
   char  sucur_inspeccion[5];
   long  nro_inspeccion;
   char  sFechaDesdePeriCalcu[25];
   char  sFechaHastaPeriCalcu[25];
   double	total_calculo;

   long  numero_medidor;
   char  marca_medidor[4];
   char  modelo_medidor[3];
   
}ClsCnr;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );

short LeoCnr(ClsCnr *);
void  InicializaCnr(ClsCnr *);

short	GenerarPlano(FILE *, ClsCnr);

char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
