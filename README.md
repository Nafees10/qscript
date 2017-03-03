## QScript is a fast, and simple scripting language.
### Features:
1. Easy and unique (a bit like C) syntax
2. Arrays - Dynamic Arrays, length can be changed at runtime
3. Fast execution - or should I say, very fast. The `demo.qscript` takes just 0.05 seconds more than it's D (compiled) equaivalent!
4. More features on the way, qscript is still in beta
5. One script can have several functions, making it usable for 'event-based scripting' - and those functions can call each other.
6. Dynamic typed, yet very fast.

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
			qwrite("Hello World!");
		}
Just a note: The `qwrite` function is not in QScript by default.  
##### Arrays(plus a bit more)  

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
				qwrite("someArray[",string(i),"]=",someArray[i],"\n");
				i = i + 1;
			}
		}


P.S: Updates have slowed down, a lot, because I am nowadays very busy with my studies.
