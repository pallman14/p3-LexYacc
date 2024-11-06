/* 
Price, Chris, Lian, Gorana
File: mycc.y
Program: P3
GCSC 554
*/

%{

#include "lex.yy.h"
#include "global.h"
static struct ClassFile cf;

%}

/* declares YYSTYPE type of attribute for all tokens and nonterminals */
%union
{ Symbol *sym;  /* token value yylval.sym is the symbol table entry of an ID */
  unsigned num; /* token value yylval.num is the value of an int constant */
  float flt;    /* token value yylval.flt is the value of a float constant */
  char *str;    /* token value yylval.str is the value of a string constant */
  unsigned loc; /* location of instruction to backpatch */
}

/* Declare ID token and its attribute type 'sym' */
%token <sym> ID

/* Declare INT tokens (8 bit, 16 bit, 32 bit) and their attribute type 'num' */
%token <num> INT8 INT16 INT32

/* Declare FLT token (not used in this assignment) */
%token <flt> FLT

/* Declare STR token (not used in this assignment) */
%token <str> STR

/* Declare tokens for keywords */
/* Note: install_id() returns Symbol* for both keywords and identifiers */
%token <sym> BREAK DO ELSE FOR IF RETURN WHILE

/* Declare operator tokens with associativity and precedence */
//1st Precedence 
%left PP      //Postfix increment '++'
%left NN      //Postfix decrement '--'
%left '.'     //Dot Operator - Left to right
   
//2nd Precedence
%right '!'     //Logical not
%right '~'     //Bitwise complement

//3rd Precedence
%left '*'       //Multiplication
%left '/'       //Division
%left '%'       //Modulus

//4th Precedence
%right '+'      //Addition 
%right '-'      //Subtraction

//5th Precedence
%left LS      //Left Shift '<<'
%left RS      //Right Shift '>>'

//6th Precedence
%left LE      //Less than or equal to '<='
%left GE      //Greater than or equal to '>='
%left '<'      //Relational less than 
%left '>'      //Relational greater than 

//7th Precedence
%left EQ        //Equal to '=='
%left NE        //Not equal to '!='

//8th Precedence
%left '&'       //Bitwise AND  

//9th Precedence
%left '^'       //Bitwise exclusive OR

//10th Precedence
%left '|'       //Bitwise inclusive OR

//11th Precedence
%left AN      //Logical AND '&&'

//12th Precedence
%left OR      //Logical OR '||'

//14th Precedence
%right RA       //Right Shift Assignment '>>='
%right LA       //Left Shift Assignment '<<='
%right PA       //Plus Assignment '+='
%right NA       //Minus Assignment '-='
%right TA       //Times Assignment '*='
%right DA       //Divide Assignment '/='
%right MA       //Modulo Assignment '%='
%right AA       //AND Assignment '&='
%right XA       //XOR Assignment '^='
%right OA       //OR Assignment '|='
%right AR       //Assignment '='

/* Declare attribute types for marker nonterminals, such as L M and N */
/* Added O */
%type <loc> L M N O

%%

stmts   : stmts stmt
        | /* empty */
        ;

stmt    : ';'
        | expr ';'      { emit(pop); /* do not leave a value on the stack */ }
        | IF '(' expr ')' M stmt
                        { // Backpatch the location stored in M to jump to the stmt if the condition is true
                        backpatch($5, pc - $5); }

        | IF '(' expr ')' M stmt ELSE N L stmt L
                        { // Backpatch to the 'else' stmt if the condition is false
                        backpatch($5, $9 - $5);
                        // Backpatch to the end after the 'else' statement
                        backpatch($8, $11 - $8); }

        | WHILE '(' L expr ')' M stmt N
                        { // Backpatch the conditional jump location M to execute the stmt if the condition is true
                        backpatch($6, pc - $6);
                        // Unconditional jump to reevaluate the condition
                        backpatch($8, $3 - $8);
                        }

        | DO L stmt WHILE '(' expr ')' M N L ';'
                        { // Backpatch the conditional jump M to go to the beginning of DO
                        backpatch($8, $10 - $8);
                        // Backpatch to ensure the loop exits if the condition is false
                        backpatch($9, $2 - $9);
                        }
        | FOR '(' expr O ';' L expr M N ';' L expr O N ')' L stmt N
                        { // Backpatch the condition check to jump to the stmt if true 
                        backpatch($8, pc - $8);
                        // Jump to the increment step 
                        backpatch($9, $16 - $9);
                        // Ensure that after the increment, we recheck the condition 
                        backpatch($14, $6 - $14);
                        // Backpatch to return to the condition after the stmt 
                        backpatch($18, $11 - $18);
                        }

        | RETURN expr ';'
                        { emit(istore_2); /* return val goes in local var 2 */ }
        | BREAK ';'
                        { /* TODO: BONUS!!! */ error("break not implemented"); }
        | '{' stmts '}'
        | error ';'     { yyerrok; }
        ;

expr    : ID   '=' expr { emit(dup); emit2(istore, $1->localvar); }
        // ID += expr: Load the current value of ID, add expr, and store the result back into ID
        | ID   PA  expr { emit2(iload , $1->localvar); emit(iadd); emit(dup); emit2(istore, $1->localvar); }
        // ID -= expr: Load the current value of ID, subtract expr, and store the result back into ID
        | ID   NA  expr { emit2(iload , $1->localvar); emit(swap); emit(isub); emit(dup); emit2(istore, $1->localvar); }
        // ID *= expr: Load the current value of ID, multiply by expr, and store the result back into ID
        | ID   TA  expr { emit2(iload , $1->localvar); emit(imul); emit(dup); emit2(istore, $1->localvar); }
        // ID /= expr: Load the current value of ID, divide by expr, and store the result back into ID
        | ID   DA  expr { emit2(iload , $1->localvar); emit(swap); emit(idiv); emit(dup); emit2(istore, $1->localvar); }
        // ID %= expr: Load the current value of ID, calculate the remainder with expr, and store the result back into ID
        | ID   MA  expr { emit2(iload , $1->localvar); emit(swap); emit(irem); emit(dup); emit2(istore, $1->localvar); }
        // ID &= expr: Perform bitwise AND on ID and expr, store the result back into ID
        | ID   AA  expr { emit2(iload , $1->localvar); emit(iand); emit(dup); emit2(istore, $1->localvar); }
        // ID ^= expr: Perform bitwise XOR on ID and expr, store the result back into ID
        | ID   XA  expr { emit2(iload , $1->localvar); emit(ixor); emit(dup); emit2(istore, $1->localvar); }
        // ID |= expr: Perform bitwise OR on ID and expr, store the result back into ID
        | ID   OA  expr { emit2(iload , $1->localvar); emit(ior); emit(dup); emit2(istore, $1->localvar); }
        // ID <<= expr: Perform bitwise left shift on ID by expr, store the result back into ID
        | ID   LA  expr { emit2(iload , $1->localvar); emit(swap); emit(ishl); emit(dup); emit2(istore, $1->localvar); }
        // ID >>= expr: Perform bitwise right shift on ID by expr, store the result back into ID
        | ID   RA  expr { emit2(iload , $1->localvar); emit(swap); emit(ishr); emit(dup); emit2(istore, $1->localvar); }
        // Perform bitwise OR on expr 
        | expr OR  expr { emit(ior); }
        // Perform bitwise AND on expr 
        | expr AN  expr { emit(iand); }
        // Perform bitwise OR on expr 
        | expr '|' expr { emit(ior); }
        // Perform bitwise XOR on expr 
        | expr '^' expr { emit(ixor); }
        // Perform bitwise AND on expr 
        | expr '&' expr { emit(iand); }

        | expr EQ  expr { /* TODO: TO BE COMPLETED */ error("== operator not implemented"); }
        | expr NE  expr { /* TODO: TO BE COMPLETED */ error("!= operator not implemented"); }
        | expr '<' expr { /* TODO: TO BE COMPLETED */ error("< operator not implemented"); }
        | expr '>' expr { /* TODO: TO BE COMPLETED */ error("> operator not implemented"); }
        | expr LE  expr { /* TODO: TO BE COMPLETED */ error("<= operator not implemented"); }
        | expr GE  expr { /* TODO: TO BE COMPLETED */ error(">= operator not implemented"); }
        
        // Perform left shift operation
        | expr LS expr { emit(ishl); } // Emit bytecode for left shift operation (<<)
        /* Perform right shift operation */
        | expr RS expr { emit(ishr); }  // Emit bytecode for right shift operation (>>)
        /* Perform addition */
        | expr '+' expr { emit(iadd); } // Emit bytecode for integer addition
        /* Perform subtraction */
        | expr '-' expr { emit(isub); } // Emit bytecode for integer subtraction
        /* Perform multiplication */
        | expr '*' expr { emit(imul); } // Emit bytecode for integer multiplication
        /* Perform division */
        | expr '/' expr { emit(idiv); } // Emit bytecode for integer division
        /* Perform modulus operation */
        | expr '%' expr { emit(irem); } // Emit bytecode for integer remainder (modulus)

        | '!' expr      { /* TODO: TO BE COMPLETED */ error("! operator not implemented"); }
        | '~' expr      { /* TODO: TO BE COMPLETED */ error("~ operator not implemented"); }
        | '+' expr %prec '!' /* '+' at same precedence level as '!' */
                        { /* TODO: TO BE COMPLETED */ error("unary + operator not implemented"); }
        | '-' expr %prec '!' /* '-' at same precedence level as '!' */
                        { /* TODO: TO BE COMPLETED */ error("unary - operator not implemented"); }
        | '(' expr ')'
        | '$' INT8      { emit(aload_1); emit2(bipush, $2); emit(iaload); }
        | PP ID         { /* TODO: TO BE COMPLETED */ error("pre ++ operator not implemented"); }
        | NN ID         { /* TODO: TO BE COMPLETED */ error("pre -- operator not implemented"); }
        | ID PP         { /* TODO: TO BE COMPLETED */ error("post ++ operator not implemented"); }
        | ID NN         { /* TODO: TO BE COMPLETED */ error("post -- operator not implemented"); }
        | ID            { emit2(iload, $1->localvar); }
        | INT8          { emit2(bipush, $1); }
        | INT16         { emit3(sipush, $1); }
        | INT32         { emit2(ldc, constant_pool_add_Integer(&cf, $1)); }
	| FLT		{ error("float constant not supported in Pr3"); }
	| STR		{ error("string constant not supported in Pr3"); }
        ;

L       : /* empty */   { $$ = pc; }
        ;

M       : /* empty */   { $$ = pc;	/* location of inst. to backpatch */
			  emit3(ifeq, 0);
			}
        ;

N       : /* empty */   { $$ = pc;	/* location of inst. to backpatch */
			  emit3(goto_, 0);
			}
        ;

O       : /* empty */   { $$ = pc;	/* location of inst. to backpatch */
			  emit3(goto_, 0);
		        } 

%%

int main(int argc, char **argv)
{
	int index1, index2, index3;
	int label1, label2;

	// set up new class file structure
	init_ClassFile(&cf);

	// class has public access
	cf.access = ACC_PUBLIC;

	// class name is "Code"
	cf.name = "Code";

	// no fields
	cf.field_count = 0;

	// one method
	cf.method_count = 1;

	// allocate array of methods (just one "main" in our example)
	cf.methods = (struct MethodInfo*)malloc(cf.method_count * sizeof(struct MethodInfo));

	if (!cf.methods)
		error("Out of memory");

	// method has public access and is static
	cf.methods[0].access = (enum access_flags)(ACC_PUBLIC | ACC_STATIC);

	// method name is "main"
	cf.methods[0].name = "main";

	// method descriptor of "void main(String[] arg)"
	cf.methods[0].descriptor = "([Ljava/lang/String;)V";

	// max operand stack size of this method
	cf.methods[0].max_stack = 100;

	// the number of local variables in the local variable array
	//   local variable 0 contains "arg"
	//   local variable 1 contains "val"
	//   local variable 2 contains "i" and "result"
	cf.methods[0].max_locals = 100;

	// set up new bytecode buffer
	init_code();
	
	// generate prologue code

/*LOC*/ /*CODE*/			/*SOURCE*/
/*000*/	emit(aload_0);
/*001*/	emit(arraylength);		// arg.length
/*002*/	emit2(newarray, T_INT);
/*004*/	emit(astore_1);			// val = new int[arg.length]
/*005*/	emit(iconst_0);
/*006*/	emit(istore_2);			// i = 0
	label1 = pc;			// label1:
/*007*/	emit(iload_2);
/*008*/	emit(aload_0);
/*009*/	emit(arraylength);
	label2 = pc;
/*010*/	emit3(if_icmpge, PAD);		// if i >= arg.length then goto label2
/*013*/	emit(aload_1);
/*014*/	emit(iload_2);
/*015*/	emit(aload_0);
/*016*/	emit(iload_2);
/*017*/	emit(aaload);			// push arg[i] parameter for parseInt
	index1 = constant_pool_add_Methodref(&cf, "java/lang/Integer", "parseInt", "(Ljava/lang/String;)I");
/*018*/	emit3(invokestatic, index1);	// invoke Integer.parseInt(arg[i])
/*021*/	emit(iastore);			// val[i] = Integer.parseInt(arg[i])
/*022*/	emit32(iinc, 2, 1);		// i++
/*025*/	emit3(goto_, label1 - pc);	// goto label1
	backpatch(label2, pc - label2);	// label2:

	// end of prologue code

	init();

	if (argc > 1)
		if (!(yyin = fopen(argv[1], "r")))
			error("Cannot open file for reading");

	if (yyparse() || errnum > 0)
		error("Compilation errors: class file not saved");

	fprintf(stderr, "Compilation successful: saving %s.class\n", cf.name);

	// generate epilogue code

	index2 = constant_pool_add_Fieldref(&cf, "java/lang/System", "out", "Ljava/io/PrintStream;");
/*036*/	emit3(getstatic, index2);	// get static field System.out of type PrintStream
/*039*/	emit(iload_2);			// push parameter for println()
	index3 = constant_pool_add_Methodref(&cf, "java/io/PrintStream", "println", "(I)V");
/*040*/	emit3(invokevirtual, index3);	// invoke System.out.println(result)
/*043*/	emit(return_);			// return

	// end of epilogue code

	// length of bytecode is in the emitter's pc variable
	cf.methods[0].code_length = pc;
	
	// must copy code to make it persistent
	cf.methods[0].code = copy_code();

	if (!cf.methods[0].code)
		error("Out of memory");

	// save class file to "Calc.class"
	save_classFile(&cf);

	return 0;
}

