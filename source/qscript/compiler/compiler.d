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
/// default namespace name
string DEFAULT_NAMESPACE = "this";
/// default visibility
const Visibility DEFAULT_VISIBILITY = Visibility.Private;

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
