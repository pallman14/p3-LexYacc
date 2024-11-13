/*
Price, Chris, Gorana, Lian
Program: p3
File:symbol.c
*/

#include "global.h"
#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>

#define SYMMAX 1024      // Max symbols

/* Define the symbol table */
struct entry {
    char *lexptr;
    int token;
};

struct Symbol symtable[SYMMAX];
int varIndex;
int lastEntry = 0;

Symbol *lookup(const char *s) {
    Symbol *rc = NULL;
    // Loop through the table
    for (int i = 0; i < lastEntry; i++) {
        // Compare *s to table entry
        if (strcmp(symtable[i].lexptr, s) == 0) {
            rc = &symtable[i];
            break;
        }
    }
    return rc;
}

Symbol *insert(const char *s, int token) {
    if (lastEntry + 1 == SYMMAX) {
        error("symbol table full");
    }
    // Store token and duplicated string
    symtable[lastEntry].token = token;
    symtable[lastEntry].lexptr = strdup(s);  // Ensure string is copied
    lastEntry++;
    
    return &symtable[lastEntry - 1]; // Return pointer to the new entry
}
