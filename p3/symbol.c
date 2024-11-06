/* TODO: TO BE COMPLETED */

#include "global.h"
#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#define STRMAX 999      //Max character per STRING
#define SYMMAX 100      //Mas symbol

/* TODO: define a symbol table/array, reuse project Pr1 */
struct entry symtable[];
int varIndex;
int lastEntry = 0;

Symbol *lookup(const char *s)
{
        /* TODO: TO BE COMPLETED */
	Symobl *rc = NULL;
	//loop throught the table
	for (int i = 0; i < lastEntry; i++){
		// compare *s to table
		if(strcmp(symtable[i].lexptr, s) == 0){
			rc = &symtable[p]
			break;
		}
	}
	return rc;
}

Symbol *insert(const char *s, int token)
{
        /* TODO: TO BE COMPLETED */

	if (lastEntry +1 == SYMMAX){
		 error("symbol table full");
	}
	
	//put token into the symtable token of index lastEntry 
	symtable[lastEntry].token = token;
	//put the string into the symtable of index lastEntry
	symtable[lastEntry].lexptr = s;


	return NULL;
}
