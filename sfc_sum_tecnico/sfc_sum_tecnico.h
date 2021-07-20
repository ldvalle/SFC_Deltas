$ifndef SFCSUMTECNICO_H;
$define SFCSUMTECNICO_H;

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
   long  numero_cliente;
   char	 ruta_lectura[14];
   char	 nro_subestacion[7];
   char	 alimentador[12];
   char	 centro_trans[21];
   char	codigo_voltaje[2];
   char	tipo_conexion[7];
   char	acometida[2];
}ClsTecni;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  	CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );

short LeoSuministro(ClsTecni *);
void  InicializaTecni(ClsTecni *);

short	GenerarPlano(FILE *, ClsTecni);

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
