// TODO complete this thing

## QScript NaVM instructions

Below is a list of instructions that QScript adds to the NaVM VM

### Function Calls:
* _`Call [n - integer >=2]`_  
Pops a library ID & then a function ID (both `integer>=0`). Then pops `n-2` number of elements (in order they were pushed) and passes them as arguments for the function call. Return value can be get by using `RetValPush`
This is **not** used for calling functions that are in the same bytecode.
* _`RetValSet`_  
Pops an element from stack, stores it temporarily as a return value.
* _`RetValPush`_  
Pushes the return value that was saved using `RetValSet`, and unsets the return value.

### Variables
* _`VarGet [libId - integer>=0]`_  
Pops variable id (integer>=0) from stack, pushes value of that variable from that library.
* _`VarGetRef [liId - integer>=0]`_  
Same as above, but pushes reference to that variable so it can be written to.

### Arrays & References:
* _`makeArrayN [n - integer>=0]`_  
Creates an array of length `n`, pushes its reference to stack.
* _`arrayCopy`_  
pops a reference to array, creates a copy of that, and pushes it back.
* _`arrayElement [n - integer>=0]`_  
pops a reference to array, pushes value of the element at `index=n` of array.
* _`arrayElementWrite [n - integer>=0]`_  
pops a reference to array, then a value. Writes that value to `array[n]`.
* _`arrayFromElements [n - integer>=0]`_  
Pops n elements (in the order they were pushed), puts them in an array, pushes the reference to the array.
* _`incRefN [n - integer]`_  
same as NaVM's incRef, but here it increments by `n`.
* _`pushRefFromPop`_  
Pops an element, pushes it's reference.

### Jumps:
* _`jumpFrameN [jumpPosition]`_  
Same as NaVM's `jumpFrame`, except this changes value of _stackIndex so that a number of elements are already after `stack[_stackIndex]`.  
That number of elements is popped from stack.