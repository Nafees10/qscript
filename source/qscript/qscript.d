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

// TODO add the QScript class
