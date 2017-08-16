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
	/// changes the data contained by this struct
	@property auto value(T)(T val){
		static if (is (T == integer)){
			intVal = val;
		}else static if (is (T == double)){
			doubleVal = val;
		}else static if (is (T == string)){
			strVal = val;
		}else static if (is (T == QData[])){
			arrayVal = val.dup;
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
			return arrayVal.dup;
		}else{
			throw new Exception("attempting to retrieve invalid data type from QData");
		}
	}
	/// retrieves the type of data stored in this struct
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
	// operator functions

	/// adds 2 ints
	QData operatorAddInt(QData[] args){
		return QData(args[0].value!(integer) + args[1].value!(integer));
	}
	/// adds 2 doubles
	QData operatorAddDouble(QData[] args){
		return QData(args[0].value!(double) + args[1].value!(double));
	}
	/// subtracts ints
	QData operatorSubtractInt(QData[] args){
		return QData(args[0].value!(integer) - args[1].value!(integer));
	}
	/// subtracts doubles
	QData operatorSubtractDouble(QData[] args){
		return QData(args[0].value!(double) - args[1].value!(double));
	}
	/// multiplies 2 ints
	QData operatorMultiplyInt(QData[] args){
		return QData(args[0].value!(integer) * args[1].value!(integer));
	}
	/// multiplies 2 doubles
	QData operatorMultiplyDouble(QData[] args){
		return QData(args[0].value!(double) * args[1].value!(double));
	}
	/// divides 2 ints
	QData operatoDivideInt(QData[] args){
		return QData(args[0].value!(integer) / args[1].value!(integer));
	}
	/// divides 2 doubles
	QData operatorDivideDouble(QData[] args){
		return QData(args[0].value!(double) / args[1].value!(double));
	}
	/// int mod int
	QData operatorModInt(QData[] args){
		return QData(args[0].value!(integer) % args[1].value!(integer));
	}
	/// double mod double
	QData operatorModDouble(QData[] args){
		return QData(args[0].value!(double) % args[1].value!(double));
	}
	/// concatenates 2 string or arrays
	QData operatorConcatenate(QData[] args){
		if (args[0].type == QData.Type.Array){
			return QData(args[0].value!(QData[]) ~ args[1].value!(QData[]));
		}else{
			return QData(args[0].value!(string) ~ args[1].value!(string));
		}
	}

	// array related functions

	/// changes length of an array, returns the new array
	/// 
	/// first arg is an array containing all the elemnets of the array to modify
	/// second arg is the new length
	QData setArrayLength(QData[] args){
		QData[] array = args[0].value!(QData[]);
		array.length = args[1].value!(integer);
		return QData(array);
	}

	/// returns the length of an array
	/// 
	/// the first arg is the array
	QData getArrayLength(QData[] args){
		return QData(args[0].value!(QData[]).length);
	}

	// functions to get args, and return a result

	/// returns an array of args that the function was called with
	QData getFunctionArgs(QData[] args){
		return QData(currentFunctionArgs.dup);
	}

	/// sets the return value of the current function
	QData setFunctionReturn(QData[] args){
		currentFunctionResult = args[0];
		return QData();
	}

	// interpreter instructions

	/// pushes a value or more to the stack
	void pushStack(QData[] args){
		stack.push(args);
	}

	/// executes a function, ignores the result
	/// 
	/// first arg is function name, second arg is number of args to pop for the function
	void executeFunctionIgnoreResult(QData[] args){
		QData[] fArgs = stack.pop(args[1].value!(integer));
		string fName = args[0].value!(string);
		/// check if the function is defined in script
		if (fName in scriptInstructions){
			executeScriptFunction(fName, fArgs);
		}else if (fName in functionPointers){
			functionPointers[fName](args);
		}else{
			if (!onUndefinedFunctionCall(fName)){
				// skip to end
				currentInstructionIndex = scriptInstructions[currentFunctionName].length;
			}
		}
	}

	/// executes a function, pushes the result to the stack
	/// 
	/// first arg is function name, second arg is number of args to pop for the function
	void executeFunctionPushResult(QData[] args){
		QData[] fArgs = stack.pop(args[1].value!(integer));
		string fName = args[0].value!(string);
		/// check if the function is defined in script
		if (fName in scriptInstructions){
			stack.push(executeScriptFunction(fName, fArgs));
		}else if (fName in functionPointers){
			stack.push(functionPointers[fName](args));
		}else{
			if (!onUndefinedFunctionCall(fName)){
				// skip to end
				currentInstructionIndex = scriptInstructions[currentFunctionName].length;
			}
		}
	}

	/// sets the size of the variable-array. This is the first instruction in every function, that tells the max
	/// number of vars that the function has at a point
	void setVarsLength(QData[] args){
		currentFunctionVars.length = args[0].value!(integer);
	}

	// vars

	/// stores array of args that the current script-defined function was called with
	QData[] currentFunctionArgs;
	/// stores the result of the last script-defined function
	QData currentFunctionResult;
	/// stores the name of the current script-defined function being executed
	string currentFunctionName;
	/// stores pointer to the index of the current instruction (in array scriptFunctions[FNAME]),
	/// the next instruction to execute can be set using `index = indexOfOtherCommand - 1;`
	uinteger currentInstructionIndex;

	/// stores compiled byte-code for each script-defined function, where index is the function name
	void delegate(QData[])[][string] scriptInstructions;
	/// stores arguments for the compiled byte-code for each fuction
	QData[][][string] scriptInstructionsArgs;

	/// the stack currently being used
	Stack!QData stack;

	/// stores all the variables, the index is the ID of the var
	QData[] currentFunctionVars;

	/// contains a list of all functions available in script, with their pointer
	QData delegate(QData[])[string] functionPointers;

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
		functionPointers = [
			// operators
			"_addInt": &operatorAddInt,
			"_addDble": &operatorAddDouble,
			"_subInt": &operatorSubtractInt,
			"_subDble": &operatorSubtractDouble,
			"_mulInt": &operatorMultiplyInt,
			"_mulDble": &operatorMultiplyDouble,
			"_divInt": &operatoDivideInt,
			"_divDbl": &operatorDivideDouble,
			"_modInt": &operatorModInt,
			"_modDbl": &operatorModDouble,
			"_concat": &operatorConcatenate,
			// array functions
			"getLength": &getArrayLength,
			"setLength": &setArrayLength,
			// get function args
			"getArgs": &getFunctionArgs,
			// set result
			"setResult": &setFunctionReturn
		];
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
			// copy the previous stack, previous function's vars, previous function's index, args, and result
			Stack!QData prevStack = stack;
			QData[] prevFunctionVars = currentFunctionVars.dup;
			uinteger prevIndex = currentInstructionIndex;
			QData[] prevFunctionArgs = currentFunctionArgs.dup;
			QData prevFunctionResult = currentFunctionResult;
			string prevFunctionName = currentFunctionName;
			// prepare a new stack, empty the vars, set args
			stack = new Stack!QData;
			currentFunctionVars = [];
			currentFunctionArgs = args.dup;
			currentFunctionName = fName;
			// start executing instruction, one by one
			auto byteCode = scriptInstructions[fName];
			auto byteCodeArgs = scriptInstructionsArgs[fName];
			for (currentInstructionIndex = 0; currentInstructionIndex < byteCode.length; currentInstructionIndex ++){
				try{
					byteCode[currentInstructionIndex](byteCodeArgs[currentInstructionIndex]);
				}catch (Exception e){
					if (!onRuntimeError(RuntimeError(fName, currentInstructionIndex, e.msg))){
						// break :(
						break;
					}
				}
			}
			QData result = currentFunctionResult;
			// destroy stack
			.destroy(stack);
			// restore previous state
			stack = prevStack;
			currentInstructionIndex = prevIndex;
			currentFunctionVars = prevFunctionVars;
			currentFunctionArgs = prevFunctionArgs;
			currentFunctionResult = prevFunctionResult;
			currentFunctionName = prevFunctionName;
			// return the result
			return result;
		}else{
			throw new Exception("function '"~fName~"' is not defined in the script");
		}
	}
}