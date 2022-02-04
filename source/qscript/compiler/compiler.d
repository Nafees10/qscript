module qscript.compiler.compiler;

import utils.misc;
import utils.ds;

import std.conv : to;

debug{import std.stdio;}

private shared static this(){
	ERROR_EXPLAIN_STRING = [
		CompileError.Type.TokenInvalid : "unidentified token, cannot read further",
	];
}

/// Visibility specifiers
package enum Visibility{
	/// Accessible only inside parent namespace
	Private,
	/// Accessible outside namespace as well
	Public
}

/// Stores explanations for CompileError.Type  
/// `$` character is replaced by a detail that can be specified in CompileError.details
private string[CompileError.Type] ERROR_EXPLAIN_STRING;
/// default script name
package const string DEFAULT_SCRIPT_NAME = "QSCRIPT_SCRIPT";
/// default namespace name
package const string DEFAULT_NAMESPACE = "this";
/// default visibility
package const Visibility DEFAULT_VISIBILITY = Visibility.Private;

/// Data type names
package enum TYPENAME : string{
	VOID = "void",
	INT = "int",
	FLOAT = "float",
	CHAR = "char",
	BOOL = "bool",
}

/// unescapes a string. the string must be provided with surrounding quotes stripped
/// 
/// Returns: unescaped string
package char[] strUnescape(string str){
	uint i, shift;
	char[] r;
	r.length = str.length;
	while (i + shift < str.length && i < r.length){
		if (str[i + shift] == '\\'){
			shift ++;
			if (i + shift < str.length){
				r[i] = charUnescape(str[i + shift]);
				r.length --;
			}
		}else
			r[i] = str[i + shift];
		i ++;
	}
	return r;
}
/// 
unittest{
	string s = "t\\\"bcd\\\"\\t\\\\";
	assert(strUnescape(s) == "t\"bcd\"\t\\", strUnescape(s));
}

/// Returns: unescaped character, for a character `c` when used as `\c`
package char charUnescape(char c){
	switch (c){
		case 't':	return '\t';
		case 'n':	return '\n';
		case 'b':	return '\b';
		default:	return c;
	}
}

/// compilation error
struct CompileError{
	/// Possible types of errors
	enum Type{
		TokenInvalid,
	}
	/// type of this error
	Type type;
	/// `[line number, column number]`
	uint[2] where;
	/// details
	string[] details;
	/// the final message. set this to `""` if modifying the struct
	string message;
	/// constructor
	this(Type type, uint[2] where = [0,0], string[] details = []){
		this.type = type;
		this.where = where;
		this.details = details;
	}
	/// Returns: a string representation of this error
	string toString(){
		if (message.length || type !in ERROR_EXPLAIN_STRING ||
		!ERROR_EXPLAIN_STRING[type].length)
			return message;
		char[] errStr;
		errStr = cast(char[])"line:"~where[0].to!string~','~where[1].to!string~' ';
		uint i = cast(uint)errStr.length;
		errStr ~= ERROR_EXPLAIN_STRING[type];
		foreach (detail; details){
			while (i < errStr.length){
				if (errStr[i] == '$'){
					errStr = errStr[0 .. i] ~ detail ~ (i + 1 < errStr.length ? errStr[i + 1 .. $] : []);
					i += detail.length;
					break;
				}
				i++;
			}
		}
		return message = cast(string)errStr;
	}
}
