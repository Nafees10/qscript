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

# Visibility
QScript has these visibility specifiers:  

* `private` - Only accessible from within script.
* `public` - Accessible by other scripts when this script is loaded as a library.

By default, all declarations are `private`.

These can be written right before any declaration like:  
```
private function void somePrivateFunction(int arg){
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
where `RETURN_VALUE` is the value to return. As soon as this statement is executed, the function execution quits, meaning that in the following code, writeln will not be called.
```
function int someFunction(){
	return 0;
	writeln("this won't be written"); # because return terminates the execution
}
```

In case of functions of type void, `return;` can be used to terminate execution, like:
```
function void main(){
	# ..
	return;
	# anything below wont be executed
}
```

## `this` Function
Each script can have 1 `this` function. It will be called before any other function in the scipt is called i.e: the `this` function can be used to initialize the script.  

`this` function is defined like:
```
function void this(){
	# code to be executed when script is loaded
}
var int someGlobalVar = 5; # global variables are initialized before calling this()
```
`this` function must not return any value.

`this` function's visibility does not matter, as it cannot be called in script.

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
* `int` - a signed 32 or 64 bit integer (`ptrdiff_t` in DLang is used for this)
* `double` - a floating point (same as `double` in DLang)
* `char` - an 8 bit character
* `bool` - a `true` or `false` (same as Dlang `bool`)

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
public function Position getPosition(int x, int y){
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

## Variable Scope
Variables and references are only available inside the "scope" they are declared in. In the code below:  
```
var int someGlobalVar;
public function void main(int count){
	var int i = 0;
	while (i < count){
		var int j;
		# some other code
		i = i + 1;
	}
}
```
Varible `i` and `count` are accessible throughout the function. Variable `j` is accessible only inside the `while` block. Variable `someGlobalVar` is declared outside any function, so it is available to all functions defined _inside_ the script, as it is `private`.  

## Reference Declaration
References can be used to "point" to another variable.
They can be declared like:
```
var TYPE@ ref0, ref1, ref3;
```
`TYPE` can be any valid data type, for example:
```
var int@ ptrInt;
```
or:
```
var int[]@ refToIntArray; # this is a reference to array of int
var int@[] arrayOfRefToInt; # this is an array of reference of int
```

references are initliazed to be `null`.

## Using References
References can be assigned like:
```
var int i;
var int@ ref;
ref = @i; # ref is now pointing to i, @i returns the reference to i
```
and read like:
```
var int i;
var int@ ref = @i;
i = 5;
writeln("Value of i="~toStr(@ref));
```
References are also valid when passed to other functions as arguments, as in the following example:
```
function void main(){
	var int i;
	setRefTo(@i, 1024);
	# i is now 1024
	writeln (toStr(i)); # prints 1024, assuming writeln function exists
}
function void setRefTo(int@ ref, int to){
	@ref = to;
}
```
Functions can also return references, except for reference to a local variable.

---

# Shadowing
In case an identifier matches with a library, and with one defined in script, the one declared in the script will be preferred.  
  
In case of variables, see the following example:  
```
var int i; # global i
function void main(int i){
	# 		local i	^
	# now this function cannot access the global i
	i = 5; 		# this refers to i passed as parameter
	var int i; 	# this is not allowed
	if (i < 5){
		var int i = 0;
		# in this scope, this i is separate from the i above.
		# this may or may not be allowed, can be changed in compiler
	}
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
The `else` part is not required. If `CONDITION` is `false`, then, if the else exists, it's executed, if `CONDITION` is `true`, then `# some code` is executed.  
It is not necessary that the `# some code` or the `# some (other?) code` be in a block. In case only one statement is to be executed, it can be written like:  
```
if (CONDITION)
	# some code, single statement
else
	# some other code, single statement
```
Indentation is also not necessary, it can be written like:
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
}while (CONDITION);
```
First the code is executed, then if the condition is `true`, it's executed again.

## For:

```
for (INIT_STATEMENT; CONDITION; INCREMENT_STATEMENT){
    # some code in a loop
}
```
First, the `INIT_STATEMENT` is executed, right before starting the loop. This is executed only once. Then if `CONDITION` is `true`, the loop body is executed, then `INCREMENT_STATEMENT` is executed, this is repeated, until condition is false.  
Unlike other languages (like D), the `INIT_STATEMENT`, `CONDITION`, and `INCREMENT_STATEMENT` all must be present.

## Break & Continue
A `break;` statement can be used to exit a loop at any point, and a `continue;` will jump to the end of current iteration.

---

# Operators

The syntax for all operators is: `value0 OPERATOR value1`, where `OPERATOR` is an operator from the lists below.  
Operators that take only one operand are written like: `OPERATOR value`.  
The whitespace between value(s) and operator is not necessary.  
  
Some operators can have higher precedence.  
These are the default precedence settings:  
1. `&&`, `||`
2. `==`, `!=`, `>=`, `<=`, `>`, `<`
3. `!`
4. `*`, `/`
5. `+`, `-`, `~`, `%`, `@`

Operators within the same precedence are read left to right.