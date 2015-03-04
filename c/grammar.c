/* Based on https://github.com/jeffreykegler/libmarpa/blob/master/test/json/json.c
 * Here is the copyright notice from that file:
 * Copyright 2015 Jeffrey Kegler
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#include <stdio.h>
#include "marpa.h"

#include "grammar.h"

int
fail (const char *s, Marpa_Grammar g)
{
  Marpa_Error_Code errcode = marpa_g_error (g, NULL);
  printf ("%s returned %d: %s", s, errcode);
  exit (1);
}

/* From RFC 7159 */
Marpa_Symbol_ID S_begin_array;
Marpa_Symbol_ID S_begin_object;
Marpa_Symbol_ID S_end_array;
Marpa_Symbol_ID S_end_object;
Marpa_Symbol_ID S_name_separator;
Marpa_Symbol_ID S_value_separator;
Marpa_Symbol_ID S_member;
Marpa_Symbol_ID S_value;
Marpa_Symbol_ID S_false;
Marpa_Symbol_ID S_null;
Marpa_Symbol_ID S_true;
Marpa_Symbol_ID S_object;
Marpa_Symbol_ID S_array;
Marpa_Symbol_ID S_number;
Marpa_Symbol_ID S_string;

/* Additional */
Marpa_Symbol_ID S_object_contents;
Marpa_Symbol_ID S_array_contents;

/* For fatal error messages */
char error_buffer[80];

/* Names follow RFC 7159 as much as possible */
char *
symbol_name (Marpa_Symbol_ID id)
{
  if (id == S_begin_array)
    return "begin_array";
  if (id == S_begin_object)
    return "begin_object";
  if (id == S_end_array)
    return "end_array";
  if (id == S_end_object)
    return "end_object";
  if (id == S_name_separator)
    return "name_separator";
  if (id == S_value_separator)
    return "value_separator";
  if (id == S_member)
    return "member";
  if (id == S_value)
    return "value";
  if (id == S_false)
    return "false";
  if (id == S_null)
    return "null";
  if (id == S_true)
    return "true";
  if (id == S_object)
    return "object";
  if (id == S_array)
    return "array";
  if (id == S_number)
    return "number";
  if (id == S_string)
    return "string";
  if (id == S_object_contents)
    return "object_contents";
  if (id == S_array_contents)
    return "array_contents";
  sprintf (error_buffer, "no such symbol: %d", id);
  return error_buffer;
};

static Marpa_Grammar
grammar_new()
{
  Marpa_Config marpa_configuration;

  Marpa_Grammar g;
  /* Longest rule is 4 symbols */
  Marpa_Symbol_ID rhs[4];

  marpa_c_init (&marpa_configuration);
  g = marpa_g_new (&marpa_configuration);
  if (!g)
    {
      Marpa_Error_Code errcode =
        marpa_c_error (&marpa_configuration, NULL);
      printf ("marpa_g_new returned %d: %s", errcode);
      exit (1);
    }

  ((S_begin_array = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_begin_object = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_end_array = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_end_object = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_name_separator = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_value_separator = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_member = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_value = marpa_g_symbol_new (g)) >= 0) || fail ("marpa_g_symbol_new", g);
  ((S_false = marpa_g_symbol_new (g)) >= 0) || fail ("marpa_g_symbol_new", g);
  ((S_null = marpa_g_symbol_new (g)) >= 0) || fail ("marpa_g_symbol_new", g);
  ((S_true = marpa_g_symbol_new (g)) >= 0) || fail ("marpa_g_symbol_new", g);
  ((S_object = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_array = marpa_g_symbol_new (g)) >= 0) || fail ("marpa_g_symbol_new", g);
  ((S_number = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_string = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_object_contents = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);
  ((S_array_contents = marpa_g_symbol_new (g)) >= 0)
    || fail ("marpa_g_symbol_new", g);

  rhs[0] = S_false;
  (marpa_g_rule_new (g, S_value, rhs, 1) >= 0)
    || fail ("marpa_g_rule_new", g);
  rhs[0] = S_null;
  (marpa_g_rule_new (g, S_value, rhs, 1) >= 0)
    || fail ("marpa_g_rule_new", g);
  rhs[0] = S_true;
  (marpa_g_rule_new (g, S_value, rhs, 1) >= 0)
    || fail ("marpa_g_rule_new", g);
  rhs[0] = S_object;
  (marpa_g_rule_new (g, S_value, rhs, 1) >= 0)
    || fail ("marpa_g_rule_new", g);
  rhs[0] = S_array;
  (marpa_g_rule_new (g, S_value, rhs, 1) >= 0)
    || fail ("marpa_g_rule_new", g);
  rhs[0] = S_number;
  (marpa_g_rule_new (g, S_value, rhs, 1) >= 0)
    || fail ("marpa_g_rule_new", g);
  rhs[0] = S_string;
  (marpa_g_rule_new (g, S_value, rhs, 1) >= 0)
    || fail ("marpa_g_rule_new", g);

  rhs[0] = S_begin_array;
  rhs[1] = S_array_contents;
  rhs[2] = S_end_array;
  (marpa_g_rule_new (g, S_array, rhs, 3) >= 0)
    || fail ("marpa_g_rule_new", g);

  rhs[0] = S_begin_object;
  rhs[1] = S_object_contents;
  rhs[2] = S_end_object;
  (marpa_g_rule_new (g, S_object, rhs, 3) >= 0)
    || fail ("marpa_g_rule_new", g);

  (marpa_g_sequence_new
   (g, S_array_contents, S_value, S_value_separator, 0,
    MARPA_PROPER_SEPARATION) >= 0) || fail ("marpa_g_sequence_new", g);
  (marpa_g_sequence_new
   (g, S_object_contents, S_member, S_value_separator, 0,
    MARPA_PROPER_SEPARATION) >= 0) || fail ("marpa_g_sequence_new", g);

  rhs[0] = S_string;
  rhs[1] = S_name_separator;
  rhs[2] = S_value;
  (marpa_g_rule_new (g, S_member, rhs, 3) >= 0)
    || fail ("marpa_g_rule_new", g);

  (marpa_g_start_symbol_set (g, S_value) >= 0)
    || fail ("marpa_g_start_symbol_set", g);
  if (marpa_g_precompute (g) < 0)
    {
      fail("marpa_g_precompute", g);
    }

  return g;
}

void *check_ptr(void *ptr)
{
  if (ptr == NULL)
  {
    fprintf(stderr, "Out of memory.");
    exit(1);
  }
  return ptr;
}

Marpa_SG_Rule *
marpa_sg_rule_new_func(char* lhs, ...)
{
  int ix;
  char *symbol;
  Marpa_SG_Rule *rule;

  va_list args;
  va_start(args, lhs);

  fprintf(stderr, "%s ", lhs);

  rule = check_ptr( malloc(sizeof(Marpa_SG_Rule)) );

  rule->symbols = check_ptr( malloc(sizeof(char *)) );
  rule->symbols[0] = lhs;

  for (ix = 1; ix < 1000; ix++)
  {
    symbol = va_arg(args, char *);
    if (symbol == NULL)
      break;

    rule->symbols = check_ptr( realloc( rule->symbols, ( ix + 1 ) * sizeof(char *)) );
    rule->symbols[ix] = symbol;

    fprintf(stderr, "%s ", symbol);
  }
  fprintf(stderr, "\n");
  va_end(args);

  rule->length = ix;

  return rule;
}

int
marpa_sg_rule_free(Marpa_SG_Rule *rule)
{
  free(rule->symbols);
}

int marpa_sg_rule_is_sequence(Marpa_SG_Rule *rule)
{
  return ( rule->length == 4
       && ( ( strcmp(rule->symbols[3], "0") == 0 )
            || ( strcmp(rule->symbols[3], "1") ) == 0 ) );
}

Marpa_Symbol_ID
marpa_sg_symbol_id(Marpa_SG_Grammar *sg, const char *name)
{
  int i;
  for (i = 0; i < sg->symbol_table_length; i++)
  {
    if (strcmp(sg->st[i].name, name) == 0)
    {
      return i;
    }
  }
  return -1;
}

char *
marpa_sg_symbol(Marpa_SG_Grammar *sg, Marpa_Symbol_ID S_id)
{
  int i;
  for (i = 0; i < sg->symbol_table_length; i++)
  {
    if (sg->st[i].id == S_id)
    {
      return sg->st[i].name;
    }
  }
  return NULL;
}

Marpa_Symbol_ID
marpa_sg_symbol_new(Marpa_SG_Grammar *sg, char *name)
{
  Marpa_Symbol_ID S_id = marpa_sg_symbol_id(sg, name);
  if (S_id < 0)
  {
    ((S_id = marpa_g_symbol_new(sg->g)) >= 0) || fail ("marpa_g_symbol_new", sg->g);
    sg->symbol_table_length++;
    if (sg->symbol_table_length == 1)
    {
      sg->st = check_ptr(malloc(sg->symbol_table_length * sizeof(Marpa_SG_Symbol_Table_Entry)));
    }
    else
    {
      sg->st = check_ptr(realloc(sg->st, sg->symbol_table_length * sizeof(Marpa_SG_Symbol_Table_Entry)));
    }
    sg->st[sg->symbol_table_length - 1].name = name;
  }
  return S_id;
}

Marpa_SG_Grammar *
marpa_sg_new(Marpa_SG_Rule *rules[], int count)
{
  int rule_ix;

  Marpa_Config marpa_configuration;
  Marpa_Grammar g;

  Marpa_SG_Grammar *sg = check_ptr(malloc(sizeof(Marpa_SG_Grammar)));
  sg->symbol_table_length = 0;

  marpa_c_init (&marpa_configuration);
  g = marpa_g_new (&marpa_configuration);
  if (!g)
    {
      Marpa_Error_Code errcode =
        marpa_c_error (&marpa_configuration, NULL);
      printf ("marpa_g_new returned %d: %s", errcode);
      exit (1);
    }
  sg->g = g;

  for (rule_ix = 0; rule_ix < count; rule_ix++)
  {
    Marpa_SG_Rule *rule = rules[rule_ix];
    int rule_is_sequence = marpa_sg_rule_is_sequence (rule);
    int symbol_count = rule_is_sequence ? rule->length - 1 : rule->length;
    int symbol_ix;
    for (symbol_ix = 0; symbol_ix < symbol_count; symbol_ix++)
    {
      marpa_sg_symbol_new(sg, rule->symbols[symbol_ix]);
    }

    if ( rule_is_sequence )
    {
      fprintf(stderr, "Sequence ");
    }
    else
    {

    }
    fprintf(stderr, "Rule %d of %d, %d symbols:\n", rule_ix, count, rules[rule_ix]->length );
  }
  sg->g = grammar_new();
  return sg;
}

int
marpa_sg_free(Marpa_SG_Grammar *sg)
{
  free(sg->st);
  free(sg);
}

int
marpa_sg_rules_free(Marpa_SG_Rule *rules[], int count)
{
  int rule_ix;
  for (rule_ix = 0; rule_ix < count; rule_ix++){
    marpa_sg_rule_free (rules[rule_ix]);
  }
  return 0;
}
