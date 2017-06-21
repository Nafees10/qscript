/+ This module converts script to tokens, and does basic syntax checking
 + 
 +/
module qscript.compiler.tokengen;

import utils.misc;
import utils.lists;
import std.conv:to;
import qscript.compiler.misc;
debug{
	import std.stdio;
}

/// First step in compilation
/// Converts the script into tokens, identifies the TokenType, returns the tokens in a `Token[]`
/// adds error to `misc.compilerErrors` in case of error, and returns empty array or null
package string[] toTokens(List!string script){
	LinkedList!Token tokens = new LinkedList!Token;
	LinkedList!CompileError errors = new LinkedList!CompileError;
	//First convert everything to 'tokens', TokenType will be set later
	for (uinteger lineno=0; lineno<till; lineno++){
		string line = script.read(i);
		for (uinteger i = 0, readFrom = 0; i < line.length; i ++){

		}
	}

	// now identify token types, only if there were no errors
	if (errors.count == 0){
		Token tmpToken;
		till = tokens.count;
		for (i=0; i<till; i++){
			token = tokens.read(i);
			if (token.token.isNum){
				//Numbers:
				token.type = TokenType.Number;
			}else if (token.token == "new"){
				//is a data type
				token.type = TokenType.VarDef;
			}else if (token.token.isIdentifier){
				//Identifiers & FunctionCall & FunctionCall
				token.type = TokenType.Identifier;
				if (i<till-1){
					tmpToken = tokens.read(i+1);
					if (tmpToken.token=="("){
						token.type = TokenType.FunctionCall;
					}else if (tmpToken.token=="{"){
						token.type = TokenType.FunctionDef;
					}
				}
			}else if (token.token.isOperator){
				//Operator
				token.type = TokenType.Operator;
			}else if (token.token[0]=='"'){
				//string
				token.type = TokenType.String;
			}else if (token.token.length == 1){
				//comma, semicolon, brackets
				switch (token.token[0]){
					case ',':
						token.type = TokenType.Comma;
						break;
					case ';':
						token.type = TokenType.StatementEnd;
						break;
					default:
						if (isBracketOpen(token.token[0])){
							token.type = TokenType.BracketOpen;
						}else if (isBracketClose(token.token[0])){
							token.type = TokenType.BracketClose;
						}
						break;
				}
			}
			tokens.set(i,token);
		}
	}

	if (errors.count == 0){
		return false;
	}else{
		return true;
	}
}

/*
Interpreter instructions:
psh - push element(s) to stack
clr - empty the stack
exf - execute function, don't push return to stack. take fName from stack, and argC from given args
exa - execute function, push return to stack. take fName from stack, and argC from given args
jmp - jump to another index, and start execution from there, used in loops, and if
stv - set a variable's value, val name=arg, new value = from stack
rtv - push a variable's value to stack
Rules:
An instruction can recieve one argument!
AND: right before jmp, clr must be called, to prevent a possible mem-leak
*/