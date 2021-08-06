$ifndef SFCOTS_H;
$define SFCOTS_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

/* Estructuras ---*/

$typedef struct{

	long 	nro_mensaje;
	char	nro_orden[17];
	char	sap_nro_ot[17];
	char	tipo_orden[4];
	char	tema[5];
	char	trabajo[7];
	char	sap_status[5];
	char	desc_status[31];
	char	ot_cod_motivo[6];
	char 	fecha_inicio[20];
	long	fecha_status;
	char	hora_status[9];
	long 	numero_cliente;
	char	fecha_evento_fmt[30];

	char	descri_motivo[51];
	char	sTexton[10240];
}ClsOT;

$typedef struct{
	int  	iPag;
	char	sTexto[101];
}ClsTexton;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void    CreaPrepare(void);
void    CreaPrepare2(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
short 	LeoOTS(ClsOT *);
void  	InicializaOT(ClsOT *);
short	LeoTexton(ClsTexton *);
void  	InicializaTexton(ClsTexton *);
short	GenerarPlano(FILE *, ClsOT);
static char	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);
static  char *strReplace2(char *, int, int);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
