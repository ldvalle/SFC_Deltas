$ifndef SFCASSET2_H;
$define SFCASSET2_H;

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
	long 	numero_cliente;
	double	potencia_inst_fp;
	char	tipo_suministro[51];
	char	tipo_cliente[51];
	char	desc_tarifa[51];
	char	voltaje[51];
	char	clave_montri[2];
}ClsCliente;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  	CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );

short	LeoCliente( ClsCliente *);
void 	InicializaCliente(ClsCliente *);

short	GenerarPlanoAsset(ClsCliente);
short	GenerarPlanoCtasCto(ClsCliente);

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
