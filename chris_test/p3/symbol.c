/*
Price, Chris, Gorana, Lian
Program: p3
File:symbol.c
*/

#include "global.h"

#define STRMAX 999
#define SYMMAX 100

int charCnt = 0;

struct Symbol symtable[SYMMAX];
int lastEntry = 0;


Symbol *lookup(const char *s)
{
    int p;
    //set symbol pointer to null
	Symbol *rc = NULL;
	//for all items in symbol table 
	for (p = 0; p < lastEntry; p++) {
		//compare current symbols pointer to string passed
		if (strcmp(symtable[p].lexptr, s) == 0) {
			//set rc to get memory address of symbol
			rc = &symtable[p];
		}
	}
    return rc;	// Return a pointer to the found Symbol struct
}

Symbol *insert(const char *s, int tok)
{
    //make sure enough memory allocated 
	int lexLen = strlen(s) + 1;
	//if not enough room to add symbol
	if (lastEntry + 1 == SYMMAX) {
		error("Symbol table full");
		//if to many characters entered
	} else if (charCnt + lexLen >= STRMAX) {
		error("Too many ID characters");
	}
	//assign token to symbol table 
	symtable[lastEntry].token = tok;
	//point to memory for this location and allocate enough memory to store lexeme 
	symtable[lastEntry].lexptr = (char *)malloc(lexLen);
	strcpy((char *)symtable[lastEntry].lexptr, s);	// Copy lexeme over
	charCnt += lexLen; //increase char counter
	symtable[lastEntry].localvar = -1;		// Assume keywords; install_ID overrides it
	lastEntry++;
	return &symtable[lastEntry - 1];		// Return a pointer to the inserted ID
}
