module qscript.qscript;

import utils.misc;
import utils.lists;
//import qscript.compiler;
import std.stdio;
import std.conv:to;

public struct QData{
	enum Type{
		String,
		Integer,
		Double,
		Array,
		Undefined
	}
	private Type dataType = QData.Type.Undefined;
	union{
		string strVal;
		integer intVal;
		double doubleVal;
		QData[] arrayVal;
	}
	/// postblit
	this(this){
		if (dataType == QData.Type.Array){
			arrayVal = arrayVal.dup;
		}
	}
	/// changes the data contained by this struct
	@property auto value(T)(T val){
		static if (is (T == integer)){
			intVal = val;
		}else static if (is (T == double)){
			doubleVal = val;
		}else static if (is (T == string)){
			strVal = val;
		}else static if (is (T == QData[])){
			arrayVal = val;
		}
	}
	/// changes the data contained by this struct
	@property auto value(QData.Type T, T1)(T1 val){
		static if (T == Type.Integer){
			intVal = val;
		}else static if (T == Type.Double){
			doubleVal = val;
		}else static if (T == Type.String){
			strVal = val;
		}else static if (T == Type.Array){
			arrayVal = val;
		}
	}

	/// retrieves the value stored by this struct
	@property auto value(T)(){
		static if (is (T == string)){
			return strVal;
		}else static if (is (T == integer)){
			return intVal;
		}else static if (is (T == double)){
			return doubleVal;
		}else static if (is (T == QData[])){
			return &arrayVal;
		}else{
			throw new Exception("attempting to retrieve invalid data type from QData");
		}
	}
	/// retrieves the value stored by this struct
	@property auto value(QData.Type T)(){
		static if (T == Type.String){
			return strVal;
		}else static if (T == Type.Integer){
			return intVal;
		}else static if (T == Type.Double){
			return doubleVal;
		}else static if (T == Type.Array){
			return &arrayVal;
		}
	}
	@property Type type(){
		return dataType;
	}
	/// constructor
	this(T)(T val){
		value = val;
	}
}

public abstract class QScript{
private:
	// operator functions/instructions

	/// adds 2 ints
	void addInt(){
		QData[] args = currentCall.stack.pop(2);
		currentCall.stack.push(QData(
				args[0].value!(integer) + args[1].value!(integer)
				));
	}
	/// adds 2 doubles
	void addDouble(){
		QData[] args = currentCall.stack.pop(2);
		currentCall.stack.push(QData(
				args[0].value!(double) + args[1].value!(double)
				));
	}

	/// subtracts 2 ints
	void subtractInt(){
		QData[] args = currentCall.stack.pop(2);
		currentCall.stack.push(QData(
				args[0].value!(integer) - args[1].value!(integer)
				));
	}
	/// subtracts 2 doubles
	void subtractDouble(){
		QData[] args = currentCall.stack.pop(2);
		currentCall.stack.push(QData(
				args[0].value!(double) - args[1].value!(double)
				));
	}

	/// multiplies 2 ints
	void multiplyInt(){
		QData[] args = currentCall.stack.pop(2);
		currentCall.stack.push(QData(
				args[0].value!(integer) * args[1].value!(integer)
				));
	}
	/// multiplies 2 doubles
	void multiplyDouble(){
		QData[] args = currentCall.stack.pop(2);
		currentCall.stack.push(QData(
				args[0].value!(double) * args[1].value!(double)
				));
	}

	/// divides 2 ints
	void divideInt(){
		QData[] args = currentCall.stack.pop(2);
		currentCall.stack.push(QData(
				args[0].value!(integer) / args[1].value!(integer)
				));
	}
	/// divides 2 doubles
	void divdeDouble(){
		QData[] args = currentCall.stack.pop(2);
		currentCall.stack.push(QData(
				args[0].value!(double) / args[1].value!(double)
				));
	}

	/// <int> mod <int>
	void modInt(){
		QData[] args = currentCall.stack.pop(2);
		currentCall.stack.push(QData(
				args[0].value!(integer) % args[1].value!(integer)
				));
	}
	/// <double> mod <double>
	void modDouble(){
		QData[] args = currentCall.stack.pop(2);
		currentCall.stack.push(QData(
				args[0].value!(double) % args[1].value!(double)
				));
	}

	/// concatenates 2 strings
	void concatString(){
		QData[] args = currentCall.stack.pop(2);
		currentCall.stack.push(QData(
				args[0].value!(string) ~ args[1].value!(string)
				));
	}
	/// concatenates 2 arrays
	void concatArray(){
		QData[] args = currentCall.stack.pop(2);
		currentCall.stack.push(QData(
				*args[0].value!(QData[]) ~ *args[1].value!(QData[])
				));
	}

	// instructions for comparing stuff

	/// `==` operator for int
	void isSameInt(){
		QData[] args = currentCall.stack.pop(2);
		if (args[0].value!(integer) == args[1].value!(integer)){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}
	/// `==` operator for double
	void isSameDouble(){
		QData[] args = currentCall.stack.pop(2);
		if (args[0].value!(double) == args[1].value!(double)){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}
	/// `==` operator for string
	void isSameString(){
		QData[] args = currentCall.stack.pop(2);
		if (args[0].value!(string) == args[1].value!(string)){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}
	/// `==` operator for array
	void isSameInt(){
		QData[] args = currentCall.stack.pop(2);
		if (args[0].value!(QData[]) == args[1].value!(QData[])){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}

	/// < operator for int
	void isLesserInt(){
		QData[] args = currentCall.stack.pop(2);
		if (args[0].value!(integer) < args[1].value!(integer)){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}
	/// < operator for double
	void isLesserDouble(){
		QData[] args = currentCall.stack.pop(2);
		if (args[0].value!(double) < args[1].value!(double)){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}

	/// > operator for int
	void isGreaterInt(){
		QData[] args = currentCall.stack.pop(2);
		if (args[0].value!(integer) > args[1].value!(integer)){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}
	/// > operator for double
	void isGreaterDouble(){
		QData[] args = currentCall.stack.pop(2);
		if (args[0].value!(double) > args[1].value!(double)){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}

	// vars:

	/// inits a var
	void initVar(){
		QData[] args = currentCall.readInstructionArgs();
		foreach (arg; args){
			currentCall.vars[arg.value!(string)] = QData();
		}
	}

	/// pushes value of a var to stack
	void getVar(){
		currentCall.stack.push(
			currentCall.vars[currentCall.readInstructionArgs()[0].value!(string)]
			);
	}

	/// sets value of a var
	void setVar(){
		currentCall.vars[currentCall.readInstructionArgs()[0].value!(string)] = currentCall.stack.pop;
	}

	// array related functions

	/// initializes an array, containing provided elements, returns the array
	void makeArray(){
		currentCall.stack.push(
			QData(
				currentCall.stack.pop(
					currentCall.readInstructionArgs()[0].value!(integer)
					)
				)
			);
	}

	/// changes length of an array, returns the new array
	/// 
	/// first arg is an array containing all the elemnets of the array to modify
	/// second arg is the new length
	void setLen(){
		QData[] args = currentCall.stack.pop(2);
		args[0].value!(QData[]).length = args[1].value!(integer);
		currentCall.stack.push(args[0]);
	}

	/// returns the length of an array
	/// 
	/// the first arg is the array
	void getLen(){
		currentCall.stack.push(
			QData(
				currentCall.stack.pop.value!(QData[]).length
				)
			);
	}

	/// returns an element from an array
	/// 
	/// first arg is the array, second is the index of the element
	void readElement(){
		QData[] args = currentCall.stack.pop(2);
		currentCall.stack.push(
			(*args[0].value!(QData[]))[args[1].value!(integer)]
			);
	}

	/// modifies an array, returns the modified array
	/// 
	/// arg0 is the array to modify
	/// arg1 is the new value of the element
	/// arg2 is the index of the element to modify
	void modifyArray(){
		QData[] args = currentCall.stack.pop(3);
		args[0].value!(QData[])[args[2].value!(integer)] = args[1];
		currentCall.stack.push(args[0]);
	}

	// stack instructions

	/// pushes a value or more to the stack
	void push(QData[] args){
		currentCall.stack.push(args);
	}

	/// clears the stack
	void clear(QData[] args){
		currentCall.stack.clear();
	}

	/// pops a number of elements from stack
	void pop(QData[] args){
		currentCall.stack.pop(args[0].value!(integer));
	}

	// misc instructions

	/// jumps to another instruction using the instruction index
	void jump(QData[] args){
		currentCall.instructionIndex = args[0].value!(integer);
	}

	/// skipTrue, skips the next instruction in case last element on stack == 1 (int)
	void skipTrue(QData[] args){
		if (currentCall.stack.pop().value!(integer) == 1){
			currentCall.instructionIndex ++;
		}
	}

	/// if last element on stack == 1 (int), pushes 0 (int), else, pushes 1 (int)
	void not(QData[] args){
		if (currentCall.stack.pop().value!(integer) == 1){
			currentCall.stack.push(QData(cast(integer)1));
		}else{
			currentCall.stack.push(QData(cast(integer)0));
		}
	}

	/// if last 2 elements on stack == 1 (int), pushes 1 (int), else, pushes 0 (int)
	void and(QData[] args){
		QData toPush = QData(cast(integer)1);
		foreach (toCheck; currentCall.stack.pop(2)){
			if (toCheck.value!(integer) == 0){
				toPush = QData(cast(integer)0);
				break;
			}
		}
		currentCall.stack.push(toPush);
	}

	/// if either of last 2 elements on stack == 1 (int), pushes 1 (int), else, pushes 0 (int)
	void or(QData[] args){
		QData toPush = QData(cast(integer)0);
		foreach (toCheck; currentCall.stack.pop(2)){
			if (toCheck.value!(integer) == 1){
				toPush = QData(cast(integer)1);
				break;
			}
		}
		currentCall.stack.push(toPush);
	}

	// executing functions:

	/// executes a function, ignores the result
	/// 
	/// first arg is function name, second arg is number of args to pop for the function
	void execFuncI(QData[] args){
		QData[] fArgs = currentCall.stack.pop(args[1].value!(integer));
		string fName = args[0].value!(string);
		/// check if the function is defined in script
		if (fName in scriptInstructions){
			executeScriptFunction(fName, fArgs);
		}else if (fName in functionPointers){
			functionPointers[fName](args);
		}else{
			if (!onUndefinedFunctionCall(fName)){
				// skip to end
				currentCall.instructionIndex = currentCall.instructions.length;
			}
		}
	}

	/// executes a function, pushes the result to the stack
	/// 
	/// first arg is function name, second arg is number of args to pop for the function
	void ExecFuncP(QData[] args){
		QData[] fArgs = currentCall.stack.pop(args[1].value!(integer));
		string fName = args[0].value!(string);
		/// check if the function is defined in script
		if (fName in scriptInstructions){
			currentCall.stack.push(executeScriptFunction(fName, fArgs));
		}else if (fName in functionPointers){
			currentCall.stack.push(functionPointers[fName](args));
		}else{
			if (!onUndefinedFunctionCall(fName)){
				// skip to end
				currentCall.instructionIndex = currentCall.instructions.length;
			}
		}
	}

	// vars

	Stack!FunctionCallData callStack; /// call stack for the script-defined function-calls
	FunctionCallData currentCall; /// fCall data for currently being executed function


	/// contains a list of all functions available in script, with their pointer
	QData delegate(QData[])[string] functionPointers;
	/// stores compiled byte-code for each script-defined function, where index is the function name
	void delegate(QData[])[][string] scriptInstructions;
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
	bool addFunction(string fName, QData delegate(QData[]) fPtr){
		if (fName !in functionPointers){
			functionPointers[fName] = fPtr;
			return true;
		}
		return false;
	}

package:
	/// to store data (args, result, vars) for a call to script-defined function, and the stack
	struct FunctionCallData{
		QData[string] vars; /// the vars that this function has
		Stack!QData stack; /// the stack that this call will use
		
		string fName; /// name of this function
		uinteger instructionIndex; /// index of the current instruction being executed
		void delegate(QData[])[] instructions; /// the instructions that make this function
		QData[][] instructionArgs;

		/// postblit
		this(this){
			vars = vars.dup;
			instructions = instructions.dup;
			instructionArgs = instructionArgs.dup;
		}
		/// constructor
		this(string functionName, QData args){
			vars["args"] = QData(args);
			vars["result"] = QData();
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

	/// constructor
	this(){
		// TODO prepare list of instructions
		/*functionPointers = [

		];*/
	}

	/// loads, compiles, and optimizes a script. Returns errors in any, else, returns empty array
	CompileError[] loadScript(string[] script){
		// TODO, after writing optimizer & toByteCode, write this
		return [];
	}

	/// executes a script-defined function, with the provided arguments, and returns the result
	/// 
	/// throws Exception if the function does not exist
	QData executeScriptFunction(string fName, QData[] args){
		// check if it exists
		if (fName in scriptInstructions){
			// put previous call in call stack
			callStack.push(currentCall);
			// prepare a new call
			currentCall = FunctionCallData(fName, QData(args));
			currentCall.instructions = scriptInstructions[fName];
			currentCall.instructionArgs = scriptInstructionsArgs[fName];
			// start executing instruction, one by one
			for (; currentCall.instructionIndex < currentCall.instructions.length; currentCall.instructionIndex ++){
				try{
					currentCall.instructions[currentCall.instructionIndex]
						(currentCall.instructionArgs[currentCall.instructionIndex]);
				}catch (Exception e){
					if (!onRuntimeError(RuntimeError(fName, currentCall.instructionIndex, e.msg))){
						// break :(
						break;
					}
				}
			}
			// get the result of the function
			QData result = currentCall.vars["result"];
			// destroy stack
			.destroy(currentCall);
			// restore previous call
			if (callStack.count > 0){
				currentCall = callStack.pop;
			}
			// return the result
			return result;
		}else{
			throw new Exception("function '"~fName~"' is not defined in the script");
		}
	}
}