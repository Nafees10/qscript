# Comments

Comments can be added using `//`:

```
// this is a comment
```

Multi line comments can be written by enclosing them in between `/*` and `*/`:

```
/*multiline
comment
*/
```

If the very first line in the file begins with a `#`, that line is ignored,
this is to make it possible to put a shebang on UNIX systems:

```
#!/usr/bin/qscript
```

---

# Functions

```
fn NAME (PARAM_TYPE PARAM_NAME, ...) -> RETURN_TYPE { BODY }
fn NAME (PARAM_TYPE PARAM_NAME, ...) -> EXPR;
```

## Anonymous Functions

See functions syntax above. A function is made anonymous by omitting the name.
Example:

```
fn (int i) -> i + 1;
```

## Returning From Functions

```
return RETURN_VALUE;
```

The `RETURN_VALUE` must be either of the return type, or must be implicitly
cast-able. For `void` return type, it can just be `return;`

## Function Calls

Function calls are made through the `()` operator like:

```
fnName(fnArg0, fnArg1, ...);
```

or in case of no arguments:

```
fnName();
```

The first argument to a function call can also be passed using the `.`
operator:

```
5.sum(5);
// is equivalent to:
sum(5, 5);
```

---

# Variables

Variables can be declared like:

```
var TYPE var0, var1, var2;
```

- `TYPE` is the data type of the variables
- `var0`, `var1`, `var2` are the names of the variables. Comma separated.

Value assignment can also be done in the variable declaration statement like:

```
var int var0 = 12, var1 = 24;
```

Variables are only available inside the scope they are declared in.

Variables can be assigned using the `=` operator:

```
variable = value;
```

---

# Data Types

- `int` - largest supported signed integer
- `float` - largest supported floating point number
- `char` - a unicode character
- `void` - incapable of storing any data, equivalent to `struct {}`
- `bool` - a `true` or `false`
- `X[]` - array of type `X`
- `X[Y]` - dictionary, with `X` as value type, and `Y` as key type.
- `string` - a unicode string
- `@X` - reference to any of the above
- `@fn (ARG_TYPES) -> RETURN_TYPE` - reference to a function

The data type can be followed by a `?` to indicate possible error value.

## `int`

Can be written as:

- Binary - `0B1100` or `0b1100` - for `12`
- Hexadecimal - `0xFF` - for `15`
- Series of `[0-9]+` digits

default value is `0`

## `float`

Digits with a single `.` between them is read as a float. `5` is an int, but
`5.0` is a float.

default value is `0.0`

## `char`

This is written by enclosing a single character within a pair of apostrophes:

`'c'` for example, or `'\t'` tab character.

default value is `\0`

## `bool`

A `true` (1) or a `false` (0).

While casting from `int`, a non zero value is read as a `true`, zero as `false`.

default value is `false`

## `@X` references

These are pointers to data. They are initialized to `null`.

```
var int num = 0;
var @int ref; // initialized to null 
var @int refAlt = @num; // pointing to num
ref = @num;
ref = 2; // assigns to num
```

To get reference to something, use the pre`@` operator: `@a`
To dereference a reference, use the post`@` operator: `a@`

## `auto` variables

The `auto` keyword can be used to infer types:

```
var auto x = something;
```

`auto` cannot be combined with the postfix `?` operator.

## `X[]`

An array type provides the following operations:

- Resize: `resize(@arr, newLength)`. Returns the new length (`int`).
- Get Length: `length(arr)`. Returns the length (`int`).
- Get Element: `arr[i]` for value, or `@arr[i]` for reference

`resize` and `length` can be used using the `.` syntax:

```
a.resize(newSize)
a.length()
```

## `X[Y]`

A dictionary that maps keys, of type `Y`, to values, of type `X`:

```
var string[int] i2s; /// maps integers to strings
```

Dictionaries provide the following functionality:

```
// add/overwrite value:
i2s[i] = s;

// existence check:
if is i2s[i] {
    // value exists
}

// get value:
var string? value = i2s[i]; // value, or error if doesn't exist

// remove key:
i2s.remove(i);
remove(i2s, i);

// get number of key-value pairs:
length(i2s); // returns int
i2s.length(); // same
```

## `string`

```
"this is a string"
```

The `\` backslash can be used to escape the following characters:

- `\"` - quotation mark `"`
- `\t` - tab
- `\n` - newline
- `\r` - carriage return
- `\b` - backspace
- `\\` - backslash `\`
- `\'` - apostrophe `'`
- `\0` - null character

The above representation does not allow for multi line strings, instead, use
the triple quotation marks syntax:

```
"""
string
here
"""
```

The string content starts at the line _after_ the opening `"""`, and ends at
the line before the `"""`:

```
"""
Hello
 World
"""
// is equivalent to:
"Hello\n World"
```

## Error values

Any type combined with a postfix `?` operator can alternatively store an error
inplace of the value. The prefix `is` operator can be used to check for error:

```
var int? v = f();
if is v {
    // v is not error
}
```

Applying the postfix `?` on a value expression which could error can be used to
short-circuit execution to conditional code to handle the error:

```
fn f () -> int?{...}
var int value = f() + 5 ? -1; // value will be -1 if f() errors
```

Use the postfix `!` operator to assert no error:

```
var int a = f();  // invalid. cannot cast int? to int
var int b = f()!; // valid
```

---

# Structs

```
struct STRUCT_NAME{
    DATA_TYPE NAME;
    DATA_TYPE NAME, NAME1;
    DATA_TYPE NAME = INIT_VALUE;
    DATA_TYPE NAME = INIT_VALUE, NAME1 = INIT_VALUE;
}
```

## Anonymous Structs

A struct can be created, and immediately used, without being given a type name:

```
struct { MEMBERS }
```

`struct { MEMBERS }` is treated as an expression, that evaluates to a
data type.

Example:

```
var struct{int x, y;} pos;
```

## Equivalence

Structs defined through the `struct NAME{...}` syntax are always unique:

```
struct Foo{ string a; int i; }
struct Bar{ string a; int i; }
var Foo foo;
var Bar bar;
foo = bar; // error, incompatible types
bar = foo; // error, incompatible types
```

Anonymous structs can be implicitly casted to any other struct type, as long
as the destination type is a superset of the source type.

```
struct Foo{ int i; string s; }
var Foo foo;

var struct{ int i; } a;
foo = a; // valid

var struct{ string s; } b;
foo = b; // valid

var struct{ string s; int i; } c;
foo = c; // valid

var struct{ string s; int i; float f; } d;
foo = d; // invalid
```

---

# Unions

Unions store one of the members at a time, along with a tag, indicating which
member is currently stored:

```
union Name{
    DATA_TYPE NAME;
    DATA_TYPE NAME = INIT_VALUE;
}
```

## Default Member

A union must be assigned a default member. The default member at
initialization can be denoted by assigning a default value to it. For example:

```
union Foo{
    struct{} bar = {}; // bar is default
    int baz;
}

union Num{
    int i;
    float f = 0; // f is default
}
```

## Reading tag

The binary `is` operator can be used to check if a union currently stores a
tag:

```
union Foo { string bar; int baz = 0; }
var Foo f;

if f is bar {
    // f contains bar
}
if f !is baz {
    // f does not contain baz
}
```

## Constructing Unions

Unions can be constructed from, and assigned values from anonymous struct
values:

```
union Foo{ int i; string s; }
var Foo foo = {i = 5};
foo = {s = "hello world"};
```

---

# Enums


```
enum NAME{
    MEMBER_0 [= val0],
    MEMBER_1 [= val1],
    MEMBER_2 [= val2],
}
```

Specifying the values is optional, if values are omitted, the compiler will
auto-generate incremental values from the largest specified value.

The first member is the default value.

```
enum Foo{ Bar, Baz }
var Foo f; // initialized to Foo.Bar
```

An enum's member's value can be read as: `EnumName.MemberName`, using the
member selector operator.

---

# `TYPE{...}` Expressions

Expressions written in as `DATA_TYPE { ... }` can be used to execute statements
that evaluate to a single value, of type `DATA_TYPE`:

```
5 + int{
        // some code
        return someInt;
    } + 10;
```

---

# Modules

External libraries can be imported as modules.

```
import math;
// symbols defined in math can now be used
```

Alternatively, `import` can be used with `as`:

```
import math as m
// symbols defined in math can be used as `m.X`
```

---

# If Statements

```
if CONDITION_EXPR
    STATEMENT_ON_TRUE
```

or:

```
if CONDITION_EXPR
    STATEMENT_ON_TRUE
else
    STATEMENT_ON_FALSE
```

---

# Loops

## While

```
while CONDITION_EXPR
    STATEMENT
```

## Do While

```
do 
    STATEMENT
while CONDITION_EXPR;
```

## For

// TODO

## Break & Continue

A `break;` statement can be used to exit a loop at any point, and a `continue;`
will jump to the end of current iteration.

---

# Switch Case

```
switch EXPRESSION
case EXPRESSION { ... }
case EXPRESSION { ... }
case _ { ... } // default
```

the switch expression is matched, whichever case expression it matches with,
that block is executed, every other case's block is skipped:

```
switch option
case "read" { line = readln; }
case "write" { line.writeln; }
case _ {}
```

A switch case is terminated by the default case, which is denoted by:

```
case _ {}
```

## Switching on Unions

The switch statement can be used on union tags. The switch expression should
evaluate to a value of union type, and case expressions should be member names:

```
var union { string s; int i; } foo = getFromSomeWhere;
switch foo
case s { foo.s.writeln; }
case i { foo.i.writeln; }
case _ {}
```

---

# Operators

Operators are read in this order (higher precedence to lower), comma separated:

- `- A`
- `A . B`
- `A [ B`
- `@ A`
- `A ( B`
- `A ?`, `A ++`, `A --`
- `A @`
- `~ A`, `is A`, `!is A`, `! A`
- `A * B`, `A / B`, `A % B`
- `A + B`, `A - B`
- `A << B`, `A >> B`
- `A & B`, `A | B`, `A ^ B`
- `A == B`, `A != B`, `A >= B`, `A <= B`, `A > B`, `A < B`, `A is B`, `A !is B`
- `A && B`, `A || B`
- `A = B`, `A += B`, `A -= B`, `A *= B`, `A /= B`, `A %= B`, `A &= B`,
    `A |= B`, `A ^= B`

All variations of the assignment operator that combine an arithmetic operator
`op` with `=` to make `op=` are translated from `A op= B;` into `A = A op B;`

---

# Explicit Type Casting

```
TYPE_NAME(VALUE)
// or
VALUE.TYPE_NAME
```

Above syntax can be used to convert between types.

## Source Type `int`

| Target Type | Actual Return Type |
|-------------|--------------------|
| `float`     | `float`            |
| `char`      | `char` truncated   |
| `bool`      | `bool`             |
| `string`    | `string`           |

## Source Type `float`

| Target Type | Actual Return Type |
|-------------|--------------------|
| `int`       | `int`              |
| `bool`      | `bool`             |
| `string`    | `string`           |

## Source Type `char`

| Target Type | Actual Return Type |
|-------------|--------------------|
| `int`       | `int`              |
| `string`    | `string`           |

## Source Type `bool`

| Target Type | Actual Return Type |
|-------------|--------------------|
| `int`       | `int`              |
| `string`    | `string`           |

## Source Type `string`

| Target Type | Actual Return Type |
|-------------|--------------------|
| `int`       | `int?`             |
| `float`     | `float?`           |
| `bool`      | `bool?`            |

## Source Type `struct A`

Where neither `A` or `B` are anonymous structs.

| Target Type | Actual Return Type |
|-------------|--------------------|
| `struct B`  | `struct B?`        |
| `string`    | `string`           |

When the source struct `A` is anonymous, and `B` is a superset, implicit casting
is possible, and return type is `B`.
