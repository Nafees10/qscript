# QScript Syntax

# Comments
Comments can be added using the `#` character. Anything following a `#` is ignored by compiler as a comment.  
For example:  
```
# a comment
function void main(){ # This is a comment
	# This also is a comment
}

```

---

# Importing libraries
Libraries can provide function and/or data types. Importing a library named `math` and `stdio` would be done like:  

```
import math, stdio;
```
Or:
```
import math;
import stdio;
```

---

# Functions
## Function Definition
```
function FLAGS RETURN_TYPE FUNCTION_NAME (arg0_type arg0, arg1_type arg1){
	# function body
}
```
* `FLAGS` (optional) are the function properties (listed below). Multiple flags can be written for a single function.
* `RETURN_TYPE` is the return type of this function
* `FUNCTION_NAME` is the name of the function
* `arg0_type` is the type for first argument
* `arg0` is the "name" for first argument
* more arguments can be added, and are to be separated by a comma.
  
A function without any arguments would be defined like:
```
function TYPE FUNCTION_NAME{
	# function body
}
```  
or:  
```
function TYPE FUNCTION_NAME(){
	# function body
}
```

### Function Flags
These are the list of flags and what they do:  
* `export` - make the function available to another script when this script is loaded as a library.
* `static` - marks the function as static i.e: The function does not: access any global variables, call any other non-static function, and does not take any references as arguments.This flag indicates to the compiler that it is safe to execute this function during compile to optimize the byte code.

## Returning From Functions
A return statement can be used to return a value from the function. The type of the return value, and the return type of the function must match.
A return statement is written as following:
```
return RETURN_VALUE;
```
where `RETURN_VALUE` is the value to return. As soon as this statement is executed, the function execution quits, meaning that in the following code, 
writeln will not be called.
```
function int someFunction{
	return 0;
	writeln("this won't be written"); # because return terminates the execution
}
```

## `this` Function
Each script can have 1 `this` function. It will be called before any other function in the scipt is called i.e: the `this` function can be used to initialize the script.  

`this` function is defined like:
```
function void this(){ # it must always be void
	# code to be executed when script is loaded
}
```

`this` function must always be of type `void` and must not return any value.

## Function Calls
There are 2 types of functions, script-defined, and external. External are made available by "registering" them into QScript (the script cannot do this).  
In case a script defined function has the same name as an external one, the script-defined one will be called, external one will be ignored.  
Both types of functions can be executed like:
```
FUNCTION_NAME (arg0, arg1);
```
And a function can take more/less than 2 arguments. In case it doesnt take any arguments, it will be called like:
```
FUNCTION_NAME ();
```

---

# Data Types
QScript has these basic data types:
* `int` - a signed integer (`ptrdiff_t` in DLang is used for this)
* `char` - a 1 byte character
* `double` - a floating point (same as `double` in DLang)

Following data types can be defined in scripts that are derived from the above basic types:

## Structs
These can be used to store multiple values of varying or same data types. They are defined like:  
```
struct FLAGS STRUCT_NAME{
	DATA_TYPE1 NAME1;
	DATA_TYPE2 NAME2;
}
```

* `FLAGS` (optional) are the properties for this struct.
* `STRUCT_NAME` is the name of this struct. This must be unique within the script, and must not conflict among any `import`ed data types.
* `DATA_TYPE1` is the data type for the first value.
* `NAME1` is the name for the first value

QScript does not allow functions as members of structs, only variables can be members.

An example usage of a struct would be:  
```
struct export Position{
	int x, y;
}
function export getPosition(int x, int y){
	var Position pos;
	pos.x = x;
	pos.y = y;
	return pos;
}
```

### Struct Flags
A struct can have these flags:
* `export` - makes this struct avaialable to another script when this script is loaded as a library

---

# Variables

## Variable Declaration
Variables can be declared like:
```
var TYPE var0, var1, var2;
```
* `TYPE` is the data type of the variables, it can be a `char`, `int`, `double`, or an array of those types: `int[]`, or `int[][]`... .
* `var0`, `var1`, `var2` are the names of the variables. There can be more/less than 3, and are to be separated by a comma.

Value assignment can also be done in the variable declaration statement like:
```
var int var0 = 12, var1 = 24;
```
## Variable Assignment
Variables can be assigned a value like:
```
VAR = VALUE;
```
the data type of `VAR` and `VALUE` must match.  
  
In case the `VAR` is an array, then it's individual elements can be modified like:
```
VAR[ INDEX ] = VALUE;
```
* `VAR` is the name of the var/array
* `INDEX` , in case `VAR` is an array, is the index of the element to assign a value to
* `VALUE` is the value to assign
And in a case like this, `VAR[INDEX]` must have the same data type as `VALUE`.
  
In case you want to modify the whole array, it can be done like:
```
char someChar = 'a';
char[] someString;
someString = [someChar, 'b', 'c'] ; # you could've also done `[someChar] ~ "bc"`
```
## Reference Declaration
References can be used to "point" to another variable.
They can be declared like:
```
var @TYPE ref0, ref1, ref3;
```
`TYPE` can be any valid data type, for example:
```
var @int ptrInt;
```
or:
```
var @int[] refToIntArray; # this is a pointer to array of int
```
Array of references is currently not possible in QScript.

## Variable Scope
Variables and references are only available inside the "scope" they are declared in. In the code below:  
```
var int someGlobalVar;
function export void main(int count){
	var int i = 0;
	while (i < count){
		var int j;
		# some other code
		i = i + 1;
	}
}
```
Varible `i` and `count` are accessible throughout the function. Variable `j` is accessible only inside the `while` block. Variable `someGlobalVar` is declared outside any function, so it is available to all functions defined _inside_ the script.  
  
Unlike functions, global variables cannot be exported in case of libraries.

## Using References
References can be assigned like:
```
int i;
@int ref;
ref = @i; # ref is now pointing to i, @i returns the reference to i
```
and read like:
```
int i;
@int ref = @i;
i = rand(); # assuming rand() is a function that returns int
writeln("Value of i="toStr(@ref)); # @ref returns the value of the variable it is pointing 
```
References are also valid when passed to other functions as arguments, as in the following example:
```
function void main(){
	int i;
	setRefTo(@i, 1024);
	# i is now 1024
	writeln (toStr(i)); # prints 1024, assuming writeln function exists
}
function void setRefTo(@int ref, int to){
	@ref = to;
}
```
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
The `else` part is not required. If `CONDITION` is 0 (int), then, if the else exists, it's executed, if `CONDITION` is 1 (int), then `# some code` is executed.  
It is not necessary that the `# some code` or the `# some (other?) code` be in a block. In case only one statement is to be executed, it can be written like:  
```
if (CONDITION)
	# some code, single statement
else
	# some other code, single statement
```
Even indentation is not necessary, it can be written like:
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
As long as `CONDITION` is 1 (int), `# some code in a loop` is executed. And just like if statements, while loops can also be nested

## Do While:
Do while loops are writen like:
```
do{
    # some code in a loop
}while (CONDITION)
```
First the code is executed, then if the condition is true, it's executed again. An optional semicolon can be put at the end of the `while (CONDITION)`. 

## For:
The for loop in QScript is a bit different from other languages, it's written like:
```
for (INIT_STATEMENT; CONDITION; INCREMENT_STATEMENT;){
    # some code in a loop
}
```
in this loop, notice that there is a semicolon after `INCREMENT_STATEMENT`, that is necessary.  
First, the `INIT_STATEMENT` is executed, right before starting the loop. This is executed only once. Then if `CONDITION` is true, the loop body is executed, then `INCREMENT_STATEMENT` is executed, this is repeated, until condition is false.  
Unlike other languages (like D), the `INIT_STATEMENT`, `CONDITION`, and `INCREMENT_STATEMENT` all must be present.

---

# Operators
One important thing to keep in mind when using operators is that they are evaluated left-to right. So instead of writing:
```
if (a == 0 || a == 1){
}
```
you should write:
```
if ((a == 0) || (a == 1)){
}
```
The syntax for all operators is: `value0 OPERATOR value1`, where `OPERATOR` is an operator from the lists below.
## Arithmetic Operators
* `/` operator divides two integers/floats
* `*` operator multiplies two integeres/floats
* `+` operator adds two integers/floats
* `-` subtracts two integers/floats
* `%` divides two integers/floats, returns the remainder
## Comparison Operators
* `==` returns 1 (int) if two integers/floats/strings/arrays are same. 
* `>` returns (int) if `value0` int/float is greater than `value1` int/float.
* `<` returns 1 (int) if `value0` int/float is lesser than `value1` int/float.
* `>=` returns (int) if `value0` int/float is greater than or equal to `value1` int/float.
* `<=` returns 1 (int) if `value0` int/float is lesser than or equal to `value1` int/float.
* `&&` returns 1 (int) if `value0` and `value1` are both 1 (int)
* `||` returns 1 (int) if either of `value0` or `value1` are 1 (int), or both are 1 (int)
## Other Operators:
* `!` not operator (works on `int`), returns `1` if operand is `0`, `0` if operand is `1`
* `@` ref/de-ref operator. Returns reference to variable when operand is variable. Returns value of variable which a reference is pointing to when operand is reference.
