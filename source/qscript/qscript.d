/++
Contains everything needed to run QScript scripts.
+/
module qscript.qscript;

import utils.misc;
import utils.lists;
import qscript.compiler.compiler;
import qscript.vm;
import std.stdio;
import std.conv:to;

/// to store data from script at runtime
public union QData{
	string strVal; /// string value
	integer intVal; /// integer value
	double doubleVal; /// double/float value
	QData[] arrayVal; /// array value
	/// constructor
	/// data can be any of the type which it can store
	this (T)(T data){
		static if (is (T == string)){
			strVal = data;
		}else static if (is (T == int) || is (T == uint) || is (T == long) || is (T == ulong)){
			intVal = data;
		}else static if (is (T == double)){
			doubleVal = data;
		}else static if (is (T == QData[]) || is (T == void[])){
			arrayVal = cast(QData[])data;
		}else{
			throw new Exception("cannot store "~T.stringof~" in QData");
		}
	}
}

/// To store information about a pre-defined function, for use at compile-time
alias Function = qscript.compiler.compiler.Function;

/// used to store data types for data at compile time
alias DataType = qscript.compiler.misc.DataType;

/// Used by compiler's functions to return error
alias CompileError = qscript.compiler.misc.CompileError;


/// The abstract class that makes QScript usable.
/// 
/// provides interface to the compiler as well
/// 
/// Usage is shown in `demos/demo.d`
public abstract class QScript{
private:
	/// contains a list of all external-functions available in script, with their pointer
	QData delegate(QData[])[string] extFunctionPointers;
	/// contains a list of all external-functions with their return types and argument types
	Function[] extFunctionTypes;
	/// the VM used by this class
	QScriptVM qvm;
	/// handles calling external functions
	QData onExternalCall(string name, QData[] args){
		if (name in extFunctionPointers){
			return extFunctionPointers[name](args);
		}
		if (!onUndefinedFunctionCall(name)){
			qvm.breakCurrent();
		}
		return QData();
	}
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

public:
	alias RuntimeError = qscript.vm.QScriptVM.RuntimeError;
	/// alias to compiler.misc.CompileError
	alias CompileError = qscript.compiler.misc.CompileError;
	/// constructor
	this (){
		qvm = new QScriptVM();
		qvm.onExternalCall = &onExternalCall;
		qvm.onRuntimeError = &onRuntimeError;
	}
	/// destructor
	~this(){
		.destroy(qvm);
	}

	/// compiles and loads a script for execution
	/// 
	/// `script` is the script to load, with each line as a separate element of the array, without the trailing newline character.
	/// 
	/// Returns: array of compile errors. or empty array in case of no errors
	/// 
	/// Throws: Exception if there was an error loading the byte code
	CompileError[] loadScript(string[] script){
		CompileError[] errors;
		/*string[] byteCode = compileQScriptToByteCode(script.dup, extFunctionTypes, errors); TODO
		string err = qvm.loadByteCode(byteCode); TODO
		if (err.length > 0){
			throw new Exception ("error loading byte code: "~err);
		}*/
		return errors;
	}

	/// compiles and loads a byte code for execution
	/// 
	/// `byteCode` is the byte code to load, with each line as a separate element, without trailing newline char
	/// 
	/// Returns: any error that occurred, or zero-length string if no error occurred
	string loadByteCode(string[] byteCode){
		return qvm.loadByteCode(byteCode.dup);
	}

	/// compiles a script into byte code, returns the byte code
	/// 
	/// `script` is the script to compile, each line in a separate element, without the trailing '\n'
	/// `errors` is the array to put compilation errors, if any, in
	string[] compileScript(string[] script, ref CompileError[] errors){
		//return compileQScriptToByteCode(script.dup, extFunctionTypes, errors); TODO
		return [];
	}

	/// executes a script defined function
	/// 
	/// Returns: what ever the function returned, or `QData()` if it didnt return anything
	/// 
	/// Throws: Exception in case the function doesn't exist
	QData execute(string name, QData[] args){
		return qvm.executeScriptFunction(name, args.dup);
	}
}
