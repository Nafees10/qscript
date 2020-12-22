# QScript Syntax

# Comments
Comments can be added using the `#` character. Anything following a `#` is ignored by compiler as a comment.  
For example:  
```
# a comment
void main(){ # This is a comment
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

# Visibility
QScript has these visibility specifier:  

* `private` - Only accessible from within script.
* `public` - Accessible by other scripts when this script is loaded as a library.

By default, all declarations are `private`.

These can be written right before any declaration like:  
```
private void somePrivateFunction(int arg){
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
## Function Definition
```
function RETURN_TYPE FUNCTION_NAME (arg0_type arg0, arg1_type arg1){
	# function body
}
```
* `RETURN_TYPE` is the return type of this function
* `FUNCTION_NAME` is the name of the function
* `arg0_type` is the type for first argument
* `arg0` is the "name" for first argument
* more arguments can be added, and are to be separated by a comma.
  
A function without any arguments would be defined like:
```
function TYPE FUNCTION_NAME(){
	# function body
}
```

## Returning From Functions
A return statement can be used to return a value from the function. The type of the return value, and the return type of the function must match.
A return statement is written as following:
```
return RETURN_VALUE;
```
where `RETURN_VALUE` is the value to return. As soon as this statement is executed, the function execution quits, meaning that in the following code, 
writeln will not be called.
```
function int someFunction(){
	return 0;
	writeln("this won't be written"); # because return terminates the execution
}
```

In case of functions of type void, `return null;` can be used to terminate execution, like:
```
function void main(){
	# ..
	return null;
	# anything below wont be executed
}
```

## `this` Function
Each script can have 1 `this` function. It will be called before any other function in the scipt is called i.e: the `this` function can be used to initialize the script.  

`this` function is defined like:
```
function this(){
	# code to be executed when script is loaded
}
var int someGlobalVar = 5; # global variables are initialized before calling this()
```
`this` function must not return any value.

## Function Calls
Function calls can be made liks this:
```
FUNCTION_NAME (arg0, arg1);
```
And a function can take more/less than 2 arguments. In case it doesnt take any arguments, it will be called like:
```
FUNCTION_NAME ();
```

In case a function with same argument types and same name is declared in a library and the script, the one 
declared in the script will be called.

---

# Data Types
QScript has these basic data types:
* `int` - a signed integer (`ptrdiff_t` in DLang is used for this)
* `uint` - an unsigned integer (`size_t` in DLang)
* `double` - a floating point (same as `double` in DLang)
* `char` - a 1 byte character
* `bool` - a `true` (non-zero int) or `false` (int, 0)
* `byte` - signed 1 byte integer
* `ubyte` - unsigned 1 byte integer

Following data types can be defined in scripts that are derived from the above basic types:

## Structs
These can be used to store multiple values of varying or same data types. They are defined like:  
```
struct STRUCT_NAME{
	var DATA_TYPE1 NAME1;
	var DATA_TYPE2 NAME2;
}
```

* `STRUCT_NAME` is the name of this struct. This must be unique within the script, and must not conflict among any `import`ed data types.
* `DATA_TYPE1` is the data type for the first value.
* `NAME1` is the name for the first value

QScript does not _yet_ allow functions as members of structs, only variables can be members.

An example usage of a struct would be:  
```
public struct Position{
	var int x, y;
}
public Position getPosition(int x, int y){
	Position pos;
	pos.x = x;
	pos.y = y;
	return pos;
}
```

## Enums
Enums are defined like:  
```
enum EnumName{
	member0,
	member1,
	member2
}
```

* `EnumName` is the name for this enum

Example:    
```
public enum ErrorType{
	FileNotFound,
	InvalidPath,
	PermissionDenied
}
```

An enum's member's value can be read as: `EnumName.MemberName`.

---

# Variables

## Variable Declaration
Variables can be declared like:
```
var TYPE var0, var1, var2;
```
* `TYPE` is the data type of the variables, it can be a `char`, `int`, `double`, `bool`, or an array of those types: `int[]`, or `int[][]`... .
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
var char someChar = 'a';
var char[] someString;
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

By default, references are initliazed to be `null`.

## Variable Scope
Variables and references are only available inside the "scope" they are declared in. In the code below:  
```
var int someGlobalVar;
public void main(int count){
	var int i = 0;
	while (i < count){
		var int j;
		# some other code
		i = i + 1;
	}
}
```
Varible `i` and `count` are accessible throughout the function. Variable `j` is accessible only inside the `while` block. Variable `someGlobalVar` is declared outside any function, so it is available to all functions defined _inside_ the script, as it is `private`.  

## Using References
References can be assigned like:
```
var int i;
var @int ref;
ref = @i; # ref is now pointing to i, @i returns the reference to i
```
and read like:
```
var int i;
var @int ref = @i;
i = rand(); # assuming rand() is a function that returns int
writeln("Value of i="toStr(@ref)); # @ref returns the value of the variable it is pointing 
```
References are also valid when passed to other functions as arguments, as in the following example:
```
void main(){
	var int i;
	setRefTo(@i, 1024);
	# i is now 1024
	writeln (toStr(i)); # prints 1024, assuming writeln function exists
}
void setRefTo(@int ref, int to){
	@ref = to;
}
```

---

# Shadowing
In case a function call, variable, enum, or struct matches the one made public by a library, and one declared
in the script, the one declared will be preferred.  
  
In case of variables where the same variable name is used in a outer scope, this will result in an error. The 
rule stated above applies only to conflicts between script and libraries.

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
The `else` part is not required. If `CONDITION` is `false`, then, if the else exists, it's executed, if `CONDITION` is `true`, then `# some code` is executed.  
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
As long as `CONDITION` is `true`, `# some code in a loop` is executed. And just like if statements, while loops can also be nested

## Do While:

Do while loops are writen like:
```
do{
    # some code in a loop
}while (CONDITION)
```
First the code is executed, then if the condition is `true`, it's executed again. An optional semicolon can be put at the end of the `while (CONDITION)`. 

## For:

The for loop in QScript is a bit different from other languages, it's written like:
```
for (INIT_STATEMENT; CONDITION; INCREMENT_STATEMENT;){
    # some code in a loop
}
```
in this loop, notice that there is a semicolon after `INCREMENT_STATEMENT`, that is necessary.  
First, the `INIT_STATEMENT` is executed, right before starting the loop. This is executed only once. Then if `CONDITION` is `true`, the loop body is executed, then `INCREMENT_STATEMENT` is executed, this is repeated, until condition is false.  
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

* `==` returns `true` if two integers/floats/strings/arrays are same. 
* `>` returns `true` if `value0` int/float is greater than `value1` int/float.
* `<` returns `true` if `value0` int/float is lesser than `value1` int/float.
* `>=` returns `true` if `value0` int/float is greater than or equal to `value1` int/float.
* `<=` returns `true` if `value0` int/float is lesser than or equal to `value1` int/float.
* `&&` returns `true` if `value0` and `value1` are both `true`
* `||` returns `true` if either of `value0` or `value1` are `true`, or both are `true`

## Other Operators:

* `!` not operator (works on `bool`), returns `true` if operand is `false`, `false` if operand is `true`
* `@` ref/de-ref operator. Returns reference to variable when operand is variable. Returns value of variable which a reference is pointing to when operand is reference.
