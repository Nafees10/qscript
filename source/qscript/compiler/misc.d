module qscript.compiler.misc;

import utils.misc;
import utils.lists;

import std.range;

/// An array containing all chars that an identifier can contain
package const char[] IDENT_CHARS = iota('a', 'z'+1).array~iota('A', 'Z'+1).array~iota('0', '9'+1).array~[cast(int)'_'];
package const string[] KEYWORDS = ["function", "var"];
/// An array containing another array conatining all operators
/// Index0 for array0 means the operators are of highest precedence
package const string[][] OPERATORS = [
	["/", "*", "+", "-", "%", "~"],
	["<", ">", "==", "<=", ">="],
	["="]
];

/// Used by compiler's functions to return error
public struct CompileError{
	string msg; /// The error stored in a string
	uinteger lineno; /// The line number on which the error is
	this(uinteger lineNumber, string errorMessage){
		lineno = lineNumber;
		msg = errorMessage;
	}
}

/// All compilation errors are stored here
package LinkedList!CompileError compileErrors;

/// Each token is stored as a `Token` with the type and the actual token
package struct Token{
	/// Specifies type of token
	/// 
	/// used only in `compiler.tokengen`
	enum Type{
		String,/// That the token is: `"SOME STRING"`
		Number,/// That the token a number, float also included
		Identifier,/// That the token is an identifier. i.e token is a variable name or a function name.  For a token to be marked as Identifier, it doesn't need to be defined in `new()`
		Operator,/// That the token is an operator, like `+`, `==` etc
		Keyword,/// A `function` or `var` ...
		Comma,/// That its a comma: `,`
		StatementEnd,/// A semicolon
		ParanthesesOpen,/// `(`
		ParanthesesClose,/// `)`
		IndexBracketOpen,/// `[`
		IndexBracketClose,///`]`
		BlockStart,///`{`
		BlockEnd,///`}`
	}
	Type type;/// type of token
	string token;/// token
	this(Type tType, string tToken){
		type = tType;
		token = tToken;
	}
}
/// To store Tokens with Types where the line number of each token is required8
package struct TokenList{
	Token[] tokens; /// Stores the tokens
	uinteger[] tokenPerLine; /// Stores the number of tokens in each line
	/// Returns the line number a token is in by usin the index of the token in `tokens`
	/// 
	/// The returned value is the line-number, not index, it starts from 1, not zero
	uinteger getTokenLine(uinteger tokenIndex){
		uinteger i = 0, chars = 0;
		tokenIndex ++;
		for (; chars < tokenIndex && i < tokenPerLine.length; i ++){
			chars += tokenPerLine[i];
		}
		return i;
	}
}

/// Used to get index of opening/closing bracket using index of opposite bracket
/// In case brackets order is wrong; appends error to `compileErrors` and returns -2
/// In case bracket is not closed; appends error to `compileErrors` and returns -1
/// otherwise, returns index of the opposite bracket
/// 
/// `start` is the index of the bracket to get the opposite of
/// `forward`, if true, searches for the closing bracket, else, for the opening bracket
package integer bracketPos(TokenList tokens, uinteger start, bool forward = true){
	enum BracketType{
		Round,
		Square,
		Block
	}
	Stack!BracketType bracks = new Stack!BracketType;
	BracketType curType;
	uinteger i = start;
	BracketType[Token.Type] brackOpenIdent = [
		Token.Type.ParanthesesOpen: BracketType.Round,
		Token.Type.IndexBracketOpen: BracketType.Square,
		Token.Type.BlockStart: BracketType.Block
	];
	BracketType[Token.Type] brackCloseIdent = [
		Token.Type.ParanthesesClose: BracketType.Round,
		Token.Type.IndexBracketClose: BracketType.Square,
		Token.Type.BlockEnd:BracketType.Block
	];
	if (forward){
		for (uinteger lastInd = tokens.tokens.length-1; i<tokens.tokens.length; i++){
			if (tokens.tokens[i].type in brackOpenIdent){
				bracks.push(brackOpenIdent[tokens.tokens[i].type]);
			}else if (tokens.tokens[i].type in brackCloseIdent){
				if (bracks.pop != brackCloseIdent[tokens.tokens[i].type]){
					compileErrors.append(CompileError(tokens.getTokenLine(i),
							"brackets order is wrong; first opened must be last closed"));
					i = -1;
					break;
				}
			}
			if (bracks.count == 0){
				break;
			}
			if (i == lastInd){
				// no bracket ending
				i = -2;
				compileErrors.append(CompileError(tokens.getTokenLine(start), "bracket not closed"));
				break;
			}
		}
	}else{
		for (uinteger lastInd = 0; i>=0; i--){
			if (tokens.tokens[i].type in brackCloseIdent){
				bracks.push(brackCloseIdent[tokens.tokens[i].type]);
			}else if (tokens.tokens[i].type in brackOpenIdent){
				if (bracks.pop != brackOpenIdent[tokens.tokens[i].type]){
					compileErrors.append(CompileError(tokens.getTokenLine(i),
							"brackets order is wrong; first opened must be last closed"));
					i = -2;
					break;
				}
			}
			if (bracks.count == 0){
				break;
			}
			if (i == lastInd){
				// no bracket ending/opening
				i = -1;
				compileErrors.append(CompileError(tokens.getTokenLine(start), "bracket not closed/opened"));
				break;
			}
		}
	}

	.destroy(bracks);
	return i;
}