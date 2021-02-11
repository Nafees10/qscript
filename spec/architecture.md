// TODO complete this thing

## QScript NaVM instructions

Below is a list of instructions that QScript adds to the NaVM VM

### Function Calls:
* _`Call [n - integer >=2]`_  
Pops a library ID & then a function ID (both `integer>=0`). Then pops `n-2` number of elements (in order they were pushed) and passes them as arguments for the function call. Pushes the value returned by function.  
This is **not** used for calling functions that are in the same bytecode.
* _`RetValSet`_  
Pops an element from stack, stores it temporarily as a return value.
* _`RetValPush`_  
Pushes the return value that was saved using `RetValSet`, and unsets the return value.

### Arrays:
* _`arrayCopy`_  
pops a reference to array, creates a copy of that, and pushes it back.
* _`arrayElement [n - integer>=0]`_  
pops a reference to array, pushes value of the element at `index=n` of array.
* _`arrayElementWrite [n - integer>=0]`_  
pops a reference to array, then a value. Writes that value to `array[n]`.

### Jumps:
* _`jumpFrameN [jumpPosition]`_  
Same as NaVM's `jumpFrame`, except this changes value of _stackIndex so that a number of elements are already after `stack[_stackIndex]`.  
That number of elements is popped from stack.