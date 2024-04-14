**Work In Progress, not finalised**

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

Use `///` comments for writing documentation.

---

# Functions

QScript has first class functions. Functions can be assigned to a variable
(of appropriate type), or passed as an argument, they behave as normal
variables.

## Function Definition

```
[pub] fn [RETURN_TYPE] FUNCTION_NAME(
		[@]arg0_type arg0,
		[@]arg1_type arg1){
	# function body
}
```

* `pub` (optional) will make the function public
* `RETURN_TYPE` (optional) is the return type of this function.
* `@` (optional) for pass by reference
* `FUNCTION_NAME` is the name of the function
* `arg0_type` is the type for first argument
* `arg0` is the "name" for first argument
* more arguments can be added, and are to be separated by a comma.

A function without any arguments would be defined like:
```
fn [TYPE] FUNCTION_NAME(){
	# function body
}
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
sumXTimes(5, @mul5);
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

The first argument(s) to a function call can also be passed using the `.`
operator:

```
fn int sum(int a, int b){
	return a + b;
}

fn main(){
	writeln(sum(5, 5)); # is same as following
	writeln(5.sum(5)); # is same as following
	writeln((5, 5).sum()); # is same as following
	writeln((5, 5).sum); # writes 25
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
var @fn() fref;
fref @= bar; // bar will not be called
```

---

# Data Types

QScript has these basic data types:

* `int` - largest supported signed integer (usually 64 or 32 bits)
* `uint` - largest supported unsigned integer (usually 64 or 32 bits)
* `i8` - 8 bit signed integer
* `i16` - 16 bit signed integer
* `i32` - 32 bit signed integer
* `i64` - 64 bit signed integer
* `u8` - 8 bit unsigned integer
* `u16` - 16 bit unsigned integer
* `u32` - 32 bit unsigned integer
* `u64` - 64 bit unsigned integer
* `f64` - a 64 bit floating point (double)
* `f32` - 32 bit bit floating point
* `char` - an 8 bit character
* `bool` - a `true` or `false` (Dlang `bool`)
* `auto` - in above examples, `auto` can be substituted for `X` in cases where
	inline assignment occers and compiler is able to detect intended type.
* `@X` - reference to any of the above (behaves the same as `X` alone would)
* `@fn ...(...)` - reference to a function

## `int` (and other integers)

This can be written as series (or just one) digit(s).

Can be written as:

* Binary - `0B1100` or `0b1100` - for `12`
* Hexadecimal - `0xFF` or `0XfF` - for `15`
* Series of `[0-9]+` digits

`int` is initialised as `0`.

## floating points

Digits with a single `.` between them is read as a double.
`5` is an int, but `5.0` is a double.

initialised as `0.0`

## `char`

This is written by enclosing a single character within a pair of apostrophes:

`'c'` for example, or `'\t'` tab character.

initialised as ascii code `0`

## `bool`

A `true` (1) or a `false` (0).

While casting from `int`, a non zero value is read as a `true`, zero as `false`.

initialised as `false`

## `@X` references

These are aliases to actual variables.
a reference is initialised to be `null`, and can be pointed to some data using
the `@=` operator.

```
int i = 0;
var @int r; // initialised to null
if (r is null)
	writeln("r is null");
r @= i;
# r can now be used as if it's an int.
writeln(r); # 1
writeln(i); # 1
```

## `auto` variables

The `auto` keyword can be used to infer types:

```
var auto x = something;
var auto y @= something;
```

Where it is not possible for qscript to detect whether `auto` should resolve to
`T` or `@T`, it will prefer `T`. To override this behavior, use `@auto`

---

# Structs

These can be used to store multiple values of varying or same data types.
They also act as namespaces.

They are defined like:

```
struct STRUCT_NAME{
	[pub] TYPE NAME [ = INIT_VALUE];
	[pub] TYPE NAME [ = INIT_VALUE] , NAME_2 [ = INIT_VALUE];
	[[pub] alias [X] = [Y]]
}
```

By default, all members inside a struct are private.

Members of a struct can be:

* variables - `var TYPE NAME;`
* static variables - `static var TYPE NAME;`
* static functions - `static fn foo(){ ... }`

## Anonymous Structs

A struct can be created, and immediately used, without being given a type name:

```
var struct{ int i; string s; } data;
data.i = 5;
data.s = "foo";
```

`struct{ int i; string s; }` is treated as an expression.

As such, structs can be defined as:

```
alias T = struct{ int i; string s; };
// or
struct T{ int i; string s; }
```

## Equivalence

Two different structs will always be treated as different types, regardless of
their members:

```
struct T{ int i; string s; }

alias TT = struct { int i; string s; };

struct TTT{ int i; string s; }
```

Each of these (`T`, `TT`, and `TTT`) are a different type.

Aliases to a defined type are equivalent:

```
struct Foo{ int i; string s; }
alias Bar = Foo;
// bar is equivalent to Foo

alias A = struct{ int i; string s; };
alias B = struct{ int i; string s; };
// A and B are not equivalent
// nor are they equivalent to either Foo or Bar
```

## `this` member in struct

Having `X.this` defined, where X is a struct, will add a fallback member to do
operations on rather than the struct itself:

```
struct Length{
	int len = 0;
	string unit = "cm";
	alias this = len;
}
var Length len = 0; // Length = int is error, so assigns to the int member
len = 1;
writeln(len + 5); // Length + int is not implemented, evaluates to len.len + 5
writeln(len.unit); // prints "cm"
```

---

# Unions

Unions store one of the members at a time, along with a tag, indicating which
member is currently stored:

```
union Name{
	[pub] TYPE NAME;
	[[pub] alias X = Y;]
}
```

Example:

```
union Val{
	int i = 0;
	float f;
	string s;
}
```

Example:

```
struct User{
	string username;
	union{
		struct {} admin;
		struct {} moderator;
		struct {} user;
		struct {
			int loginAttempts = int.max;
			string ipAddr = "127.0.0.1";
		} loggedOut;
	} this;
}
```

This is a User struct, where the username is always stored, along with one of:

* nothing - in case of `admin`
* nothing - in case of `moderator`
* nothing - in case of `user`
* `loginAttempts` and `ipAddr` - in case of `loggedOut`

Similar to structs, anonymous unions can also be created.

Same equivalence rules as structs apply.

Same rules regarding `this` member as struct apply.

## Initializing Union

A union must at all times have a valid member. At initialization, the default
member can be denoted by assigning a default value to it. For example:

```
union Foo{
	struct {} bar = void; // bar is default
	int baz;
}

union Num{
	int i;
	float f = float.init; // f is default
}
```

## Reading tag

The `unionIs(U, T)` can be used to check if a union currently stores a tag:

```
union Foo{
	struct {} bar = void;
	int baz;
}
var Foo f;
$assert($unionIs(f, bar) == true);
$assert($unionIs(f, baz) == false);
f.baz = 5;
$assert($unionIs(f, bar) == false);
$assert($unionIs(f, baz) == true);
```

In case of `this` members:

```
union Foo{
	struct {} bar = void;
	int baz;
	alias this = bar;
}
var Foo f;
$assert($unionIs(f) == $unionIs(f, bar));
```

Alternatively, the `?` operator can be used:

```
union Foo{
	struct {} bar = void;
	alias this = bar;
	int baz;
}
var Foo f;
$assert(f?);
$assert(f.bar?);
$assert(f.baz? == false);
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
enum int ErrorType{
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
var [static] TYPE var0, var1, var2;
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

Variables are only available inside the scope they are declared in.
In the code below:

```
var int someGlobalVar;
pub fn main(int count){
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
outside any function, so it is available to all functions defined inside the
module, as it is `private`.

---

# Modules

Each file is a module.

The `load` keyword can be used to instantiate a module.
A module is similar to a struct, except:

1. only 1 instannce of a module can exist, created the first time `load` is
	called
2. private members inside a module are not accessible outside

```
# file debug.qs
var string prefix = "debug: ";
pub var auto log = (string msg) -> { ... };

# file main.qs:
var auto logger = load(debug);
pub fn this(){
	logger.log("started");
	logger.prefix.writeln; # compiler error, prefix not accessible
};
```

is equivalent to:

```
# file main.qs:
module Logger{
	var string prefix = "debug: ";
	pub var auto log = (string msg) -> { ... };
}

var Logger logger;
fn this(){
	logger.log("started");
	logger.prefix.writeln; # compiler error, prefix not accessible
}
```

In the first case, the `load(debug)` statement creates an instance of the
`debug.qs` module, and returns it.

assigning a "namespace" of sorts as shown above is not necessary, a library can
be loaded so that its symbols become accessible as global symbols:

```
load(debug);
```

This will create an instance of debug and merge it's public symbols with
current module.

Similarly, a module can be loaded and all it's public symbols made public:

```
pub load(debug);
```

if a module is `load`-ed multiple times, instance is created only once,
succeeding `load`s return the same instance.

# Visibility

All members are by default private, and only accessible inside current scope.

The `pub` keyword can be prefixed to make a member public:

```
pub struct SomeStruct{
	int someInt, someOtherInt; # these data members are private
	pub int x; # this is public
}
```

private applies at module level. For example:

```
# file coord.qs
pub struct Coord{
	var int x, y; # private
	this (int x, int y){
		this.x = x;
		this.y = y;
	}
}
pub Coord right(Coord c){
	return Coord(c.x + 1, c.y); # Coord.x Coord.y accessible inside module
}

# file app.qs
load(coord);
pub fn main(){
	var Coord c;
	c.x = 5; # compiler error, Coord.x is private
}
```

---

# Shadowing

In case an identifier matches with a library, and with one defined in module,
the one declared in the module will be preferred.

---

# If Statements

If statements are written like:

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

## While:

While loops are written like:

```
while (CONDITION) {
	# some code in a loop
}
```

As long as `CONDITION` is `true`, `# some code in a loop` is executed.

## Do While:

Do while loops are writen like:

```
do {
	# some code in a loop
} while (CONDITION);
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
auto __range = data.rangeOf;
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

To make a data type `X` iterable, `X.rangeOf` should return a range, for
example:

```
fn RangeObjectOfX rangeOf(X){
	return RangeObjectOfX(X);
}
```

Or in case `X` itself is a range, you can use the `alias .. = this`:

```
struct X{
	# ...
	alias rangeOf = this;
}
```

## Break & Continue

A `break;` statement can be used to exit a loop at any point, and a `continue;`
will jump to the end of current iteration.

---

# Operators

Operators are read in this order (higher = evaluated first):

1. `.`, `?`
1. `[`
1. `@`, `fn`
1. `(`
1. `a++`, `a--`
1. `!a`, `++a`, `--a`
1. `*`, `/`, `%`
1. `+`, `-`
1. `<<`, `>>`
1. `==`, `!=`, `>=`, `<=`, `>`, `<`, `is`, `!is`
1. `&`, `|`, `^`
1. `&&`, `||`
1. `=`, `+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `@=`

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
through `T opCast(To)(val)`.

It is not necessary that the `opCast(To)` return type be `To`, for example:

```
union Optional(T){
	pub T this;
	pub struct{} none = void;
}

/// An integer that is >=5 and <= 10
struct WeirdInt{
	pub int this;
}

Optional(WeirdInt) opCast(To : WeirdInt)(int i){
	OptionalInt ret;
	if (i < 5 || i > 10)
		return ret;
	ret = i;
	return ret;
}
```

---

# Conditional Compilation

## `$if`

`$if` can be used to determine which branch of code to compile:

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
	writeln(num.stringOf);
}
```

Since a `$for` will copy it's body, it will result in redefinition
errors if any definitions are made inside. To avoid, do:

```
$for (num; [0, 5, 4, 2]){{
	enum square = num * num;
	writeln(square.stringOf);
}}
```

Since `$for` is evaluated at compile time, it can iterate over sequnces:

```
$for (num; (0, 5, 4, 2)){
	num.stringOf.writeln;
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

Templates can be used to create compile time constants:

```
template TypeName(T) if ($isType){
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

## Unions

```
$union Optional(T) if ($isType(T)){
	pub T this;
	pub struct {} none;
}
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
* `unionIs(unionInstance, tagSymbolName)` - true if `tagSymbolName` is stored
* `unionIs(unionInstance)` - true if `this` is stored
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
