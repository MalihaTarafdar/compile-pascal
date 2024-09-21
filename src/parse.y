%{
#include <stdio.h>
#include "attr.h"
#include "instrutil.h"
int yylex();
void yyerror(char * s);
#include "symtab.h"

FILE *outfile;
char *CommentBuffer;
 
%}

%union {tokentype token;
		regInfo targetReg;
		}

%token PROG PERIOD VAR 
%token INT BOOL ARRAY RANGE OF WRITELN THEN IF 
%token BEG END ASG DO FOR
%token EQ NEQ LT LEQ 
%token AND OR XOR NOT TRUE FALSE 
%token ELSE
%token WHILE
%token <token> ID ICONST 

%type <targetReg> exp lvalue condexp
%type <token> bconst
%type <targetReg> fastmt flvalue fexp fstmtlist flstmt

%start program

%nonassoc EQ NEQ LT LEQ 
%left '+' '-' 
%left '*'
%left AND OR XOR NOT

%nonassoc THEN
%nonassoc ELSE

%%
program: {
			emitComment("Assign STATIC_AREA_ADDRESS to register \"r0\"");
			emit(NOLABEL, LOADI, STATIC_AREA_ADDRESS, 0, EMPTY);
		}
	PROG ID ';' block PERIOD { emitComment("PROG ID ';' block PERIOD"); }
	;

block: variables cmpdstmt {
			emitComment("block: variables cmpdstmt");
		}
	;

variables: /* empty */
	| VAR vardcls {
			emitComment("variables: VAR vardcls");
			malloc_arrays();
		}
	;

vardcls: vardcls vardcl ';' { emitComment("vardcls: vardcls vardcl"); }
	| vardcl ';' { emitComment("vardcls: vardcl"); }
	| error ';' { yyerror("***Error: illegal variable declaration\n"); }
	;

vardcl: idlist ':' INT { emitComment("vardcl: idlist ':' INT"); }
	| idlist ':' BOOL { emitComment("vardcl: idlist ':' BOOL"); }
	| idlist ':' ARRAY '[' ICONST RANGE ICONST ']' OF INT {
			emitComment("vardcl: idlist ':' ARRAY '[' ICONST RANGE ICONST ']' OF INT");
			demark($7.num);
		}
	| idlist ':' ARRAY '[' ICONST RANGE ICONST ']' OF BOOL {
			emitComment("vardcl: idlist ':' ARRAY '[' ICONST RANGE ICONST ']' OF BOOL");
			demark($7.num);
		}
	;

idlist: idlist ',' ID {
			emitComment("idlist: idlist ',' ID");
			add_new_var($3.str, 0);
		}
	| ID {
			emitComment("idlist: ID");
			add_new_var($1.str, 0);
			mark();
		}
	;

stmtlist: stmtlist ';' stmt { emitComment("stmtlist: stmtlist ';' stmt"); }
	| stmt { emitComment("stmtlist: stmt"); }
	| error { yyerror("***Error: illegal statement \n"); }
	;

stmt: ifstmt { emitComment("stmt: ifstmt"); }
	| wstmt { emitComment("stmt: wstmt"); }
	| fstmt { emitComment("stmt: fstmt"); }
	| astmt { emitComment("stmt: astmt"); }
	| writestmt { emitComment("stmt: writestmt"); }
	| cmpdstmt { emitComment("stmt: cmpdstmt"); }
	;

cmpdstmt: BEG stmtlist END { emitComment("cmpdstmt: BEG stmtlist END"); }
	;

ifstmt: ifhead THEN stmt {
			emitComment("ifstmt: ifhead THEN stmt");
			int label_exit = stack_pop();
			emit(label_exit, NOP, EMPTY, EMPTY, EMPTY);
		} 
	| ifhead THEN stmt ELSE {
			emitComment("ifstmt: ifhead THEN stmt ELSE");
			int label_exit = NextLabel();
			int label2 = stack_pop();
			stack_push(label_exit);
			emit(NOLABEL, BR, label_exit, EMPTY, EMPTY);
			emit(label2, NOP, EMPTY, EMPTY, EMPTY);
		}
	stmt {
			emitComment("ifstmt: stmt");
			int label_exit = stack_pop();
			emit(label_exit, NOP, EMPTY, EMPTY, EMPTY);
		}
	;

ifhead: IF condexp {
			emitComment("ifhead: IF condexp");
			int label1 = NextLabel();
			int label2 = NextLabel();
			emit(NOLABEL, CBR, $2.targetRegister, label1, label2);
			emit(label1, NOP, EMPTY, EMPTY, EMPTY);
			stack_push(label2);
		}
	;

writestmt: WRITELN '(' exp ')' {
			emitComment("writestmt: WRITELN '(' exp ')'");
			emit(NOLABEL, STOREAI, $3.targetRegister, 0, -4);
			emit(NOLABEL, OUTPUT, 1020, EMPTY, EMPTY);
		}
	;

wstmt: WHILE condexp DO stmt { emitComment("wstmt: WHILE condexp DO stmt"); }
	;

fstmt: FOR ID ASG ICONST ',' ICONST DO fastmt {
			emitComment("fstmt: FOR ID ASG ICONST ',' ICONST DO astmt");

			// labels
			int label_header = stack_pop();
			int label_init = stack_pop();
			int label_body = stack_pop();

			// jump
			emitComment("==========JUMP FOR LOOP HEADER==========");
			emit(NOLABEL, BR, label_header, EMPTY, EMPTY);

			// initialize
			emitComment("==========FOR LOOP INIT==========");
			emit(label_init, NOP, EMPTY, EMPTY, EMPTY);
			int reg_counter = NextRegister();
			emit(NOLABEL, LOADI, $4.num, reg_counter, EMPTY);
			emit(NOLABEL, STOREAI, reg_counter, 0, find_offset($2.str));
			int reg_end = NextRegister();
			emit(NOLABEL, LOADI, $6.num, reg_end, EMPTY);

			// decrement loop counter initially
			int reg_step = NextRegister();
			emit(NOLABEL, LOADI, 1, reg_step, EMPTY);
			emit(NOLABEL, SUB, reg_counter, reg_step, reg_counter);
			emit(NOLABEL, STOREAI, reg_counter, 0, find_offset($2.str));

			// increment loop counter
			emitComment("==========FOR LOOP HEADER==========");
			emit(label_header, NOP, EMPTY, EMPTY, EMPTY);
			emit(NOLABEL, ADD, reg_counter, reg_step, reg_counter);
			emit(NOLABEL, STOREAI, reg_counter, 0, find_offset($2.str));

			// loop test, jump
			int reg_test = NextRegister();
			emit(NOLABEL, CMPLT, reg_end, reg_counter, reg_test);
			int label_exit = NextLabel();
			emit(NOLABEL, CBR, reg_test, label_exit, label_body);

			// exit
			emitComment("==========FOR LOOP EXIT==========");
			emit(label_exit, NOP, EMPTY, EMPTY, EMPTY);
		}
	| FOR ID ASG ICONST ',' ICONST DO BEG fstmtlist END {
			emitComment("fstmt: FOR ID ASG ICONST ',' ICONST DO BEG fstmtlist END ';'");

			// labels
			int label_header = stack_pop();
			int label_init = stack_pop();
			int label_body = stack_pop();

			// jump
			emitComment("==========JUMP FOR LOOP HEADER==========");
			emit(NOLABEL, BR, label_header, EMPTY, EMPTY);

			// initialize
			emitComment("==========FOR LOOP INIT==========");
			emit(label_init, NOP, EMPTY, EMPTY, EMPTY);
			int reg_counter = NextRegister();
			emit(NOLABEL, LOADI, $4.num, reg_counter, EMPTY);
			emit(NOLABEL, STOREAI, reg_counter, 0, find_offset($2.str));
			int reg_end = NextRegister();
			emit(NOLABEL, LOADI, $6.num, reg_end, EMPTY);

			// decrement loop counter initially
			int reg_step = NextRegister();
			emit(NOLABEL, LOADI, 1, reg_step, EMPTY);
			emit(NOLABEL, SUB, reg_counter, reg_step, reg_counter);
			emit(NOLABEL, STOREAI, reg_counter, 0, find_offset($2.str));

			// increment loop counter
			emitComment("==========FOR LOOP HEADER==========");
			emit(label_header, NOP, EMPTY, EMPTY, EMPTY);
			emit(NOLABEL, ADD, reg_counter, reg_step, reg_counter);
			emit(NOLABEL, STOREAI, reg_counter, 0, find_offset($2.str));

			// loop test, jump
			int reg_test = NextRegister();
			emit(NOLABEL, CMPLT, reg_end, reg_counter, reg_test);
			int label_exit = NextLabel();
			emit(NOLABEL, CBR, reg_test, label_exit, label_body);

			// exit
			emitComment("==========FOR LOOP EXIT==========");
			emit(label_exit, NOP, EMPTY, EMPTY, EMPTY);
		}
	;

fstmtlist: fstmtlist ';' stmt { emitComment("fstmtlist: fstmtlist ';' stmt"); }
	| flstmt { emitComment("fstmtlist: flstmt"); }
	| error { yyerror("***Error: illegal statement \n"); }
	;

flstmt: flvalue ASG exp {
			emitComment("fstmt: flvalue ASG exp");
			emit(NOLABEL, STORE, $3.targetRegister, $1.targetRegister, EMPTY);
		}
	| WRITELN '(' fexp ')' {
			emitComment("fstmt: WRITELN '(' fexp ')'");
			emit(NOLABEL, STOREAI, $3.targetRegister, 0, -4);
			emit(NOLABEL, OUTPUT, 1020, EMPTY, EMPTY);
		}
	;

fastmt: flvalue ASG exp {
			emitComment("fastmt: flvalue ASG exp");
			emit(NOLABEL, STORE, $3.targetRegister, $1.targetRegister, EMPTY);
		}
	| WRITELN '(' fexp ')' {
			emitComment("fastmt: WRITELN '(' fexp ')'");
			emit(NOLABEL, STOREAI, $3.targetRegister, 0, -4);
			emit(NOLABEL, OUTPUT, 1020, EMPTY, EMPTY);
		}
	;

flvalue: ID {
			emitComment("flvalue: ID");
			// labels
			int label_body = NextLabel();
			int label_init = NextLabel();
			int label_header = NextLabel();
			stack_push(label_body);
			stack_push(label_init);
			stack_push(label_header);
			emitComment("==========JUMP FOR LOOP INIT==========");
			emit(NOLABEL, BR, label_init, EMPTY, EMPTY);
			emitComment("==========FOR LOOP BODY==========");
			emit(label_body, NOP, EMPTY, EMPTY, EMPTY);

			int reg_offset = NextRegister();
			emit(NOLABEL, LOADI, find_offset($1.str), reg_offset, EMPTY);
			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, ADD, 0, reg_offset, reg);
		}
	|  ID '[' fexp ']' { 
			emitComment("flvalue: ID '[' fexp ']'");
			int reg4 = NextRegister();
			emit(NOLABEL, LOADI, 4, reg4, EMPTY);
			int reg = NextRegister();
			int reg_offset = NextRegister();
			emit(NOLABEL, MULT, $3.targetRegister, reg4, reg_offset);
			int reg2 = NextRegister();
			$$.targetRegister = reg2;
			emit(NOLABEL, LOADAI, 0, find_offset($1.str), reg);
			emit(NOLABEL, ADD, reg, reg_offset, reg2);
		}
	;

fexp: '(' fexp ')' {
			emitComment("fexp: '(' fexp ')'");
			$$.targetRegister = $2.targetRegister;
		}
	| fexp '+' exp {
			emitComment("fexp: fexp '+' exp");
			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, ADD, $1.targetRegister, $3.targetRegister, reg);
		}
	| fexp '-' exp {
			emitComment("fexp: fexp '-' exp");
			int reg = NextRegister(); 
			$$.targetRegister = reg;
			emit(NOLABEL, SUB, $1.targetRegister, $3.targetRegister, reg);
		}
	| fexp '*' exp {
			emitComment("fexp: fexp '*' exp");
			int reg = NextRegister(); 
			$$.targetRegister = reg;
			emit(NOLABEL, MULT, $1.targetRegister, $3.targetRegister, reg);
		}
	| fexp AND exp {
			emitComment("fexp: fexp AND exp");
			int reg = NextRegister(); 
			$$.targetRegister = reg;
			emit(NOLABEL, L_AND, $1.targetRegister, $3.targetRegister, reg);
		}
	| fexp OR exp {
			emitComment("fexp: fexp OR exp");
			int reg = NextRegister(); 
			$$.targetRegister = reg;
			emit(NOLABEL, L_OR, $1.targetRegister, $3.targetRegister, reg);
		}
	| fexp XOR exp {
			emitComment("fexp: fexp XOR exp");
			int reg = NextRegister(); 
			$$.targetRegister = reg;
			emit(NOLABEL, L_XOR, $1.targetRegister, $3.targetRegister, reg);
		}
	| NOT fexp {
			emitComment("fexp: NOT fexp");
			int reg = NextRegister(); 
			$$.targetRegister = reg;
			int reg2 = NextRegister();
			emit(NOLABEL, LOADI, 0, reg2, EMPTY);
			emit(NOLABEL, CMPEQ, $2.targetRegister, reg2, reg);
		}
	| ID {
			emitComment("fexp: ID");
			// labels
			int label_body = NextLabel();
			int label_init = NextLabel();
			int label_header = NextLabel();
			stack_push(label_body);
			stack_push(label_init);
			stack_push(label_header);
			emitComment("==========JUMP FOR LOOP INIT==========");
			emit(NOLABEL, BR, label_init, EMPTY, EMPTY);
			emitComment("==========FOR LOOP BODY==========");
			emit(label_body, NOP, EMPTY, EMPTY, EMPTY);

			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, LOADAI, 0, find_offset($1.str), reg);
		}
	| ID '[' fexp ']' {
			emitComment("fexp: ID '[' fexp ']'");
			int reg4 = NextRegister();
			emit(NOLABEL, LOADI, 4, reg4, EMPTY);
			int reg_offset = NextRegister();
			emit(NOLABEL, MULT, $3.targetRegister, reg4, reg_offset);
			int reg = NextRegister();
			int reg2 = NextRegister();
			$$.targetRegister = reg2;
			emit(NOLABEL, LOADAI, 0, find_offset($1.str), reg);
			emit(NOLABEL, LOADAO, reg, reg_offset, reg2);
		}
	| ICONST {
			emitComment("fexp: ICONST");
			// labels
			int label_body = NextLabel();
			int label_init = NextLabel();
			int label_header = NextLabel();
			stack_push(label_body);
			stack_push(label_init);
			stack_push(label_header);
			emitComment("==========JUMP FOR LOOP INIT==========");
			emit(NOLABEL, BR, label_init, EMPTY, EMPTY);
			emitComment("==========FOR LOOP BODY==========");
			emit(label_body, NOP, EMPTY, EMPTY, EMPTY);

			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, LOADI, $1.num, reg, EMPTY);
		}
	| bconst {
			emitComment("fexp: bconst");
			// labels
			int label_body = NextLabel();
			int label_init = NextLabel();
			int label_header = NextLabel();
			stack_push(label_body);
			stack_push(label_init);
			stack_push(label_header);
			emitComment("==========JUMP FOR LOOP INIT==========");
			emit(NOLABEL, BR, label_init, EMPTY, EMPTY);
			emitComment("==========FOR LOOP BODY==========");
			emit(label_body, NOP, EMPTY, EMPTY, EMPTY);

			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, LOADI, $1.num, reg, EMPTY);
		}
	| error { yyerror("***Error: illegal expression\n"); }
	;

astmt: lvalue ASG exp {
			emitComment("astmt: lvalue ASG exp");
			emit(NOLABEL, STORE, $3.targetRegister, $1.targetRegister, EMPTY);
		}
	;

lvalue: ID {
			emitComment("lvalue: ID");
			int reg_offset = NextRegister();
			emit(NOLABEL, LOADI, find_offset($1.str), reg_offset, EMPTY);
			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, ADD, 0, reg_offset, reg);
		}
	|  ID '[' exp ']' { 
			emitComment("lvalue: ID '[' exp ']'");
			int reg4 = NextRegister();
			emit(NOLABEL, LOADI, 4, reg4, EMPTY);
			int reg = NextRegister();
			int reg_offset = NextRegister();
			emit(NOLABEL, MULT, $3.targetRegister, reg4, reg_offset);
			int reg2 = NextRegister();
			$$.targetRegister = reg2;
			emit(NOLABEL, LOADAI, 0, find_offset($1.str), reg);
			emit(NOLABEL, ADD, reg, reg_offset, reg2);
		}
	;

exp: '(' exp ')' {
			emitComment("exp: '(' exp ')'");
			$$.targetRegister = $2.targetRegister;
		}
	| exp '+' exp {
			emitComment("exp: exp '+' exp");
			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, ADD, $1.targetRegister, $3.targetRegister, reg);
		}
	| exp '-' exp {
			emitComment("exp: exp '-' exp");
			int reg = NextRegister(); 
			$$.targetRegister = reg;
			emit(NOLABEL, SUB, $1.targetRegister, $3.targetRegister, reg);
		}
	| exp '*' exp {
			emitComment("exp: exp '*' exp");
			int reg = NextRegister(); 
			$$.targetRegister = reg;
			emit(NOLABEL, MULT, $1.targetRegister, $3.targetRegister, reg);
		}
	| exp AND exp {
			emitComment("exp: exp AND exp");
			int reg = NextRegister(); 
			$$.targetRegister = reg;
			emit(NOLABEL, L_AND, $1.targetRegister, $3.targetRegister, reg);
		}
	| exp OR exp {
			emitComment("exp: exp OR exp");
			int reg = NextRegister(); 
			$$.targetRegister = reg;
			emit(NOLABEL, L_OR, $1.targetRegister, $3.targetRegister, reg);
		}
	| exp XOR exp {
			emitComment("exp: exp XOR exp");
			int reg = NextRegister(); 
			$$.targetRegister = reg;
			emit(NOLABEL, L_XOR, $1.targetRegister, $3.targetRegister, reg);
		}
	| NOT exp {
			emitComment("exp: NOT exp");
			int reg = NextRegister(); 
			$$.targetRegister = reg;
			int reg2 = NextRegister();
			emit(NOLABEL, LOADI, 0, reg2, EMPTY);
			emit(NOLABEL, CMPEQ, $2.targetRegister, reg2, reg);
		}
	| ID {
			emitComment("exp: ID");
			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, LOADAI, 0, find_offset($1.str), reg);
		}
	| ID '[' exp ']' {
			emitComment("exp: ID '[' exp ']'");
			int reg4 = NextRegister();
			emit(NOLABEL, LOADI, 4, reg4, EMPTY);
			int reg_offset = NextRegister();
			emit(NOLABEL, MULT, $3.targetRegister, reg4, reg_offset);
			int reg = NextRegister();
			int reg2 = NextRegister();
			$$.targetRegister = reg2;
			emit(NOLABEL, LOADAI, 0, find_offset($1.str), reg);
			emit(NOLABEL, LOADAO, reg, reg_offset, reg2);
		}
	| ICONST {
			emitComment("exp: ICONST");
			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, LOADI, $1.num, reg, EMPTY);
		}
	| bconst {
			emitComment("exp: bconst");
			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, LOADI, $1.num, reg, EMPTY);
		}
	| error { yyerror("***Error: illegal expression\n"); }
	;

bconst: TRUE {
			emitComment("bconst: TRUE");
			$$.num = 1;
		}
	| FALSE {
			emitComment("bconst: FALSE");
			$$.num = 0;
		}
	;

condexp: exp NEQ exp {
			emitComment("condexp: exp NEQ exp");
			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, CMPNE, $1.targetRegister, $3.targetRegister, reg);
		}
	| exp EQ exp {
			emitComment("condexp: exp EQ exp");
			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, CMPEQ, $1.targetRegister, $3.targetRegister, reg);
		}
	| exp LT exp {
			emitComment("condexp: exp LT exp");
			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, CMPLT, $1.targetRegister, $3.targetRegister, reg);
		}
	| exp LEQ exp {
			emitComment("condexp: exp LEQ exp");
			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, CMPLE, $1.targetRegister, $3.targetRegister, reg);
		}
	| exp {
			emitComment("condexp: exp");
			$$.targetRegister = $1.targetRegister;
		}
	| ID {
			emitComment("condexp: ID");
			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, LOADAI, 0, find_offset($1.str), reg);
		}
	| bconst {
			emitComment("condexp: bconst");
			int reg = NextRegister();
			$$.targetRegister = reg;
			emit(NOLABEL, LOADI, $1.num, reg, EMPTY);
		}
	| error { yyerror("***Error: illegal conditional expression\n"); }
	;

%%

void yyerror(char* s) {
	fprintf(stderr,"%s\n",s);
	fflush(stderr);
}

int main() {
	printf("\n          CS415 Project 2: Code Generator\n\n");

	outfile = fopen("iloc.out", "w");
	if (outfile == NULL) { 
		printf("ERROR: cannot open output file \"iloc.out\".\n");
		return -1;
	}

	CommentBuffer = (char *) malloc(500);  

	printf("1\t");
	yyparse();
	printf("\n");

	//   /*** START: THIS IS BOGUS AND NEEDS TO BE REMOVED ***/    

	//   emitComment("LOTS MORE BOGUS CODE");
	//   emit(1, NOP, EMPTY, EMPTY, EMPTY);
	//   emit(NOLABEL, LOADI, 12, 1, EMPTY);
	//   emit(NOLABEL, LOADI, 1024, 2, EMPTY);
	//   emit(NOLABEL, STORE, 1, 2, EMPTY);
	//   emit(NOLABEL, OUTPUT, 1024, EMPTY, EMPTY);
	//   emit(NOLABEL, LOADI, -5, 3, EMPTY);
	//   emit(NOLABEL, CMPLT, 1, 3, 4);
	//   emit(NOLABEL, STORE, 4, 2, EMPTY);
	//   emit(NOLABEL, OUTPUT, 1024, EMPTY, EMPTY);
	//   emit(NOLABEL, CBR, 4, 1, 2);
	//   emit(2, NOP, EMPTY, EMPTY, EMPTY);

	//   /*** END: THIS IS BOGUS AND NEEDS TO BE REMOVED ***/    

	fclose(outfile);

	return 1;
}




