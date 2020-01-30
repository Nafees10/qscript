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

## length ( void[] )
Returns the length of an array.  
**Arguments:**  

1. The array to get length of. Data Type: `void[]` , array of any type, of any dimensions.  

**Returns:**  
The length of array in argument1. Data Type: `int` >=0  
**Usage:**  
```
int[] array;
array = [0, 2, 4, 6];
length (array); # returns 4
```

## copy(void[], @void[])
Copies first array onto second. Changing the elements of 
the second array following this function call will not affect
the original array.  
**Arguments:**  

1. The array to make copy of. Data Type: `void[]`, array of any type, **One dimensional**.  
2. The array to copy it onto. Data Type: `void[]`, array of any type, **One dimensional**.  

**Returns:**  
`void`  

**Usage:**  
```
int[] array = [0,1,2,3];
int[] another = array;
another[0] = 1; # this will also change array[0] to 1 
copy(array, @another);
another[1] = 2; # now, array is unaffected, only applies to another
```

---

## Data Type Conversion:
## toInt ( char[]/double )
Reads an integer from a string or reads integer value from double.  
**Arguments:**  

1. The string to read from, or the double to read integer from. Data Type: `char[]` or `double`  

**Returns:**  
The integer read from it. Data Type: `int`  
**Usage:**  
```
int sum;
sum = toInt(2.7) + toInt("5"); # sum is now: 7, as in 2+5
```

## toDouble ( char[]/int )
Reads a double (floating point number) from a string, or from integer.  
**Arguments:**  

1. The string to read from, or integer. Data Type: `char[]` or `int`  

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
The string containing the integer or double. Data Type: `char[]`  
**Usage:**  
```
char[] r;
r = "i="toStr(5)~" d="~toInt(5.4);# r is now "i=5 d=5.4"
```
