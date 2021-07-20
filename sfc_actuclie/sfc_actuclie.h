$ifndef SFC_ACTUCLIE_H;
$define SFC_ACTUCLIE_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

#define SEPARADOR ";"

/* Estructuras **/
$typedef struct{
   long	numero_cliente;
   char  sFechaLarga[25];
   char  sFechaCorta[11];
}ClsBaja;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
void  CargaPeriodoAnalisis(int, char **, char *);
short ValidaFecha(char *);
short CargaContingente(void);


short	AbreArchivos(void);
void  CreaPrepareIni(void);
void  CreaPrepare(void);
char 	*FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );

short CargoContactos(void);


short LeoBajas(ClsBaja *);
void  InicializaBaja(ClsBaja *);
void  GeneraBaja(ClsBaja);
short RegistraCorrida(long);

char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);
int   instr(char *, char *);

$endif;
