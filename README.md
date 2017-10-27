### **Download from a stable release/tag - at this moment, the master branch is not stable (The compiler is being rewritten)**

## QScript is a fast, and simple scripting language.
### Features:
1. Easy syntax (somewhat similar to D)
2. Arrays - Dynamic Arrays, length can be changed at runtime
3. Fast execution - The whole script is converted into array of function-pointers, which are just called, no interpretation at run time, QScript has a compiler for this.
4. Dynamic typed - This is changing in the next version I'm working on.

---

### TODO (Features to add):
1. `if else` statements - planned for next version, 0.6.0
2. static typing - planned for next version, 0.6.0
3. `for`, and `do while` loops - planned for 0.6.1
4. compile-time optimizations - Compiler executes code like `2+2` at compile time - planned for 0.6.2

### Where to report bugs?
Use the issues tab at the top.

---

### Where to learn QScript from (Since QScript is a language itself)?
Use the wiki.

---

### Example scripts:  
##### Hello World  
		function void main{
			write("Hello World!");
		}
Just a note: The `write` function is not in QScript by default, it must be defined by the host program, before this script can run.  
And it's not necessary that execution always starts from `main` function, it is up to the program to decide which function to call.  
##### Arrays (plus a bit more)  

		function void main{
			int (someArray, i, end);
			someArray = array();
			someArray = setLength(someArray,10);
			i = 0;
			end = getLength(someArray);
			//put values in array
			while (i<end){
				someArray[i] = i+1;
				i = i + 1;
			}
			//output
			i = 0;
			while (i<end){
				write("someArray[",intToStr(i),"]=",intToStr(someArray[i]),"\n");
				i = i + 1;
			}
		}


