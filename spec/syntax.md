Note: this is currently WIP and not finalised

TODO: reorganize the sections in this

# QScript Language Reference

# Comments
Comments can be added using the `#` character or `//`.
Anything following a `#` or `//` is ignored by compiler as a comment.

For example:

```
# a comment
// another comment
fn main(){ # This is a comment
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

# Loading external scripts/libraries
The `load` keyword can be used to create an instance of an existing script.
A script is similar to a struct:

```
debug.qscript:
	var string prefix = "debug: ";
	pub var auto log = (string msg) -> { ... };

main.qscript:
	var auto logger = load(debug);
	pub var auto this = () -> {
		logger.log("started");
	};
```

is equivalent to:

```
main.qscript:
	struct SomeInaccessibleType{
		var string prefix = "debug: ";
		pub var auto log = (string msg) -> { ... };
	}

	var SomeInaccessibleType logger;
	fn this(){
		logger.log("started");
	}
```

In the first case, the `load(debug)` statement creates an instance of the
`debug.qscript` script, and returns it.

assigning a "namespace" of sorts as shown above is not necessary, a library can
be loaded so that its symbols become accessible as global symbols:

```
load(debug);
```

This will create an instance of debug and merge it's symbols with current
script.

Similarly, a script can be loaded and all it's public symbols made public:

```
pub load(debug);
```

if a script/library is `load`-ed multiple times, instance is created only once,
succeeding `load`s return the same instance.

---

# Visibility
All script members are by default private, and only accessible inside the
script.

The `pub` keyword can be prefixed to make a member public:

```
fn somePrivateFunction(int arg){
	# body of private function
}
pub struct SomeStruct{
	var int someInt, someOtherInt; # these data members are private
	pub var int x; # this is public
}
```

# Functions
QScript has first class functions. Functions can be assigned to a variable
(of appropriate type), or passed as an argument, they behave as normal
variables.

## Function Data Type
To create a variable that can store a function:

```
var fn RETURN_TYPE(arg0_type, arg1_type, ..) someFunc;
// or
var auto someFunc = someExistingFunction; // assignmment necessary here
```

following this, the function can be called using the `(..)` operator:

```
someFunc(arg0, arg1);
```

The Function Data Type is a reference data type, annotating it with a `ref` is
not necessary, and not allowed.

## Function Definition
```
[pub] fn [ref] [RETURN_TYPE] FUNCTION_NAME(
		[ref] arg0_type arg0,
		[ref] arg1_type arg1){
	# function body
}
// or
[pub] var auto FUNCTION_NAME = (
		[ref] arg0_type arg0,
		[ref] arg1_type arg1) -> [RETURN_TYPE]{
	# function body
};
```

* `pub` (optional) will make the function public
* `ref` (optional) will make it so parameters/return is passed by reference not
	value
* `RETURN_TYPE` (optional) is the return type of this function.
* `FUNCTION_NAME` is the name of the function
* `arg0_type` is the type for first argument
* `arg0` is the "name" for first argument
* more arguments can be added, and are to be separated by a comma.

_Note that the `ref` part of return type is not a property of the function,
but rather a part of the return data type._

A function without any arguments would be defined like:
```
fn [TYPE] FUNCTION_NAME(){
	# function body
}
# or
var auto FUNCTION_NAME = () -> TYPE{
	# function body
};
```

## Default parameters

Default values for parameters can be written as:

```
fn int sum(int a = 0, int b = 1){...} // valid
fn int sum(int a, int b = 1){...} // valid
fn int sum(int a = 0, int b){...} // invalid
```

While calling a function, to use the default value for a parameter:
```
sum(, 1); // default value for a is used
sum(0, 1); // no default value used
sum(0); // default value for b used
```

## Anonymous Functions
```
fn int sumXTimes(int x, fn int(int) func){
	var int i = 0;
	var int sum;
	while (i < x)
		sum += func(i ++);
	return sum;
}
sumXTimes(5, (num) -> num * 5);
# is equivalent to:
sumXTimes(5, (int num) -> {return num * 5;});
# is equivalent to:
fn mul5(int num){ return num * 5; }
sumXTimes(5, mul5);
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

In case of functions that return nothing, `return;` can be used to terminate
execution, like:

```
fn main(){
	# ..
	return;
	# anything below wont be executed
}
```

## Function Calls
Function calls are made through the `()` operator like:

```
fnName(funcArg0, funcArg1, ...);
```

or in case of no arguments:

```
fnName();
```

The first argument to a function call can also be passed using the `.` operator:

```
fn int square(int i){
	return i * i;
}
fn main(){
	writeln(square(5)); # is same as following
	writeln(5.square); # writes 25
	# () operator not needed in this case
}
```

Alternatively, just writing the name of a function will call it, if it has
either no arguments, or all the arguments were provided using `.` operator:

```
fn func(int a, int b){
	# do stuff
}
fn bar(){ ... }
bar; // will call
(5, 6).func; // will call
5.func(6); // is the same as above
```

The one case where this will not result in a function call:

```
var fn() fref;
fref -> bar; // bar will not be called
```

---

# Data Types
QScript has these basic data types:

* `int` - a signed 32 or 64 bit integer (`ptrdiff_t` in DLang is used for this)
* `double` - a floating point (`double` in DLang)
* `char` - an 8 bit character
* `bool` - a `true` or `false` (Dlang `bool`)
* `auto` - in above examples, `auto` can be substituted for `X` in cases where
	inline assignment occers and compiler is able to detect intended type.
* `ref X` - reference to any of the above (behaves the same as `X` alone would)
* `fn ...(...)` - a Function Data Type (see above)

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
a `ref` is initialised to be `null`, and can be pointed to some data using the
`->` operator.

```
int i = 0;
var ref int r; // initialised to null
if (r is null)
	writeln("r is null");
r -> i;
# r can now be used as if it's an int.
writeln(r); # 1
writeln(i); # 1
```

## `auto` variables
The `auto` keyword can be combined with others in the following order:

```
var [ref] auto
```

This is necessary since the `auto` detection will not pick up whether it should
be made `ref`

---

# Structs
These can be used to store multiple values of varying or same data types.
They also act as namespaces.

They are defined like:

```
struct STRUCT_NAME{
	# members go here
}
```

By default, all members inside a struct are private.

Members of a struct can be:

* variables - `var TYPE NAME;`
* static variables - `static var TYPE NAME;`
* functions - `fn print(){ ... }`
* static functions - `static fn print(){ ... }`

## `this` constructor
Similar to scripts, structs have a constructor that is called after initialising
variables:

```
struct Position{
	var int x = 0, y = 0;
	pub fn this(){
		writeln("constructed 0,0");
	}
	pub fn this(int x, int y){
		this.x = x;
		this.y = y;
		writeln("constructed with values");
	}
}
```

---

# Enums
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
	FileNotFound = 1, # default value is first one
	InvalidPath = 1 << 1, # constant expression is allowed
	PermissionDenied = 4
}
```

An enum's member's value can be read as: `EnumName.MemberName`, using the
member selector operator.

Enums act as data types:

```
var ErrorType err; # initialised to FileNotFound
// or
var auto err = ErrorType.FileNotFound;
```

## Compile Time Constants

The `enum` keyword can be used to create constants that are evaluated compile
time as follows:

```
enum int U8MASK = (1 << 4) - 1; # evaluated at compile time
```

---

# Aliases

`alias` keyword can be used to enable using alternative identifiers to access
something:

```
struct Position{ # struct is private
	pub int x, y;
}

pub alias Coordinate = Position; # Coordinate is publically accessible
```

---

# Variables

## Variable Declaration
Variables can be declared like:

```
var [static] [ref] TYPE var0, var1, var2;
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
var string someString;
someString = [someChar, 'b', 'c'] ; # you could've also done someChar + "bc"
```

## Variable Scope
Variables are only available inside the "scope" they are declared in.
In the code below:

```
var int someGlobalVar;
public fn main(int count){
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

---

# Loops

## While:

While loops are written like:

```
while (CONDITION){
	# some code in a loop
}
```

As long as `CONDITION` is `true`, `# some code in a loop` is executed.

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

For loops uses `Ranges` to iterate over members of a value.

A for loop can be written as:
```
for (counter; value; range)
	writeln(counter + 1, "th value is ", value);
// or
for (value; range)
	writeln(value);
```

Example:

```
var auto data = getStuff();
for (val; data)
	writeln(val);
// is equivalent to:
for (val; data.rangeOf)
	writeln(val);
// is equivalent to:
auto __range = rangeOf(data);
while (!__range.empty()){
	var auto val = __range.front();
	writeln(val);
	__range.popFront();
}
```

### Ranges:

A data type `T` can qualify as a range if the following functions can be called
on it:

```
T.empty(); // should return true if there are no more values left to pop
T.front(); // current value
T.popFront(); // pop current element
```

To make a data type `X` iterable, there should exist a function:

```
fn RangeObjectOfX rangeOf(X){
	return RangeObjectOfX(X);
}
```

## Break & Continue
A `break;` statement can be used to exit a loop at any point, and a `continue;`
will jump to the end of current iteration.

---

# Operators

Operators are read in this order (higher = evaluated first):

1. `.`
1. `[`
1. `ref`, `fn` - these are special cases, available only in Data Type
1. `(`
1. `a++`, `a--`
1. `!a`, `++a`, `--a`
1. `*`, `/`, `%`
1. `+`, `-`
1. `<<`, `>>`
1. `==`, `!=`, `>=`, `<=`, `>`, `<`, `is`, `!is`
1. `&`, `|`, `^`
1. `&&`, `||`
1. `=`, `+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `->`

## Operator Overloading
Operators are read as functions, and can be overrided same as functions.

operators are translated as:

```
a + b;
// translated to
opBin("+")(a, b);

a ++;
// translated to
opPost("++")(a);

++ a;
// translated to
opPre("++")(a);

a(...);
// translated to:
opBin("()")(a, ...);

a[b];
// translated to:
opBin("[]")(a, b);

a.b;
// translated to:
opBin(".", "b")(a);
```

The `is`, and `!is` operators are a language feature and do not translate to a
function call.

Example:

```
struct A{}
struct B{}
$fn int opBin(string op : "+", aType : A, bType : B)(aType a, bType B){
	return 5;
}
$fn opBin(string op : "()", T : A, ParamT...)(T a, ParamT params){
	writeln("A called with params: ", params);
}
$fn $typeof(T.$member(b)) opBin(string op : ".", string b, T : A)(T a){
	return $member(a, b);
}
```

## Casting

QScript does explicit, and implicit casting. Implicit casting is implemented
through `T opImplicitCast(T, a)`.

---

# Conditional Compilation

## `$if`

The `$if` can be used to determine which branch of code to compile:

```
$if (platformIsLinux){
	enum string PlatformName = "Linux";
}else{
	enum string PlatformName = "Other";
}
```

## `$for`

`$for` iterates over a container that is available at compile time,
and copies its body for each element:

```
# this loop will not exist at runtime
$for (num; [0, 5, 4, 2]){
	writeln(num.toString());
}
```

Since a `$for` will copy it's body, it will result in redefinition
errors if any definitions are made inside. To avoid, do:

```
$for (num; [0, 5, 4, 2]){{
	enum square = num * num;
	writeln(square.toString());
}}
```

Since `$for` is evaluated at compile time, it can iterate over sequnces:

```
$for (num; (0, 5, 4, 2)){
	num.toString.writeln;
}
```

---

# Templates

A template can be declared using the `template` keyword followed by name and a
tuple of template parameters:

```
// an overly complicated way to create global variables of a type
template globVar(T){
	var T this;
}
template square(int x){
	enum int this = getSquare(x); # function call will be made at compile time
	fn int getSquare(int x){ return x * x; }
}
template sum(T x, T y, T){
	enum T this = x + y;
}
```

Anything within a template is private.

Since the enums inside the template are named `this`, the resulting enum
will replace the template whereever initialised:

```
globVar(int) = 5;
writeln(globVar(int)); # prints 5
writeln(square(5)); # prints 25
writeln(sum(5.5, 2)); # prints 7.5
```

As shown above, templates are initialised similar to a function call

## Conditions

Templates can be tagged with an if condition block, to only initialize if
it evaluates to true:

```
template foo(T) if (someCondition(T)){
	enum string this = "bar";
}
```

Another way to condition a template is through the `:` operator in template
paramters list:

```
template typeStr(T : int){
	enum string this = "int";
}
template typeStr(T : double){
	enum string this = "double"
}
template number(T : (int, double)){
	alias this = T;
}
```

## Mixin

A template can be mixin'd; initialized in the context where it is called. This
can be done by following any template definition by the `mixin` keyword:

```
mixin template foo(){
	writeln(i);
}
fn main(){
	var int i = 5;
	foo(); // equivalent to calling `writeln(i)` right here
				 // prints 5
}
```

## Functions

Function templates are defined as regular functions with an extra tuple for
template parameters:

```
$fn T sum(T)(T a, T b) if (someCondition){
	return a + b;
}
// or
$fn T sum(T)(T a, T b){
	return a + b;
}
// or
template sum(T){
	fn T this(T a, T b){
		return a + b;
	}
}
```

Calling a function template can be done as:

```
var int c = sum(int)(5, 10);
// or
var int c = sum(5, 10); // T is inferred
```

QScript is able to determine what value to use for `T`, only if the former
declaration (`$fn bool sym(T)(T a, T b)`) is used.

## Enums

Templates can be used on compile time constants:

```
template TypeName(T) if ($isType){ // the if (..) is optional
	$if (T is int)
		enum string this = "int";
	else $if (T is double)
		enum string this = "double";
	else $if (T is string)
		enum string this = "string";
	else
		enum string this = "weird type";
}
// or
$enum string TypeName(T) if ($isType(T)) = doSomethingAtCompileTime();

$fn bool typeIsSupported(T)(){
	return TypeName(T) != "weird type";
}
```

## Structs

```
$struct Position(T) if ($isNumber(T)){
	var T x, y;
}
// or
template Position(T){
	struct this{
		var T x, y;
	}
}
alias PositionDiscrete = Position(int);
alias PositionContinuous = Position(double);
```

## Variables

```
$var T foo(T), bar(T);
fn setFoo(){
	foo(int) = 5;
	foo(string) = "hello";
}

fn setBar(){
	bar(int) = 10;
	bar(string) = " world";
}

fn main(){
	setFoo();
	setBar();
	writeln(foo(string), bar(string)); # "hello world"
	writeln(foo(int)); # 5
	writeln(bar(int)); # 10
}
```

## Aliases

```
$alias X(T) = T;
$var X(int) i = 5;
```

Alias templates can be used to create type qualifiers. When an alias template
`foo(...)` is used as a Data Type, QScript will check if `foo(T)` evaluates to
`T`. If it does, `T` is a `foo` qualified type:

```
$alias Number(T) if (T is int || T is double) = T;

fn double square(Number x){
	return x * x;
}

square(5); // 25.0
square(5.5); // 30.25
square("a"); // compiler error
```

Another example:

```
$alias Number(T) if (T is int || T is double) = T;
template Iterable(BaseType){
	$alias this(T) if ($isRange(T) && $rangeType(T) is BaseType) = T;
}

fn double sum(Iterable(Number) numbers){
	double ret;
	for (num; numbers)
		ret += num;
	return ret;
}
```

## Sequences

Sequences are compile time "lists" of aliases and/or values (can be mixed).

A sequence can be defined as: `(a, b, c)`

A template can receive a sequence as:

```
template foo(T...){}
```

A sequence containing aliases to types can be used to declare a sequence of
variables:

```
$fn T[0] sum(T...)(T params){
	var T[0] ret;
	$for (val; params)
		ret += val;
	return ret;
}
```

Length of a sequence can be found through the `length` template:

```
fn printLength(T...)(){
	length(T).writeln;
}
```

---

# Macros

Compiler macros, written as:

```
$macroName(args...)
```

_Note: list is incomplete_

* `assert(condition, error)` - Emits error as a compiler error if !condition
* `fnRetType(symbol)` - return type of a function
* `fnArgs(symbol)` - array of names of function arguments
* `fnArgType(symbol, name)` - argument type of argument with name in function
* `members(symbol)` - string array, names of accessible members inside of a
	symbol. Works for structs and enums.
* `member(symbol, nameStr)` - returns member with name=nameStr in symbol.
	Works for structs and enums.
* `canImplicitCast(s1, s2)` - whether s1 can be implicitly casted to s2
* `canCast(s1, s2)` - whether s1 can be casted to s2 (implicitly or explicitly)
* `typeOf(symbol)` - data type of a symbol
* `isStatic(symbol)` - true if a symbol is static
* `isRef(symbol)` - true if a data type is reference
* `isTemplate(symbol)` - true if a symbol is a template
* `isFn(symbol)` - true if a symbol is a function
* `isFnTemplate(symbol)` - true if a symbol is a function template
* `isStruct(symbol)` - true if a symbol is a struct
* `isStructTemplate(symbol)` - true if a symbol is a struct template
* `isEnum(symbol)` - true if a symbol is an enum
* `isEnumTemplate(symbol)` - true if a symbol is an enum template
* `isVar(symbol)` - true if a symbol is a variable
* `isVarTemplate(symbol)` - true if a symbol is a variable template
* `isPub(symbol)` - true if a symbol is public
