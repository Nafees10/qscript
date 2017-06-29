### **Download from a stable release/tag - outside from there, it's not functional**

## QScript is a fast, and simple scripting language.
### Features:
1. Easy syntax
2. Arrays - Dynamic Arrays, length can be changed at runtime
3. Fast execution
4. Dynamic typed - This will hopefully change soon.

---

### Where to report bugs?
Use the issues tab at the top!

---

### Where to learn QScript from (Since QScript is a language itself)?
Use the wiki!

---

### Example scripts:  
##### Hello World  
		main{
			write("Hello World!");
		}
Just a note: The `qwrite` function is not in QScript by default, it must be defined by the host program, before this script can run.  
And it's not necessary that execution always starts from `main` function, it is up to the program to decide which function to call.  
##### Arrays (plus a bit more)  

		main{
			new (someArray, i, end);
			someArray = array();
			someArray = setLength(someArray,10);
			i = 0;
			end = getLength(someArray);
			//put values in array
			while (i<end){
				someArray[i] = string(i+1);
				i = i + 1;
			}
			//output
			i = 0;
			while (i<end){
				write("someArray[",string(i),"]=",someArray[i],"\n");
				i = i + 1;
			}
		}


