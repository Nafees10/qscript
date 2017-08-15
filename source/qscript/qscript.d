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
		static if (typeid(T) == typeid(string)){
			dataType = Type.String;
			strVal = val;
		}else static if (typeid(T) == typeid(integer)){
			dataType = Type.Integer;
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
	@property auto value(QData T)(){
		static if (T == QData.Type.String){
			return strVal;
		}else static if (T == QData.Type.Integer){
			return intVal;
		}else static if (T == QData.Type.Double){
			return doubleVal;
		}else static if (T == QData.Type.Array){
			return arrayVal;
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
		this.value = val;
	}
}

public abstract class QScript{
private:
	// operator functions
	// TODO write operator functions, and other basic functions
	enum OperatorType{
		Divide,
		Multiply,
		Add,
		Subtract,
		Mod,
		Concatenate,
	}
	QData numeralOperator(OperatorType T)(QData[] args){
		QData r;
		// identify the correct type, integer, or double
		if (args[0].type == QData.Type.SignedInt){

		}
		static if (T == OperatorType.Divide){

		}
	}
	// interpreter instructions
	// TODO write interpreter instructions

	// vars


public:
	this(){

	}
}