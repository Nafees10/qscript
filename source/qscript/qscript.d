module qscript.qscript;

import utils.misc;
import utils.lists;
import qscript.compiler.compiler;
import std.stdio;
import std.conv:to;

/// to store data from script at runtime
public union QData{
	string strVal; /// string value
	integer intVal; /// integer value
	double doubleVal; /// double/float value
	QData[] arrayVal; /// array value
	// constructor
	this (T)(T data){
		static if (is (T == string)){
			strVal = data;
		}else static if (is (T == integer) || is (T == int)){
			intVal = data;
		}else static if (is (T == double)){
			doubleVal = data;
		}else static if (is (T == QData[])){
			arrayVal = data;
		}else{
			throw new Exception("attempting to store unsupported type in QData");
		}
	}
}

/// To store information about a pre-defined function, for use at compile-time
alias Function = qscript.compiler.compiler.Function;

/// used to store data types for data at compile time
alias DataType = qscript.compiler.misc.DataType;

/// Used by compiler's functions to return error
alias CompileError = qscript.compiler.misc.CompileError;

public abstract class QScript{
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
				currentCall.stack.pop(
					currentCall.readInstructionArgs()[0].intVal
					)
				)
			);
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
	/// 
	/// arg0 is the array to modify
	/// arg1 is the new value of the element
	/// arg2 is the index of the element to modify
	void modifyArray(){
		QData[3] args = currentCall.stack.pop!(true)(3);
		args[0].arrayVal[args[2].intVal] = args[1];
		currentCall.stack.push(args[0]);
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
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
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
		string fName = args[0].strVal;
		/// check if the function is defined in script
		if (fName in extFunctionPointers){
			currentCall.stack.push(extFunctionPointers[fName](fArgs));
		}else{
			if (!onUndefinedFunctionCall(fName)){
				// skip to end
				currentCall.instructionIndex = currentCall.instructions.length;
			}
		}
	}

	// vars
	FunctionCallData* currentCall; /// fCall data for currently being executed function


	/// contains a list of all external-functions available in script, with their pointer
	QData delegate(QData[])[string] extFunctionPointers;
	/// contains a list of all external-functions with their return types and argument types
	Function[] extFunctionTypes;
	/// stores compiled byte-code for each script-defined function, where index is the function name
	void delegate()[][string] scriptInstructions;
	/// stores arguments for the compiled byte-code for each fuction
	QData[][][string] scriptInstructionsArgs;

protected:
	/// called when an error occurs, return true to continue execution and ignore the error,
	/// false to break execution of the **current function**
	abstract bool onRuntimeError(RuntimeError error);
	
	/// called when an undefined function is called. return true to ignore, false to break execution of the **current function**
	abstract bool onUndefinedFunctionCall(string fName);

	/// makes a function with name `fName` available for calling through script
	/// 
	/// returns true if it was added, else, false (could be because fName is already used?)
	bool addFunction(Function f, QData delegate(QData[]) fPtr){
		if (f.name !in extFunctionPointers){
			extFunctionPointers[f.name] = fPtr;
			extFunctionTypes ~= f;
			return true;
		}
		return false;
	}

package:
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
	/// alias to compiler.misc.CompileError
	alias CompileError = qscript.compiler.misc.CompileError;

	/// compiles and loads a script for execution. Returns errors if any, else, returns empty array
	CompileError[] loadScript(string[] script){
		// compile to byte code
		CompileError[] errors;
		string[] byteCode = compileQScriptToByteCode(script.dup, extFunctionTypes, errors);
		if (errors.length > 0){
			return errors;
		}
		debug{
			// TODO remove this debug
			arrayToFile ("/home/nafees/Desktop/q.code", byteCode);
		}
		string sError;
		if (!loadByteCode(byteCode, sError)){
			return [CompileError(0, sError)];
		}
		return [];
	}

	/// loads a byte code for execution. Returns true if no errors occured,
	/// else, writes error to `ref string error`, and returns false.
	bool loadByteCode(string[] byteCode, ref string error){
		import qscript.compiler.bytecode;
		ByteCode.ByteCodeFunction!(void delegate())[] functions;
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
					// strings
					/*"setLenString"	: &setLenString,
					"getLenString"		: &getLenString,
					"readChar"			: &readChar,
					"modifyString"		: &modifyString,*/
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
			return false;
		}
		// now put functions in the arrays
		foreach (currentFunction; functions){
			scriptInstructions[currentFunction.name] = currentFunction.instructions.dup;
			scriptInstructionsArgs[currentFunction.name] = currentFunction.args.dup;
		}
		return true;
	}

	/// executes a script-defined function, with the provided arguments, and returns the result
	/// 
	/// throws Exception if the function does not exist
	QData executeScriptFunction(string fName, QData[] args){
		// check if it exists
		if (fName in scriptInstructions){
			// put previous call in call stack
			FunctionCallData* lastCall = currentCall;
			// prepare a new call
			currentCall = new FunctionCallData(fName, args);
			currentCall.instructions = scriptInstructions[fName];
			currentCall.instructionArgs = scriptInstructionsArgs[fName];
			// start executing instruction, one by one
			for (; currentCall.instructionIndex < currentCall.instructions.length; currentCall.instructionIndex ++){
				try{
					currentCall.instructions[currentCall.instructionIndex]();
				}catch (Exception e){
					if (!onRuntimeError(RuntimeError(fName, currentCall.instructionIndex, e.msg))){
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
}