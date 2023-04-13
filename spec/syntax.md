# QScript Syntax

# Comments
Comments can be added using the `#` character. Anything following a `#` is
ignored by compiler as a comment.

For example:

```
# a comment
fn void main(){ # This is a comment
	# This also is a comment
}
```

Multi line comments can be written by enclosing them in between `/*` and `*/`
like: 

```
/*
this
is
a
multiline
comment
*/
```

---

# Importing libraries
Libraries can provide function and/or data types. Importing a library named
`math` and `stdio` would be done like:

```
import math, stdio;
```
Or:
```
import math;
import stdio;
```

---

# Visibility
QScript has these visibility specifiers:

* `private` - Only accessible from within script.
* `public` - Accessible from outside when this script is loaded as a library.

By default, all declarations are `private`.

These can be written right before any declaration like:

```
private fn void somePrivateFunction(int arg){
	# body of private function
}
public struct SomeStruct{
	var int someInt, someOtherInt;
}
```

Visiblity specifier can apply to:

* structs
* enums
* functions
* global variables

# Functions
QScript has first class functions. Functions can be assigned to a variable
(of appropriate type), or passed as an argument, they behave as normal
variables.

## Function Data Type
To create a variable that can store a function:

```
var fn RETURN_TYPE(arg0_type, arg1_type, ..) someFunc;
```

following this, the function can be called using the `(..)` operator:

```
someFunc(arg0, arg1);
```

## Function Definition
```
fn [ref] RETURN_TYPE FUNCTION_NAME(
		[ref] arg0_type arg0,
		[ref] arg1_type arg1){
	# function body
}
```

* `ref` (optional) will make it so parameters/return is passed by reference not
	value
* `RETURN_TYPE` is the return type of this function
* `FUNCTION_NAME` is the name of the function
* `arg0_type` is the type for first argument
* `arg0` is the "name" for first argument
* more arguments can be added, and are to be separated by a comma.

_Note that the `ref` part of return type is not a property of the function,
but rather a part of the return data type._
  
A function without any arguments would be defined like:
```
fn TYPE FUNCTION_NAME(){
	# function body
}
```

A function definition is similar to a const function variable:

```
fn int length(int[] arr){
	return arr.length;
}
# is the same as:
var const fn int(int[]) length = fn int(int[] arr){
	return arr.length;
}
```

## Anonymous Functions
Anonymous functions can be created using the `fn` keyword:
```
writeln(fn int(char[] str){
		return str.length;
	}("hello")); # prints 5
```

## Returning From Functions
A return statement can be used to return a value from the function. The type of
the return value, and the return type of the function must match.
A return statement is written as following:
```
return RETURN_VALUE;
```

where `RETURN_VALUE` is the value to return. As soon as this statement is
executed, the function execution quits, meaning that in the following code,
writeln will not be called.

```
fn int someFunction(){
	return 0;
	writeln("this won't be written"); # because return terminates the execution
}
```

In case of functions of type void, `return;` can be used to terminate execution,
like:

```
fn void main(){
	# ..
	return;
	# anything below wont be executed
}
```

## `this` Function
Each script can have 1 `this` function. It will be called before any other
function in the scipt is called i.e: the `this` function can be used to
initialize the script.

`this` function is defined like:
```
fn void this(){
	# code to be executed when script is loaded
	writeln(someGlobalVar); # prints 5
	someGlobalVar = 0;
}
var int someGlobalVar = 5; # global variables are initialized before this()
```

`this` function must not return any value.

`this` function's visibility does not matter, as it cannot be explicitly called.

## Function Calls
Function calls are made through the `()` operator like:
```
fnName(funcArg0, funcArg1, ...);
```
or in case of no arguments:
```
fnName();
```

The first argument to a function call can also be passed as:
```
fn square(int i){
	return i * i;
}
fn main(){
	writeln(square(5)); # is same as following
	writeln(5.square); # writes 25
	# () operator not needed in this case
}
```

### `()` Overloading
```
struct SomeStruct{
	var int i;
}
fn void opFnCall(SomeStruct strct, int a){
	writeln("SomeStruct() called with a = " ~ toString(a));
}
fn void main(){
	var SomeStruct s;
	s(5); # prints: SomeStruct() called with a = 5
}
```

Overloading `()` operator for `function` types is not allowed, as that would
break a lot of things.

---

# Data Types
QScript has these basic data types:
* `int` - a signed 32 or 64 bit integer (`ptrdiff_t` in DLang is used for this)
* `double` - a floating point (`double` in DLang)
* `char` - an 8 bit character
* `bool` - a `true` or `false` (Dlang `bool`)
* `ref X` - reference to any of the above (behaves the same as `X` alone would)
* `const X` - a constant, which must be initialised at time of declaration.

## `int`
This can be written as series (or just one) digit(s).

Can be written as:

* Binary - `0B1100` or `0b1100` - for `12`
* Hexadecimal - `0xFF` or `0XfF` - for `15`
* Series of `[0-9]+` digits

`int` is initialised as `0`.

## `double`
Digits with a single `.` between them is read as a double.
`5` is an int, but `5.0` is a double.

`double`s are initialised as `0.0`

## `char`
This is written by enclosing a single character within a pair of apostrophes:
`'c'` for example, or `'\t'` tab character.

initialised as ascii code `0`

## `bool`
A `true` (1) or a `false` (0).  
While casting from `int`, a non zero value is read as a `true`, zero as `false`.

initialised as `false`

## `ref` references
These are aliases to actual variables.
A `ref` must always be initialised to reference some variable:

```
int i = 0;
var ref int r = i; # r is now a reference of i
# r can now be used as if it's an int.
r = 1;
writeln(r); # 1
writeln(i); # 1
```

after initialising, a ref cannot be made to reference another variable.

## `const` variables
A variable created as a const cannot be modified. It can only be set during
declaration:

```
var const int i = 5; # valid
i = 6; # not allowed
i ++; # not allowed
writeln(toString(i)); # allowed
```

## Structs
These can be used to store multiple values of varying or same data types.

They are defined like:

```
struct STRUCT_NAME{
	var DATA_TYPE1 NAME1;
	var DATA_TYPE2 NAME2;
}
```

* `STRUCT_NAME` is the name of this struct. This must be unique within the
	script.
* `DATA_TYPE1` is the data type for the first value.
* `NAME1` is the name for the first value

Keep in mind that recursive dependency is not possible in structs. However you
can have an array of the same type inside the struct, as arrays are initialised
to length 0.

QScript does not allow functions as members of structs, only variables can be
members.

An example usage of a struct would be:  
```
public struct Position{
	var int x, y;
}
public fn Position getPosition(int x, int y){
	Position pos;
	pos.x = x;
	pos.y = y;
	return pos;
}
```

## Enums
Enum can be used to group together constants of the same base data type.

Enums are defined like:
```
enum int EnumName{
	member0 = 1,
	member1 = 3,
	member2 = 3, # same value multiple times is allowed
}
```

* `int` is the base data type
* `EnumName` is the name for this enum

Example:  
```
public enum int ErrorType{
	FileNotFound = 1,
	InvalidPath = 1 << 1, # constant expression is allowed
	PermissionDenied = 4
}
```

An enum's member's value can be read as: `EnumName.MemberName`, using the
member selector operator.

Enums do not become data types:
```
var ErrorType err; # WRONG
var int err = ErrorType.FileNotFound; # Valid
```

---

# Variables

## Variable Declaration
Variables can be declared like:
```
var TYPE var0, var1, var2;
```
* `TYPE` is the data type of the variables, it can be a `char`, `int`,
	`float`, `bool`, or an array of those types: `int[]`, or `int[][]`...
* `var0`, `var1`, `var2` are the names of the variables. There can be more/less
	than 3, and are to be separated by a comma.

Value assignment can also be done in the variable declaration statement like:
```
var int var0 = 12, var1 = 24;
```

## Variable Assignment

Variables can be assigned a value like:
```
VAR = VALUE;
```
the data type of `VAR` and `VALUE` must match, or be implicitle castable.
  
In case the `VAR` is an array, then it's individual elements can be modified:
```
VAR[ INDEX ] = VALUE;
```
* `VAR` is the name of the var/array
* `INDEX` , in case `VAR` is an array, is the index of the element to assign a
	value to
* `VALUE` is the value to assign

And in a case like this, `VAR[INDEX]` must have the same data type as `VALUE`.
  
In case you want to modify the whole array, it can be done like:
```
var char someChar = 'a';
var char[] someString;
someString = [someChar, 'b', 'c'] ; # you could've also done [someChar] ~ "bc"
```

## Variable Scope
Variables are only available inside the "scope" they are declared in. In the code below:  
```
var int someGlobalVar;
public fn void main(int count){
	var int i = 0;
	while (i < count){
		var int j;
		# some other code
		i = i + 1;
	}
}
```
Varible `i` and `count` are accessible throughout the function. Variable `j` is
accessible only inside the `while` block. Variable `someGlobalVar` is declared
outside any function, so it is available to all functions defined _inside_ the
script, as it is `private`.

---

# Shadowing
In case an identifier matches with a library, and with one defined in script,
the one declared in the script will be preferred.

---

# If Statements
If statements are written like:
```
if (CONDITION){
	# some code
}else{
	# some (other?) code
}
```
The `else` part is not required. If `CONDITION` is `false`, then, if the else
exists, it's executed, if `CONDITION` is `true`, then `# some code` is executed.
It is not necessary that the `# some code` or the `# some (other?) code` be in
a block. In case only one statement is to be executed, it can be written like:
```
if (CONDITION)
	# some code, single statement
else
	# some other code, single statement
```
Indentation is not necessary, it can be written like:
```
if (CONDITION)
# some code, single statement
else
# some other code, single statement
```

## Nested If Statements
If statements can also be nested inside other if statements, like:  
```
if (CONDITION)
	if (OTHER_CONDITION)
		writeln("OTHER_CONDITION and CONDITION were 1");
	else
		writeln("OTHER_CONDITION was 0, CONDITION was 1");
else
	writeln("CONDITION was 0");
```

---

# Loops

QScript curently has the following types of loops:

## While:

While loops are written like:
```
while (CONDITION){
	# some code in a loop
}
```
As long as `CONDITION` is `true`, `# some code in a loop` is executed. And just
like if statements, while loops can also be nested

## Do While:

Do while loops are writen like:
```
do{
    # some code in a loop
}while (CONDITION);
```
First the code is executed, then if the condition is `true`, it's executed
again.

## For:

```
for (INIT_STATEMENT; CONDITION; INCREMENT_STATEMENT){
    # some code in a loop
}
```
First, the `INIT_STATEMENT` is executed, right before starting the loop. This
is executed only once. Then if `CONDITION` is `true`, the loop body is
executed, then `INCREMENT_STATEMENT` is executed, this is repeated, until
condition is false.

Unlike other languages (like D), the `INIT_STATEMENT`, `CONDITION`, and
`INCREMENT_STATEMENT` all must be present.

## Break & Continue
A `break;` statement can be used to exit a loop at any point, and a `continue;`
will jump to the end of current iteration.

---

# Operators

Syntax for binary operators is: `A operator B`. The whitespace between operator
and A/B is not necessary.

Syntax for unary operators is: `operator A`. Whitespace between operator and A
is not necessary.

Operators are read in this order (higher = evaluated first):
1. `.`, `[`, `(`
1. `a++`, `a--`
1. `!a`, `++a`, `--a`
1. `*`, `/`, `%`
1. `+`, `-`, `~`
1. `<<`, `>>`
1. `==`, `!=`, `>=`, `<=`, `>`, `<`, `is`, `!is`
1. `&`, `|`, `^`
1. `&&`, `||`
1. `=`, `+=`, `-=`, `*=`, `/=`, `%=`, `~=`, `&=`, `|=`, `^=`

## Operator Functions
Operators are read as functions, and can be overrided same as functions, and
the operands are arguments.

The function associated with each operator is as follows:
(`Ta`, `Tb`, `T` refers to data types, of `a`,`b`, or return value)
| Operators | Function																|
|-----------|-----------------------------------------|
| `.`				|	`T opMemberSelect(Ta a, char[] name)`		|
| `a[b]`		|	`T opIndexRead(Ta a, Tb b)`							|
| `a(..)`		|	`T opFnCall(Ta a, ..)`									|
| `a++`			|	`T opIncPost(Ta a)`											|
| `a--`			|	`T opDecPost(Ta a)`											|
| `!`				|	`T opBoolNot(Ta a)`											|
| `++a`			|	`T opIncPre(Ta a)`											|
| `--a`			|	`T opDecPre(Ta a)`											|
| `*`				|	`T opMultiply(Ta a, Tb b)`							|
| `/`				|	`T opDivide(Ta a, Tb b)`								|
| `%`				|	`T opMod(Ta a, Tb b)`										|
| `+`				|	`T opAdd(Ta a, Tb b)`										|
| `-`				|	`T opSubtract(Ta a, Tb b)`							|
| `~`				|	`T opConcat(Ta a, Tb b)`								|
| `<<`			|	`T opBitshiftLeft(Ta a, Tb b)`					|
| `>>`			|	`T opBitshiftRight(Ta a, Tb b)`					|
| `==`			|	`int opCmp(Ta a, Tb b)`									|
| `!=`			|	`int opCmp(Ta a, Tb b)`									|
| `>=`			|	`int opCmp(Ta a, Tb b)`									|
| `<=`			|	`int opCmp(Ta a, Tb b)`									|
| `>`				|	`int opCmp(Ta a, Tb b)`									|
| `<`				|	`int opCmp(Ta a, Tb b)`									|
| `&`				|	`T opBinAnd(Ta a, Tb b)`								|
| `\|`			|	`T opBinOr(Ta a, Tb b)`									|
| `^`				|	`T opBinXor(Ta a, Tb b)`								|
| `&&`			|	`bool opBoolAnd(Ta a, Tb b)`						|
| `\|\|`		|	`bool opBoolOr(Ta a, Tb b)`							|
| `=`				|	`T opAssign(Ta a, Tb b)`								|
| `+=`			|	`T opAddAssign(Ta a, Tb b)`							|
| `-=`			|	`T opSubtractAssign(Ta a, Tb b)`				|
| `*=`			|	`T opMultiplyAssign(Ta a, Tb b)`				|
| `/=`			|	`T opDivideAssign(Ta a, Tb b)`					|
| `%=`			|	`T opModAssign(Ta a, Tb b)`							|
| `~=`			|	`T opConcatAssign(Ta a, Tb b)`					|
| `&=`			|	`T opBinAndAssign(Ta a, Tb b)`					|
| `\|=`			|	`T opBinOrAssign(Ta a, Tb b)`						|
| `^=`			|	`T opBinXorAssign(Ta a, Tb b)`					|

the `is`, and `!is` operators are a language feature and do not translate to a
function call.

## `int opCmp(Ta a, Tb b)`
This function is used to evaluate the `>=`, `<=`, `>`, and `<` operators.

It should return only one of these values:
* `-1` - a is less than b
* `0` - a is equal to b
* `1` - a is greater than b

The comparison operators are translated as follows:

|	Expression	|	Compiled Form							|
|-------------|---------------------------|
|	`a >= b`		| `opCmp(a, b) !is -1`			|
|	`a <= b`		| `opCmp(a, b) !is 1`				|
|	`a > b`			| `opCmp(a, b) is 1`				|
|	`a < b`			| `opCmp(a, b) is -1`				|
