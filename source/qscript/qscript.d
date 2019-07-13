/++
Contains everything needed to run QScript scripts.
+/
module qscript.qscript;

import utils.misc;
import utils.lists;
import qscript.compiler.compiler;
import qscript.compiler.misc : encodeString;
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
				return "s\""~encodeString(this.strVal)~'"';
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

// TODO add the QScript class
