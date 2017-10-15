# QScript syntax
## Functions
### Function Definition
```
function TYPE FUNCTION_NAME (arg0_type arg0, arg1_type arg1){
	// function body
}
```
* `TYPE` is the return type of this function
* `FUNCTION_NAME` is the name of the function
* `arg0_type` is the type for first argument
* `arg0` is the "name" for first argument
* more arguments can be added, and are to be separated by space.
  
A function without any arguments would be defined like:
```
function TYPE FUNCTION_NAME{
	// function body
}
```
### Returning From Functions
A return statement can be used to return a value from the function. The type of the return value, and the return type of the function must match.
A return statement is written as following:
```
return RETURN_VALUE;
```
where `RETURN_VALUE` is the value to return. As soon as this statement is executed, the function execution quits, meaning that in the following code:
```
function int someFunction{
	return 0;
	writeln("this won't be written");
}
```
writeln will not be called.

---

## Variables
### Variable Definition
Variables can be defined as shown below:
```
TYPE (var0, var1, var2);
```
* `TYPE` is the data type of the variables, it can be a `string`, `int`, `double`, or an array of those types: `int[]`, or `int'[][]`... .
* `var0`, `var1`, `var2` are the names of the variables. There can be more/less than 3, and are to be separated by a comma.
### Variable Assignment
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
  
In case you want to modify the whole array, it can be done like:
```
int[] (intArray);
intArray = [0, 1, 2, 3];
```
---

## If Statements
If statements are written like:
```
if (CONDITION){
	// some code
}else{
	// some (other?) code
}
```
The `else` part is not required. If `CONDITION` is 0 (int), then, if the else exists, it's executed, if `CONDITION` is 1 (int), then `// some code` is executed

---

## While Statements
While statements are written like:
```
while (CONDITION){
	// some code in a loop
}
```
As long as `CONDITION` is 1 (int), `// some code in a loop` is executed.

---

## Operators
One important thing to keep in mind when using operators is that they are evaluated left-to right. So instead of writing:
```
if (a == 0 || a == 1){}
```
you should write:
```
if ((a == 0) || (a == 1)){}
```
The syntax for all operators is: `value0 OPERATOR value1`, where `OPERATOR` is an operator from the lists below.
### Arithmetic Operators
* `/` operator divides two integers/floats
* `*` operator multiplies two integeres/floats
* `+` operator adds two integers/floats
* `-` subtracts two integers/floats
* `%` divides two integers/floats, returns the remainder
### Comnparison Operators
* `==` returns 1 (int) if two integers/floats/strings/arrays are same. 
* `>` returns (int) if `value0` int/float is greater than `value1` int/float.
* `<` returns 1 (int) if `value0` int/float is lesser than `value1` int/float.
* `&&` returns 1 (int) if `value0` and `value1` are both 1 (int)
* `||` returns 1 (int) if either of `value0` or `value1` are 1 (int), or both are 1 (int)

---

## Function Call
A function can be called like shown below:
```
FUNCTION_NAME (arg0, arg1);
```