module qscript.compiler.syncheck;

import utils.lists;
import utils.misc;
import qscript.compiler.tokengen;
import qscript.compiler.misc;

/// To identify how "deep" into the script it is
private enum ScopeLevel{
	Script,
	FunctionDefinition,
	FunctionCall,
	IfWhileStatement,
	BlockOfStatements,
}
/// Used to represent "set-of-tokens"
private enum TokenSets{
	Statements,
	Arguments,
	FunctionDefinitions,
}

/// Used by syntax checking functions to match TokenTypes
/// Returns true if the types matched, else, false
/// 
/// `tokens` is the TokenList which has to be checked
/// `types` is the TokenType[] containing types to match against
/// `startIndex` is index in `tokens` from which checking will start, tokens before that index are ignored
private bool matchTokenTypes(TokenList tokens, TokenType[] types, uinteger startIndex){
	bool hasError = false;
	// first make sure there are enough tokens
	if (tokens.tokens.length - (startIndex + 1) >= types.length){
		for (uinteger i = 0; i < types.length; i ++){
			if (tokens.tokens[startIndex + i].type != types[i]){
				// not matching
				compileErrors.append(CompileError(tokens.getTokenLine(startIndex + i), "syntax error, unexpected token"));
				hasError = true;
			}
		}
	}else{
		compileErrors.append(CompileError(tokens.getTokenLine(startIndex), "unexpected end-of-file"));
		hasError = true;
	}
	return !hasError;
}


/// Checks a function (definition) for syntax errors
/// Adds error, if any, to misc.compileErrors
/// Returns the number of tokens occupied by the block, this number can be wrong in case there was an error
/// 
/// tokens is the TokenList containing the whole script's tokens
/// index is the index of the first token for to-be-checked
private uinteger checkFunctionDefinition(TokenList tokens, uinteger index){
	TokenType[] expectedTypes = [TokenType.Identifier, TokenType.BlockStart];
	matchTokenTypes(tokens, expectedTypes, index);
	// no need to check {} brackets, checkBlock will do that
	return expectedTypes.length + checkBlock(tokens, index + 1);
}

/// Checks a Function call for syntax errors
/// Adds error, if any, to misc.compileErrors
/// Returns the number of tokens occupied by the block, this number can be wrong in case there was an error
/// 
/// tokens is the TokenList containing the whole script's tokens
/// index is the index of the first token for to-be-checked
private uinteger checkFunctionCall(TokenList tokens, uinteger index){
	TokenType[] expectedTypes = [TokenType.Identifier, TokenType.ParanthesesOpen];
	matchTokenTypes(tokens, expectedTypes, index);
	// no need to check for brackets closing, checkArguments does that
	return expectedTypes.length + checkFunctionCallArgs(tokens, index + 1);
}

/// Checks a Function call for syntax errors
/// Adds error, if any, to misc.compileErrors
/// Returns the number of tokens occupied by the block, this number can be wrong in case there was an error
/// 
/// tokens is the TokenList containing the whole script's tokens
/// index is the index of the first token for to-be-checked
private uinteger checkFunctionCallArgs(TokenList tokens, uinteger index){

}

/// Checks an if/while statement for syntax errors
/// Adds error, if any, to misc.compileErrors
/// Returns the number of tokens occupied by the block, this number can be wrong in case there was an error
/// 
/// tokens is the TokenList containing the whole script's tokens
/// index is the index of the first token for to-be-checked
private uinteger checkIfWhileStatement(TokenList tokens, uinteger index){
	// make sure it's an if/while statement
	if (tokens.tokens[index].token == "if" || tokens.tokens[index].token == "while"){
		// continue with the checks
		TokenType[] expectedTypes = [TokenType.Identifier, TokenType.ParanthesesOpen];
		if (matchTokenTypes(tokens, expectedTypes, index)){
			// checks if brackets are properly closed
			uinteger brackEnd = bracketPos(tokens, index + 1);
			if (brackEnd >= 0){
				// make sure it's followed by a	block
				if (tokens.tokens[brackEnd + 1].type == TokenType.BlockStart){
					//check if block has closing bracket, return the number of tokens
					return (tokens.bracketPos(brackEnd + 1) - index) + 1;
				}
			}
		}
	}else{
		compileErrors.append(CompileError(tokens.getTokenLine(index), "not an if/while statement"));
	}
	return 0;
}

/// Checks a block-of-code (i.e `{this}`) for syntax errors
/// Adds error, if any, to misc.compileErrors
/// Returns the number of tokens occupied by the block, this number can be wrong in case there was an error
/// 
/// tokens is the TokenList containing the whole script's tokens
/// index is the index of the first token for to-be-checked
private uinteger checkBlock(TokenList tokens, uinteger index){
	// make sure there are curly brackets
	if (tokens.tokens[index].type == TokenType.BlockStart){
		// check if it is properly closed
		uinteger blockEnd = tokens.bracketPos(index);
		if (blockEnd >= 0){
			// check each and every statement
			for (uinteger i = index + 1; i < tokens.tokens.length; i ++){
				// here is where the whole syntax is checked

			}

		}//else{} not required coz bracketPos itself appends an error in case on one
		return (blockEnd - index) + 1; // +1 for the first bracket
	}else{
		compileErrors.append(CompileError(tokens.getTokenLine(index), "'{' expected"));
		return 0;
	}
}

package void checkSyntax(TokenList tokens){
	TokenSets[][ScopeLevel] scopeTokenSets = [
		ScopeLevel.Script: [
			TokenSets.FunctionDefinitions
		],
		ScopeLevel.FunctionDefinition: [
			TokenSets.Statements
		],
		ScopeLevel.FunctionCall: [
			TokenSets.Arguments
		],
		ScopeLevel.IfWhileStatement: [
			TokenSets.Arguments, TokenSets.Statements
		],
		ScopeLevel.BlockOfStatements: [
			TokenSets.Statements
		]
	];

}