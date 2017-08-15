module qscript.qscript;

import utils.misc;
import utils.lists;
//import qscript.compiler;
import std.stdio;
import std.conv:to;

public struct QData{
	enum Type{
		String,
		UnsignedInt,
		SignedInt,
		Double,
		Array,
		Undefined
	}
	private Type dataType = QData.Type.Undefined;
	union{
		string strVal;
		uinteger uintVal;
		integer intVal;
		double doubleVal;
		QData[] arrayVal;
	}
	/// changes the data contained by this struct
	@property auto value(T)(T val){
		static if (typeid(T) == typeid(string)){
			dataType = Type.String;
			strVal = val;
		}else static if (typeid(T) == typeid(uinteger)){
			dataType = Type.UnsignedInt;
			uintVal = val;
		}else static if (typeid(T) == typeid(integer)){
			dataType = Type.SignedInteger;
			intVal = val;
		}else static if (typeid(T) == typeid(double) || typeid(T) == typeid(float)){
			dataType = Type.Double;
			doubleVal = val;
		}else static if (typeid(T) == typeid(QData[])){
			dataType = Type.Array;
			arrayVal = val;
		}else{
			throw new Exception("attempting to store invalid data type in QData");
		}
	}
	/// retrieves the value stored by this struct
	@property auto value(T)(){
		/// make sure it is the correct type
		static if (typeid(T) == typeid(string)){
			return strVal;
		}else static if (typeid(T) == typeid(uinteger)){
			return uintVal;
		}else static if (typeid(T) == typeid(integer)){
			return intVal;
		}else static if (typeid(T) == typeid(double) || typeid(T) == typeid(float)){
			return doubleVal;
		}else static if (typeid(T) == typeid(QData[])){
			return arrayVal;
		}else{
			throw new Exception("attempting to retrieve invalid data type from QData");
		}
	}
	/// retrieves the type of data stored in this struct
	@property Type type(){
		return dataType;
	}
}

public abstract class QScript{
private:
	// operator functions
	// TODO write operator functions, and other basic functions

	// interpreter instructions
	// TODO write interpreter instructions

	// vars


public:
	this(){

	}
}