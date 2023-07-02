module qscript.compiler;

import utils.misc;
import utils.ds;

import std.conv : to;
import std.traits;

import qscript.tokens;

debug import std.stdio;

/// default script name
package const string DEFAULT_SCRIPT_NAME = "QSCRIPT_SCRIPT";
/// default namespace name
package const string DEFAULT_NAMESPACE = "this";
/// maximum number of errors
package const uint ERRORS_MAX = 20;

/// Data type names
package enum TYPENAME : string{
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
/// Possible types of errors
public enum ErrorType{
	@("")																						None,
	@("unidentified token, cannot read further")		TokenInvalid,
	@("unexpected token, cannot read further")			TokenUnexpected,
	@("Expected $")																	Expected,
	@("Expected $ found $")													ExpectedAFoundB,
	@("Expected 1 character inside ''")							CharLengthInvalid,
	@("Unexpected end of file")											UnexpectedEOF,
	@("Syntax Error")																SyntaxError,
}

/// error explain format string
private string errorExplainFormat(ErrorType type){
	switch (type){
		static foreach (member; EnumMembers!ErrorType){
			case member:
				return getUDAs!(member, string)[0];
		}
		default:
			return null;
	}
}

/// construct error explanation string
private string errorExplainStr(ErrorType type, uint line, uint col, string[] details){
	string format = errorExplainFormat(type);
	if (format is null)
		return null;
	char[] errStr;
	errStr = cast(char[]) line.to!string ~ ',' ~ col.to!string ~ ": ";
	uint i = cast(uint)errStr.length;
	errStr ~= format;

	foreach (detail; details){
		while (i < errStr.length){
			if (errStr[i] == '$'){
				errStr = errStr[0 .. i] ~ detail ~
					(i + 1 < errStr.length ? errStr[i + 1 .. $] : []);
				i += detail.length;
				break;
			}
			i++;
		}
	}
	return cast(string)errStr;
}

/// A value or a compiler error
public struct CompileResult(T){
	bool isError;
	union{
		T value;
		CompileError error;
	}
	@disable this();
	this(T value){
		this.value = value;
		this.isError = false;
	}
	this(CompileError error){
		this.error = error;
		this.isError = true;
	}
	bool opCast(To : bool)() const pure {
		return !isError;
	}
}

/// A compiler error
public struct CompileError{
	ErrorType type = ErrorType.None;
	uint line, col;
	string msg;

	/// constructor
	this(ErrorType type, uint line, uint col, string[] details = []){
		this.type = type;
		this.line = line;
		this.col = col;
		msg = errorExplainStr(type, line, col, details);
	}

	/// ditto
	this(ErrorType type, Token tok, string[] details = []){
		this.type = type;
		this.line = tok.lineno;
		this.col = tok.colno;
		msg = errorExplainStr(type, line, col, details);
	}

	/// ditto
	/// syntax error
	this(Token tok){
		this.type = ErrorType.SyntaxError;
		this.line = tok.lineno;
		this.col = tok.colno;
		msg = errorExplainStr(type, line, col, []);
	}
}
