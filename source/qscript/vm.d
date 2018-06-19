/+
classes and stuff for the VM:  
converting bytecode to function_pointers and running it
+/
module qscript.vm;

import qscript.compiler.compiler;
import qscript.compiler.bytecode;
import qscript.qscript : QData;
import std.conv : to;
import utils.lists;
import utils.misc;

/// to run QScipt bytecode VM
package class QScriptVM{
private:
	// operator functions/instructions

	/// adds 2 ints
	void addInt(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		currentCall.stack.push(QData(
				args[0].intVal + args[1].intVal
				));
	}
	/// adds 2 doubles
	void addDouble(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		currentCall.stack.push(QData(
				args[0].doubleVal + args[1].doubleVal
				));
	}

	/// subtracts 2 ints
	void subtractInt(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		currentCall.stack.push(QData(
				args[0].intVal - args[1].intVal
				));
	}
	/// subtracts 2 doubles
	void subtractDouble(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		currentCall.stack.push(QData(
				args[0].doubleVal - args[1].doubleVal
				));
	}

	/// multiplies 2 ints
	void multiplyInt(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		currentCall.stack.push(QData(
				args[0].intVal * args[1].intVal
				));
	}
	/// multiplies 2 doubles
	void multiplyDouble(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		currentCall.stack.push(QData(
				args[0].doubleVal * args[1].doubleVal
				));
	}

	/// divides 2 ints
	void divideInt(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		currentCall.stack.push(QData(
				args[0].intVal / args[1].intVal
				));
	}
	/// divides 2 doubles
	void divideDouble(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		currentCall.stack.push(QData(
				args[0].doubleVal / args[1].doubleVal
				));
	}

	/// <int> mod <int>
	void modInt(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		currentCall.stack.push(QData(
				args[0].intVal % args[1].intVal
				));
	}
	/// <double> mod <double>
	void modDouble(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		currentCall.stack.push(QData(
				args[0].doubleVal % args[1].doubleVal
				));
	}

	/// concatenates 2 strings
	void concatString(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		currentCall.stack.push(QData(
				args[0].strVal ~ args[1].strVal
				));
	}
	/// concatenates 2 arrays
	void concatArray(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		currentCall.stack.push(QData(
				args[0].arrayVal ~ args[1].arrayVal
				));
	}

	// instructions for comparing stuff

	/// `==` operator for int
	void isSameInt(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		if (args[0].intVal == args[1].intVal){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}
	/// `==` operator for double
	void isSameDouble(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		if (args[0].doubleVal == args[1].doubleVal){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}
	/// `==` operator for string
	void isSameString(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		if (args[0].strVal == args[1].strVal){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}

	/// < operator for int
	void isLesserInt(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		if (args[0].intVal < args[1].intVal){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}
	/// < operator for double
	void isLesserDouble(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		if (args[0].doubleVal < args[1].doubleVal){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}

	/// > operator for int
	void isGreaterInt(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		if (args[0].intVal > args[1].intVal){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}
	/// > operator for double
	void isGreaterDouble(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		if (args[0].doubleVal > args[1].doubleVal){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}

	// vars:

	/// inits a var
	void varCount(){
		currentCall.vars.length = currentCall.readInstructionArgs()[0].intVal;
	}

	/// pushes value of a var to stack
	void getVar(){
		currentCall.stack.push( currentCall.vars[currentCall.readInstructionArgs()[0].intVal] );
	}

	/// sets value of a var
	void setVar(){
		currentCall.vars[currentCall.readInstructionArgs()[0].intVal] = currentCall.stack.pop;
	}

	// array related functions

	/// initializes an array, containing provided elements, returns the array
	void makeArray(){
		currentCall.stack.push(
			QData(
				currentCall.stack.pop!(true)(
					currentCall.readInstructionArgs()[0].intVal
					)
				)
			);
	}

	/// makes an empty array
	/// 
	/// called after array is declared, to init it.
	void emptyArray(){
		currentCall.stack.push (QData([]));
	}

	/// changes length of an array, returns the new array
	/// 
	/// first arg is an array containing all the elemnets of the array to modify
	/// second arg is the new length
	void setLen(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		args[0].arrayVal.length = args[1].intVal;
		currentCall.stack.push(args[0]);
	}

	/// returns the length of an array
	/// 
	/// the first arg is the array
	void getLen(){
		currentCall.stack.push(
			QData(
				currentCall.stack.pop.arrayVal.length
				)
			);
	}

	/// returns an element from an array
	/// 
	/// first arg is the array, second is the index of the element
	void readElement(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		currentCall.stack.push(
			args[0].arrayVal[args[1].intVal]
			);
	}

	/// modifies an array, returns the modified array
	void modifyArray(){
		QData[] indexes = currentCall.stack.pop!(true)(currentCall.readInstructionArgs[0].intVal);
		QData newVal, array;
		newVal = currentCall.stack.pop;
		array = currentCall.stack.pop;
		QData subArray;
		uinteger indexToModify = indexes[indexes.length-1].intVal;
		indexes.length--;
		array.arrayVal = array.arrayVal.dup;
		subArray = array;
		for (uinteger i=0; i < indexes.length; i ++){
			subArray = subArray.arrayVal[indexes[i].intVal];
		}
		subArray.arrayVal[indexToModify] = newVal;
		currentCall.stack.push(array);
	}

	/// returns a char (inside a string with length=1) from a string at an index
	void readChar(){
		QData[2] args = currentCall.stack.pop!(true)(2);
		currentCall.stack.push(
			QData(cast(string)[args[0].strVal[args[1].intVal]])
			);
	}

	/// returns length of string
	void strLen(){
		currentCall.stack.push(
			QData(currentCall.stack.pop.strVal.length)
			);
	}

	// data type conversion instructions

	/// str -> int
	void strToInt(){
		currentCall.stack.push(
			QData(to!integer(currentCall.stack.pop.strVal))
			);
	}

	/// str -> double
	void strToDouble(){
		currentCall.stack.push(
			QData(to!double(currentCall.stack.pop.strVal))
			);
	}

	/// int -> str
	void intToStr(){
		currentCall.stack.push(
			QData(to!string(currentCall.stack.pop.intVal))
			);
	}

	/// int -> double
	void intToDouble(){
		currentCall.stack.push(
			QData(to!double(currentCall.stack.pop.intVal))
			);
	}

	/// double -> str
	void doubleToStr(){
		currentCall.stack.push(
			QData(to!string(currentCall.stack.pop.doubleVal))
			);
	}

	/// double -> int
	void doubleToInt(){
		currentCall.stack.push(
			QData(to!integer(currentCall.stack.pop.doubleVal))
			);
	}

	// stack instructions

	/// pushes a value or more to the stack
	void push(){
		currentCall.stack.push(currentCall.readInstructionArgs());
	}

	/// clears the stack
	void clear(){
		currentCall.stack.clear();
	}

	/// pops a number of elements from stack
	void pop(){
		currentCall.stack.pop!(true)(currentCall.readInstructionArgs()[0].intVal);
	}

	// misc instructions

	/// jumps to another instruction using the instruction index
	void jump(){
		currentCall.instructionIndex = currentCall.readInstructionArgs()[0].intVal;
	}

	/// skipTrue, skips the next instruction in case last element on stack == 1 (int)
	void skipTrue(){
		if (currentCall.stack.pop().intVal == 1){
			currentCall.instructionIndex ++;
		}
	}

	/// if last element on stack == 1 (int), pushes 0 (int), else, pushes 1 (int)
	void not(){
		if (currentCall.stack.pop().intVal == 1){
			currentCall.stack.push(QData(cast(integer)0));
		}else{
			currentCall.stack.push(QData(cast(integer)1));
		}
	}

	/// if last 2 elements on stack == 1 (int), pushes 1 (int), else, pushes 0 (int)
	void and(){
		QData toPush = QData(cast(integer)1);
		foreach (toCheck; currentCall.stack.pop!(true)(2)){
			if (toCheck.intVal == 0){
				toPush = QData(cast(integer)0);
				break;
			}
		}
		currentCall.stack.push(toPush);
	}

	/// if either of last 2 elements on stack == 1 (int), pushes 1 (int), else, pushes 0 (int)
	void or(){
		QData toPush = QData(cast(integer)0);
		foreach (toCheck; currentCall.stack.pop!(true)(2)){
			if (toCheck.intVal == 1){
				toPush = QData(cast(integer)1);
				break;
			}
		}
		currentCall.stack.push(toPush);
	}

	/// returns a value from a function being executed
	void returnInstruction(){
		currentCall.result = currentCall.stack.pop;
		// then break execution of that function
		currentCall.instructionIndex = currentCall.instructions.length;
	}

	// executing functions:

	/// executes a script-defined function, return is pushed to stack
	/// 
	/// first arg is function name, second arg is number of args to pop for the function
	void execFuncS(){
		QData[] args = currentCall.readInstructionArgs();
		QData[] fArgs = currentCall.stack.pop!(true)(args[1].intVal);
		string fName = args[0].strVal;
		currentCall.stack.push(executeScriptFunction(fName, fArgs));
	}

	/// executes an external function, return is pushed to stack
	/// 
	/// first arg is function name, second arg is number of args to pop for the function
	void execFuncE(){
		QData[] args = currentCall.readInstructionArgs();
		QData[] fArgs = currentCall.stack.pop!(true)(args[1].intVal);
		currentCall.stack.push(_onExternalCall(args[0].strVal, fArgs));
	}
	
	/// to store data (args, result, vars) for a call to script-defined function, and the stack
	struct FunctionCallData{
		QData[] vars; /// the vars that this function has
		QData result; /// stores the return value of this function
		Stack!QData stack; /// the stack that this call will use
		
		string fName; /// name of this function
		uinteger instructionIndex; /// index of the current instruction being executed
		void delegate()[] instructions; /// the instructions that make this function
		QData[][] instructionArgs;

		/// postblit
		this(this){
			vars = vars.dup;
			instructions = instructions.dup;
			instructionArgs = instructionArgs.dup;
		}
		/// constructor
		this(string functionName, QData[] args){
			vars = args.dup;
			fName = functionName;
			instructionIndex = 0;
			stack = new Stack!QData;
		}
		/// destructor
		~this(){
			.destroy(stack);
		}
		/// reads args for the current instruction
		@property QData[] readInstructionArgs(){
			return instructionArgs[instructionIndex];
		}
	}
	/// stores the instructions from the compiled byte code, index is function name
	void delegate()[][string] instructions;
	/// stores the arguments for each instruction from compiled byte code, index is function name
	QData[][][string] instructionArgs;
	/// the function-call-data for currently being executed function
	FunctionCallData* currentCall;

	/// stores the pointer to delegate to call to execute an external function
	QData delegate(string, QData[]) _onExternalCall;
	/// stores the pointer to delegate to call when RuntimeError occurs  
	/// if it returns true, keep running, else, break execution of current function
	bool delegate(RuntimeError) _onRuntimeError;
public:
	/// struct to store a runtime error
	struct RuntimeError{
		string functionName; /// the script-defined function in which the error occurred
		uinteger instructionIndex; /// the index of the instruction at which the error occurred
		string error; /// a description of the error
		/// constructor
		this (string fName, uinteger index, string errorMsg){
			functionName = fName;
			instructionIndex = index;
			error = errorMsg;
		}
	}
	~this(){
		if (currentCall !is null){
			.destroy(currentCall);
		}
	}
	/// to set the function to call to handle external function calls
	@property QData delegate(string, QData[]) onExternalCall(QData delegate(string, QData[]) fPtr){
		return _onExternalCall = fPtr;
	}
	/// to set the function to call to handle RuntimeErrors
	@property bool delegate(RuntimeError) onRuntimeError(bool delegate(RuntimeError) fPtr){
		return _onRuntimeError = fPtr;
	}
	/// compiles a byte code, and makes it ready for execution  
	/// any previously loaded byte code is kept
	/// 
	/// Returns: errors in byte code, or zero-length string if there were not errors
	string loadByteCode(string[] byteCode){
		ByteCode.ByteCodeFunction!(void delegate())[] functions;
		string error = "";
		// compile it, long code ahead
		try{
			functions = ByteCode.toFunctionPtr!(void delegate())(byteCode,[
					// operators
					"addInt" 			: &addInt,
					"addDouble" 		: &addDouble,
					"subtractInt"		: &subtractInt,
					"subtractDouble"	: &subtractDouble,
					"multiplyInt"		: &multiplyInt,
					"multiplyDouble"	: &multiplyDouble,
					"divideInt"			: &divideInt,
					"divideDouble"		: &divideDouble,
					"modInt"			: &modInt,
					"modDouble"			: &modDouble,
					"concatArray"		: &concatArray,
					"concatString"		: &concatString,
					// bool operators
					"isSameInt"			: &isSameInt,
					"isSameDouble"		: &isSameDouble,
					"isSameString"		: &isSameString,
					"isLesserInt"		: &isLesserInt,
					"isLesserDouble"	: &isLesserDouble,
					"isGreaterInt"		: &isGreaterInt,
					"isGreaterDouble"	: &isGreaterDouble,
					"not"				: &not,
					"and"				: &and,
					"or"				: &or,
					// misc. instructions
					"push"				: &push,
					"clear"				: &clear,
					"pop"				: &pop,
					"jump"				: &jump,
					"skipTrue"			: &skipTrue,
					"return"			: &returnInstruction,
					// arrays stuff
					"setLen"			: &setLen,
					"getLen"			: &getLen,
					"readElement"		: &readElement,
					"modifyArray"		: &modifyArray,
					"makeArray"			: &makeArray,
					"emptyArray"		: &emptyArray,
					// strings
					"strLen"			: &strLen,
					"readChar"			: &readChar,
					// concatString also comes under this, but it's an operator related thing, so its up there ^
					// data type conversion
					"strToInt"			: &strToInt,
					"strToDouble"		: &strToDouble,
					"intToStr"			: &intToStr,
					"intToDouble"		: &intToDouble,
					"doubleToStr"		: &doubleToStr,
					"doubleToInt"		: &doubleToStr,
					// executing functions
					"execFuncS"			: &execFuncS,
					"execFuncE"			: &execFuncE,
					// vars
					"varCount"			: &varCount,
					"getVar"			: &getVar,
					"setVar"			: &setVar
					
				]);
		}catch (Exception e){
			error = e.msg;
			.destroy(e);
			return error;
		}
		// now put functions in the arrays
		foreach (currentFunction; functions){
			instructions[currentFunction.name] = currentFunction.instructions.dup;
			instructionArgs[currentFunction.name] = currentFunction.args.dup;
		}
		return error;
	}
	/// executes a script-defined function, with the provided arguments, and returns the result
	/// 
	/// throws Exception if the function does not exist
	QData executeScriptFunction(string fName, QData[] args){
		// check if it exists
		if (fName in instructions){
			// put previous call in call stack
			FunctionCallData* lastCall = currentCall;
			// prepare a new call
			currentCall = new FunctionCallData(fName, args);
			currentCall.instructions = instructions[fName];
			currentCall.instructionArgs = instructionArgs[fName];
			// start executing instruction, one by one
			for (; currentCall.instructionIndex < currentCall.instructions.length; ++ currentCall.instructionIndex){
				try{
					currentCall.instructions[currentCall.instructionIndex]();
				}catch (Exception e){
					if (!_onRuntimeError(RuntimeError(fName, currentCall.instructionIndex, e.msg))){
						// break :(
						break;
					}
				}
			}
			// get the result of the function
			QData result = currentCall.result;
			// destroy stack
			.destroy(*currentCall);
			// restore previous call
			currentCall = lastCall;
			// return the result
			return result;
		}else{
			throw new Exception("function '"~fName~"' is not defined in the script/byteCode");
		}
	}

	/// breaks execution of current function
	void breakCurrent(){
		if (currentCall !is null){
			currentCall.instructionIndex = currentCall.instructions.length;
		}
	}
}
