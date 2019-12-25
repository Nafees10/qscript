/++
Contains everything needed to run QScript scripts.
+/
module qscript.qscript;

import utils.misc;
import utils.lists;
import qscript.compiler.bytecode;
import qscript.compiler.compiler;
import qscript.compiler.misc : encodeString;
import qscript.vm;
import std.stdio;
import std.conv:to;

/// to store data from script at runtime
public union QData{
	char charVal; /// character value
	uinteger uintVal; /// unsigned integer value
	integer intVal; /// integer value
	double doubleVal; /// double/float value
	QData[] arrayVal; /// array value
	char[] strVal;
	/// constructor
	/// data can be any of the type which it can store
	this (T)(T data){
		static if (is (T == string) || is (T == char[])){
			strVal = cast(char[])data;
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
	/// Returns: this QData as it would be written in byte code
	string toByteCode(DataType type){
		if (type.arrayDimensionCount > 0){
			char[] array = ['['];
			// the type of the elements
			DataType subType = type;
			subType.arrayDimensionCount --;
			// use recursion
			foreach (element; this.arrayVal){
				array ~= cast(char[])element.toByteCode(subType) ~ ',';
			}
			if (array.length == 1){
				array ~= ']';
			}else{
				array[array.length - 1] = ']';
			}
			return cast(string)array;
		}else{
			if (type.type == DataType.Type.Double){
				return "d"~to!string(this.doubleVal);
			}else if (type.type == DataType.Type.Integer){
				return "i"~to!string(this.intVal);
			}else if (type.type == DataType.Type.String){
				return "s\""~encodeString(cast(string)this.strVal)~'"';
			}else{
				return "NULL"; /// actually an error TODO do something about it
			}
		}
	}
}

/// To store information about a pre-defined function, for use at compile-time
alias Function = qscript.compiler.compiler.Function;

/// used to store data types for data at compile time
alias DataType = qscript.compiler.misc.DataType;

/// Used by compiler's functions to return error
alias CompileError = qscript.compiler.misc.CompileError;

/// QScript class. Use this to compile & execute scripts
class QScript{
private:
	/// the vm, obviously
	QVM _vm;
	/// addresses of external functions
	QVMFunction*[] _extFuncsPtr;
	/// declarations of external functions
	Function[] _extFuncs;
	/// stores the byte code for the script
	ByteCode _bytecode;
public:
	/// constructor
	///
	/// `externalFunctions` is the array of functions declarations that are to be made avaialable  
	/// `externalFunctionsPtr` is the pointers to those functions
	this(Function[] externalFunctions, QVMFunction[] externalFunctionsPtr){
		_extFuncs = externalFunctions.dup;
		_vm = new QVM(externalFunctionsPtr);
	}
	/// destructor
	~this(){
		.destroy(_vm);
		if (_bytecode){
			.destroy(_bytecode);
		}
	}
	/// loads & compiles a script
	///
	/// Returns: CompileError[] with length>0 if there are errors, with length=0 if no errors
	CompileError[] compile(string[] script){
		CompileError[] r;
		_bytecode = compileScript(script, _extFuncs, r);
		if (r.length == 0 && !_vm.loadByteCode(_bytecode)){
			throw new Exception("error loading bytecode");
		}
		return r;
	}
	/// Returns: a string representation of the compiled bytecode. Empty array if no bytecode compiled present (like if there was a compilation error)
	string[] byteCodeToString(){
		if (_bytecode){
			return _bytecode.tostring;
		}
		return [];
	}
	/// Executes a function from the script
	/// 
	/// Returns: what that function returns, or some random value if it didn't
	QData execute(uinteger funcId, QData[] args){
		QData*[] ptrs;
		ptrs.length = args.length;
		foreach (i, arg; args){
			ptrs[i] = &args[i];
		}
		QData* rPtr = _vm.execute(funcId, ptrs);
		return rPtr ? *rPtr : QData();
	}
}