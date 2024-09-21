#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "instrutil.h"

struct node
{
	char *name;
	int offset;
	int length; // if length == -1, not array
	struct node *next_node;
};

struct stack_node
{
	int label;
	struct stack_node *next_node;
	struct stack_node *prev_node;
};

struct node *head = NULL, *tail = NULL, *array_start;
struct stack_node *stack = NULL;

int add_new_var(char *name, int length)
{
	struct node *new_node = (struct node *)malloc(sizeof(struct node));
	new_node->name = (char *)malloc(strlen(name) + 1);
	memcpy(new_node->name, name, strlen(name) + 1);
	new_node->offset = NextOffset();
	new_node->length = length;
	new_node->next_node = NULL;
	if (head == NULL)
	{
		head = new_node;
	}
	else
	{
		tail->next_node = new_node;
	}
	tail = new_node;
	return new_node->offset;
}

int find_offset(char *name)
{
	struct node *temp = head;
	while (temp != NULL)
	{
		if (strcmp(temp->name, name) == 0)
			return temp->offset;
		temp = temp->next_node;
	}
	return -8;
}

void clean()
{
	struct node *temp = head, *temp2 = head->next_node;
	while (temp != NULL)
	{
		free(temp->name);
		free(temp);
		temp = temp2;
		if (temp2 != NULL)
		{
			temp2 = temp->next_node;
		}
	}
}

void mark()
{
	array_start = tail;
}

void demark(int length)
{
	while (array_start != NULL)
	{
		array_start->length = length;
		array_start = array_start->next_node;
	}
}

void malloc_arrays()
{
	struct node *temp = head;
	int offset = NextOffset();
	while (temp != NULL)
	{
		// if length not 0, assign space for array
		if (temp->length != 0)
		{
			int newReg = NextRegister();
			emit(NOLABEL, LOADI, offset, newReg, EMPTY);
			emit(NOLABEL, STOREAI, newReg, 0, temp->offset);
			offset = offset + 4 * (temp->length + 1);
		}
		temp = temp->next_node;
	}
}

void stack_push(int label)
{
	struct stack_node *new_node = (struct stack_node *)malloc(sizeof(struct stack_node));
	new_node->label = label;
	new_node->next_node = NULL;
	new_node->prev_node = NULL;
	if (stack == NULL)
	{
		stack = new_node;
	}
	else
	{
		new_node->prev_node = stack;
		stack->next_node = new_node;
		stack = new_node;
	}
}

int stack_pop()
{
	if (stack == NULL)
	{
		return -1;
	}
	struct stack_node *temp = stack;
	int label = temp->label;
	stack = stack->prev_node;
	free(temp);
	return label;
}
