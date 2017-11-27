# Predefined QScript Functions
This document contains some information about the functions predefined in QScript.

## Arrays:
### setLength
Modifies length of an existing array.  
**Arguments:**  
1. The array to change length of. Data Type: `void[]` , array of any type, of any dimensions.
2. The new length. Data Type: `int` >=0  

**Returns:**  
The array with the new length. Data Type: same data type as argument1  

**Usage:**  
```
int[] (array);
array = setLength(array, 5); # change array's length to hold 5 elements, from index 0 to index 4
```
### getLength
Returns the length of an array.  
**Arguments:**  
1. The array to get length of. Data Type: `void[]` , array of any type, of any dimensions.  

**Returns:**  
The length of array in argument1. Data Type: `int` >=0  
**Usage:**  
```
int[] (array);
array = [0, 2, 4, 6];
getLength (array); # returns 4
```
### array
Puts all provided arguments in an array. Unlike `[...]`, arguments be be literal or not.  
**Arguments:**  
* The elements of the resulting array. Data Type: `void`, can be of any type, all arguments must be of the same type.  

**Returns:**  
The arguments in an array. Data Type: `void[]`, array of the data type of the arguments.  
**Usage:**  
```
int[] (array);
array = array (0, 2, 4, 6); # same as [0, 2, 4, 6], except, this function can be used with variables
```

---

## Strings:
### strLen
To get the length of a string.  
**Arguments:**  
1. The stirng to get the length of. Data Type: `string`  

**Rerurns:**  
The length of the string in argument1. Data Type: `int` >=0  
**Usage:**  
```
strLen("hello World!"); # returns 12
```

---

## Data Type Conversion:
### strToInt
Reads an integer from a string.  
**Arguments:**  
1. The string to read from. Data Type: `string`  

**Returns:**  
The integer read from it. Data Type: `int`  
**Usage:**  
```
int (sum);
sum = 2 + strToInt("5"); # sum is now: 7
```
### strToDouble
Reads a double (floating point number) from a string.  
**Arguments:**  
1. The string to read from. Data Type: `string`  

**Returns:**  
The double read from it. Data Type: `double`  
**Usage:**  
```
double (sum);
double = 2.0 + strToDouble("5.7"); # sum is now: 7.7
```
### intToStr
Puts the value of an integer into a string.  
**Arguments:**  
1. The integer value to put into a string. Data Type: `int`  

**Returns:**  
The string containing the integer. Data Type: `string`  
**Usage:**  
```
string (r);
r = "sum of 2 & 5 is: "~intToStr(2+5);
```
### intToDouble
Puts the value of an integer into a double.  
**Arguments:**  
1. The integer to put into a double. Data Type: `int`  

**Returns:**  
The double containing the same value as the integer. Data Type: `double`  
**Usage:**  
```
double (d);
d = 5.7 + intToDouble(2);
```
### doubleToStr
Puts the value of a double into a string.  
**Arguments:**  
1. The double value to put into a string. Data Type: `double`  

**Returns:**  
The string containing the double. Data Type: `string`  
**Usage:**  
```
string (r);
r = "sum of 2 & 5.7 is: "~doubleToStr( 2.0 + 5.7 );
```
### doubleToInt
Puts the value of a double into an integer, ignoring the decimal value.  
**Arguments:**  
1. The double to put into an integer. Data Type: `double`  

**Returns:**  
The integer containing the integral value of the double. Data Type: `int`  
**Usage:**  
```
int (i);
i = 2 + doubleToInt(5.7); # i is now 7, because 2+5=7
```

---

## Functions:
### return
Returns a value from a function, and exits execution of that function. If used in `void functions`, will just exit execution.  
**Arguments:**  
1. The data to return. Data Type: same as the function return type.  

**Returns:**  
nothing. Data Type: `void`, no return value  
**Usage:**  
```
# function to get sum of 2 ints
function int sum (int a, int b){
	return (a + b);
}
```