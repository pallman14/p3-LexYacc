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

struct BreakStack {
    int locations[100];
    int count;
} breakStack;

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
/*Precedence 14*/
%right AA XA OA
%right RA LA
%right TA DA MA
%right PA NA
%right '='

/* Precedence 12 */
%left OR

/* Precedence 11 */
%left AN

/* Precedence 10 */
%left '|'

/* Precedence 9 */
%left '^'

/* Precedence 8 */ 
%left '&'

/* Precedence 7 */
%left EQ NE

/* Precedence 6 */
%left '<' LE  '>' GE

/* Precedence 5 */
%left LS RS

/* Precedence 4 */
%right '+' '-'

/* Precedence 3 */
%left '*' '/' '%'

/* Precedence 2 */
%right '!' '~'

/* Precedence 1 */
%left AR
%left '.'
%left PP NN

/* Declare attribute types for marker nonterminals, such as L M and N */
/* Added P to implement for loop */
%type <loc> L M N P

%%

stmts   : stmts stmt
        | /* empty */
        ;

stmt    : ';'
        | expr ';'      { emit(pop); /* do not leave a value on the stack */ }
        | IF '(' expr ')' M stmt
                        { // Backpatch the location stored in M to jump to the stmt if the condition is true
                        backpatch($5, pc - $5); }

        | IF '(' expr ')' M stmt  ELSE  N L stmt L 
                        { // Backpatch to the 'else' stmt if the condition is false
                        backpatch($5, $9 - $5);
                        // Backpatch to the end after the 'else' statement
                        backpatch($8, $11 - $8); }

        | WHILE '(' L expr ')' M stmt N
                        { // Backpatch the conditional jump location M to execute the stmt if the condition is true
                        backpatch($6, pc - $6);
                        // Unconditional jump to reevaluate the condition
                        backpatch($8, $3 - $8);
                        // Backpatch to exit the loop if the condition is false
                        // backpatch($8, pc - $8); 
                        for (int i = 0; i < breakStack.count; i++) {
                                backpatch(breakStack.locations[i], pc - breakStack.locations[i]);
                        }
                        breakStack.count = 0;
                        }

        | DO L stmt WHILE '(' expr ')' M N L';'
                        { // Backpatch the conditional jump M to go to the beginning of DO
                        backpatch($8, $10 - $8);
                        // Backpatch to ensure the loop exits if the condition is false
                        backpatch($9, $2 - $9);
                        for (int i = 0; i < breakStack.count; i++) {
                                backpatch(breakStack.locations[i], pc - breakStack.locations[i]);
                        }
                        breakStack.count = 0;
                        }
        | FOR '(' expr  P ';' L expr M N ';' L expr P N ')' L stmt N
                        { // Backpatch the condition check to jump to the stmt if true
                        backpatch($8, pc - $8);
                        // Jump to the increment step
                        backpatch($9, $16 - $9);                      
                        // Ensure that after the increment, we recheck the condition
                        backpatch($14, $6 - $14);
                        // Backpatch to return to the condition after the stmt
                        backpatch($18, $11 - $18);
                        for (int i = 0; i < breakStack.count; i++) {
                                backpatch(breakStack.locations[i], pc - breakStack.locations[i]);
                        }
                        breakStack.count = 0;
                        }

        | RETURN expr ';'
                        { emit(istore_2); /* return val goes in local var 2 */ }
        | BREAK ';'
                        { {
                                // Emit a goto instruction for the break
                                emit3(goto_, 0);

                                // Save the location for later backpatching
                                breakStack.locations[breakStack.count++] = pc - 1;
                                if (breakStack.count >= 100) {
                                        error("Break stack overflow");
                                }
                        } }
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

        // expr == expr: Compare if two expressions are equal, if true push 1, otherwise skip to the next instruction.
        | expr EQ expr { 
                                // Save the current pc position to backpatch later
                                int a = pc;

                                // Emit an instruction to compare the two expressions (if_icmpeq). 
                                // If they are equal, it will jump to the next instruction (emitting 1).
                                emit3(if_icmpeq, 0);  
                                
                                // If the expressions are not equal, we need to push a 0 to indicate inequality
                                emit(iconst_0);  
                                
                                // Save the current pc again, so we can backpatch it later if the comparison fails
                                int b = pc;
                                
                                // Emit a 'goto' instruction to skip over the 1 that will be emitted later.
                                // This prevents executing the part where 1 is emitted if the comparison was true.
                                emit3(goto_, 0);
                                
                                // Backpatch the instruction at position 'a' (the original comparison).
                                // Update it to jump to the current pc (the location after we emit 1).
                                backpatch(a, pc - a);
                                
                                // Emit 1 to indicate equality if the comparison was true
                                emit(iconst_1);
                                
                                // Backpatch the goto instruction at position 'b' to ensure it jumps over the 1 if needed
                                backpatch(b, pc - b);

		        }

        // Comparison of two expressions for inequality (!=)                
        | expr NE  expr 
        		{ 
				// Save the current pc to be used for backpatching
                                int a = pc;
                                
                                // Emit an instruction to compare if the values are not equal (if_icmpne). 
                                // If they are not equal, jump to the instruction to emit 1.
                                emit3(if_icmpne, 0);  
                                
                                // Emit 0 if the values are equal
                                emit(iconst_0);  
                                
                                // Save the current pc position to backpatch the 'goto' instruction later
                                int b = pc;
                                
                                // Emit 'goto' to skip over the part where 1 will be emitted, 
                                // which is only needed if the comparison is true (i.e., values are not equal).
                                emit3(goto_, 0);
                                
                                // Backpatch the comparison instruction at position 'a' to jump to the pc after emitting 1
                                backpatch(a, pc - a);
                                
                                // Emit 1 to indicate that the values were not equal (this happens if the comparison was true)
                                emit(iconst_1);
                                
                                // Backpatch the goto at position 'b' so it skips the emitting of 1 if the comparison was false
                                backpatch(b, pc - b);
			}

        // Comparison for Less than (>)
        | expr '<' expr 
        		{ 
				// Save the current pc for backpatching
                                int a = pc;
                                
                                // Emit a comparison instruction (if_icmplt) to check if the left value is less than the right.
                                // If true, jump to the instruction to emit 1.
                                emit3(if_icmplt, 0);  
                                
                                // Emit 0 if the left value is not less than the right value
                                emit(iconst_0);  
                                
                                // Save the current pc position to backpatch the 'goto' instruction later
                                int b = pc;
                                
                                // Emit 'goto' to skip the emission of 1 if the left value is not less than the right
                                emit3(goto_, 0);
                                
                                // Backpatch the comparison instruction to jump to the code after emitting 1
                                backpatch(a, pc - a);
                                
                                // Emit 1 to indicate the left value is less than the right value (this happens if the comparison is true)
                                emit(iconst_1);
                                
                                // Backpatch the goto instruction to ensure it skips the emission of 1 if the comparison was false
                                backpatch(b, pc - b);
			}

        // Comparison for greater than (>)
        | expr '>' expr 
        		{ 
				// Save the current pc to use later for backpatching
                                int a = pc;
                                
                                // Emit an instruction (if_icmpgt) to compare if the left value is greater than the right value
                                // If true, it will jump to the next instruction that will emit 1.
                                emit3(if_icmpgt, 0);  
                                
                                // Emit 0 if the left value is not greater than the right value
                                emit(iconst_0);  
                                
                                // Save the current pc position so it can be backpatched later
                                int b = pc;
                                
                                // Emit goto to skip over the 1 emission if the comparison fails 
                                emit3(goto_, 0);
                                
                                // Backpatch the comparison instruction at position 'a' to jump to the code after 1
                                backpatch(a, pc - a);
                                
                                // Emit 1 to indicate the left value is greater than the right (if the comparison was true)
                                emit(iconst_1);
                                
                                // Backpatch the goto to skip emitting 1 if the comparison fails
                                backpatch(b, pc - b);
                        }

        // Comparison for less than or equal to (<=)
        | expr LE expr 
                        { 
                                // Save the current pc for backpatching
                                int a = pc;
                                
                                // Emit the instruction (if_icmple) to compare if the left value is less than or equal to the right
                                // If true, jump to emit 1
                                emit3(if_icmple, 0);  
                                
                                // Emit 0 if the comparison fails 
                                emit(iconst_0);  
                                
                                // Save the pc for backpatching the goto instruction
                                int b = pc;
                                
                                // Emit goto to skip over the 1 emission if the comparison fails
                                emit3(goto_, 0);
                                
                                // Backpatch the comparison at position 'a' to jump to after emitting 1 if comparison is true
                                backpatch(a, pc - a);
                                
                                // Emit 1 to indicate left <= right if the comparison was true
                                emit(iconst_1);
                                
                                // Backpatch the 'goto' at position 'b' to skip over the 1 if comparison was false
                                backpatch(b, pc - b);
                        }

        // Comparison for greater than or equal to (>=)
        | expr GE expr 
                        { 
                                // Save the current pc for backpatching
                                int a = pc;
                                
                                // Emit the instruction (if_icmpge) to check if the left value is greater than or equal to the right value
                                // If true, jump to the instruction that emits 1
                                emit3(if_icmpge, 0);  
                                
                                // Emit 0 if the comparison is false 
                                emit(iconst_0);  
                                
                                // Save the current pc to backpatch the 'goto' instruction
                                int b = pc;
                                
                                // Emit a goto to skip over the 1 emission if the comparison fails
                                emit3(goto_, 0);
                                
                                // Backpatch the comparison instruction at position 'a' to jump to after emitting 1
                                backpatch(a, pc - a);
                                
                                // Emit 1 to indicate the left value is greater than or equal to the right (if comparison is true)
                                emit(iconst_1);
                                
                                // Backpatch the goto at position 'b' to skip over the 1 if comparison fails
                                backpatch(b, pc - b);
                        }

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

        // Logical NOT operation: Negate the value of the expression, add 1 to flip the result.
        | '!' expr { emit(ineg); emit(iconst_1); emit(iadd); }
        // Bitwise NOT operation: Negate the value and add 1 to get the bitwise complement.
        | '~' expr { emit(ineg); emit(iconst_1); emit(iadd); }
        // '+' at the same precedence level as '!' 
        | '+' expr %prec '!' {  // Unary '+' does nothing, so leave empty to ignore this case.
        }
        // '-' at the same precedence level as '!' 
        | '-' expr %prec '!' { 
                 // Unary minus: Negate the value of the expression.
                emit(ineg); 
        }
        | '(' expr ')' { 
        // Expression enclosed in parentheses: Do nothing special, just evaluate the inner expression.
        }
        | '$' INT8 { 
                // Load value from an array stored in the first local variable, indexed by the given INT8.
                emit(aload_1); 
                emit2(bipush, $2); 
                emit(iaload); 
        }
        | PP ID { 
                // Pre-increment: Increment the value of ID by 1, duplicate the result, and store it back in ID.
                emit(iconst_1); 
                emit2(iload, $2->localvar); 
                emit(iadd); 
                emit(dup); 
                emit2(istore, $2->localvar); 
        }
        | NN ID { 
                // Pre-decrement: Load the value of ID, subtract 1, duplicate the result, and store it back in ID.
                emit2(iload, $2->localvar); 
                emit(iconst_1); 
                emit(isub); 
                emit(dup); 
                emit2(istore, $2->localvar); 
        }
        | ID PP { 
                // Post-increment: Load the value of ID, duplicate it, increment by 1, and store the result back in ID.
                emit2(iload, $1->localvar); 
                emit(dup); 
                emit(iconst_1); 
                emit(iadd); 
                emit2(istore, $1->localvar); 
        }
        | ID NN { 
                // Post-decrement: Load the value of ID, duplicate it, subtract 1, and store the result back in ID.
                emit2(iload, $1->localvar); 
                emit(dup); 
                emit(iconst_1); 
                emit(isub); 
                emit2(istore, $1->localvar); 
        }
        | ID { 
                // Simple variable reference: Load the value of ID onto the stack.
                emit2(iload, $1->localvar); 
        }
        | INT8 { 
                // Load an 8-bit integer constant onto the stack.
                emit2(bipush, $1); 
        }
        | INT16 { 
                // Load a 16-bit integer constant onto the stack.
                emit3(sipush, $1); 
        }
        | INT32 { 
                // Load a 32-bit integer constant onto the stack using the constant pool.
                emit2(ldc, constant_pool_add_Integer(&cf, $1)); 
        }
        | FLT { 
                // Floating-point constants are not supported in this project.
                error("float constant not supported in Pr3"); 
        }
        | STR { 
                // String constants are not supported in this project.
                error("string constant not supported in Pr3"); 
        }
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

P       : /* empty */   { emit(pop);	/* location of inst. to backpatch */ } 

%%

int main(int argc, char **argv)
{
	int index1, index2, index3;
	int label1, label2;
        breakStack.count = 0;

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



