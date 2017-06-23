module qscript.compiler.misc;

import utils.misc;
import utils.lists;

import std.range;

/// An array containing all chars that an identifier can contain
package const char[] IDENT_CHARS = iota('a', 'z'+1).array~iota('A', 'Z'+1).array~iota('0', '9'+1).array~[cast(int)'_'];
/// An array containing another array conatining all operators
/// Index0 for array0 means the operators are of highest precedence
package const string[][] OPERATORS = [
	["/", "*", "+", "-", "%", "~"],
	["<", ">", "==", "<=", ">="],
	["="]
];

/// Used by compiler's functions to return error
package struct CompileError{
	string msg; /// The error stored in a string
	uinteger lineno; /// The line number on which the error is
	this(uinteger lineNumber, string errorMessage){
		lineno = lineNumber;
		msg = errorMessage;
	}
}

/// All compilation errors are stored here
package LinkedList!CompileError compileErrors;

/// Specifies type of token
/// 
/// used only in `compiler.tokengen`
package enum TokenType{
	String,/// That the token is: `"SOME STRING"`
	Number,/// That the token a number, float also included
	Identifier,/// That the token is an identifier. i.e token is a variable name or a function name.  For a token to be marked as Identifier, it doesn't need to be defined in `new()`
	Operator,/// That the token is an operator, like `+`, `==` etc
	Comma,/// That its a comma: `,`
	StatementEnd,/// A semicolon
	ParanthesesOpen,/// `(`
	ParanthesesClose,/// `)`
	IndexBracketOpen,/// `[`
	IndexBracketClose,///`]`
	BlockStart,///`{`
	BlockEnd,///`}`
}

/// Each token is stored as a `Token` with the type and the actual token
package struct Token{
	TokenType type;/// type of token
	string token;/// token
	this(TokenType tType, string tToken){
		type = tType;
		token = tToken;
	}
}
/// Returns the index of the quotation mark that ends a string
/// 
/// Returns -1 if not found
package integer strEnd(string s, uinteger i){
	for (i++;i<s.length;i++){
		if (s[i]=='\\'){
			i++;
			continue;
		}else if (s[i]=='"'){
			break;
		}
	}
	if (i==s.length){i=-1;}
	return i;
}