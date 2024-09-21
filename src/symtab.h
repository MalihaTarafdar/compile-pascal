#ifndef SYMTAB_H
#define SYMTAB_H

extern void mark();

extern void demark(int length);

extern int add_new_var(char *name, int length);

extern int find_offset(char *name);

extern void clean();

extern void malloc_arrays();

extern void stack_push(int label);

extern int stack_pop();

#endif
