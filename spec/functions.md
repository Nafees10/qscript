# Predefined QScript Functions
This document contains some information about the functions predefined in QScript.

## Arrays:
## length ( @void[], int )
Modifies length of an existing array.  
**Arguments:**  

1. The array to change length of. Data Type: `@void[]` , reference to array of any type, of any dimensions.
2. The new length. Data Type: `int` >=0  

**Returns:**  
`void`  

**Usage:**  
```
int[] array;
length(@array, 5); # change array's length to hold 5 elements, from index 0 to index 4
```
## length ( @void[] )
Returns the length of an array.  
**Arguments:**  

1. The array to get length of. Data Type: `@void[]` , reference to array of any type, of any dimensions.  

**Returns:**  
The length of array in argument1. Data Type: `int` >=0  
**Usage:**  
```
int[] array;
array = [0, 2, 4, 6];
length (@array); # returns 4
```

---

## Strings:
## length ( @string )
To get the length of a string.  
**Arguments:**  

1. The stirng to get the length of. Data Type: `string`, reference to string  

**Rerurns:**  
The length of the string in argument1. Data Type: `int` >=0  
**Usage:**  
```
string s = "Hello World!"
length(@s); # returns 12
```

---

## Data Type Conversion:
## toInt ( string/double )
Reads an integer from a string or reads integer value from double.  
**Arguments:**  

1. The string to read from, or the double to read integer from. Data Type: `string` or `double`  

**Returns:**  
The integer read from it. Data Type: `int`  
**Usage:**  
```
int sum;
sum = toInt(2.7) + toInt("5"); # sum is now: 7, as in 2+5
```
## toDouble ( string/int )
Reads a double (floating point number) from a string, or from integer.  
**Arguments:**  

1. The string to read from, or integer. Data Type: `string` or `int`  

**Returns:**  
The double read from it. Data Type: `double`  
**Usage:**  
```
double sum;
double = toDouble(2) + toDouble("5.7"); # sum is now: 7.7
```
## toStr ( int/double )
Puts the value of an integer or double into a string.  
**Arguments:**  

1. The integer or double value to put into a string. Data Type: `int` or `double`  

**Returns:**  
The string containing the integer or double. Data Type: `string`  
**Usage:**  
```
string r;
r = "i="toStr(5)~" d="~toInt(5.4);# r is now "i=5 d=5.4"
```
