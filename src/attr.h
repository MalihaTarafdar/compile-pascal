#ifndef ATTR_H
#define ATTR_H

typedef union
{
        int num;
        char *str;
} tokentype;

typedef struct
{
        int targetRegister;
} regInfo;

#endif
