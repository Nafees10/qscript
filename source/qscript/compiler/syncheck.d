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


/// Checks a function (definition) for syntax errors
/// Adds error, if any, to misc.compileErrors
/// Returns the number of tokens occupied by the function
/// 
/// tokens is he TokenList containing the whole script's tokens
/// index is the index of the first token for to-be-checked
private uinteger checkFunctionDefinition(TokenList tokens, uinteger index){
	TokenType[] expectedTokens = [TokenType.Identifier, TokenType.BlockStart];// afer this comes the function body which will be checked by `checkBlock`
	bool hasError = false;
	// make sure that expectedTokens match
	for (uinteger i = 0; i < expectedTokens.length; i ++){
		if (tokens.tokens[index + i].type != expectedTokens[i]){
			//add error, and break
			compileErrors.append(CompileError(tokens.getTokenLine(index + i), "syntax error, unexpected token"));
			hasError = true;
		}
	}
	// check if brackets are properly closed, if not, the `bracketPos` will itself put an error in `compileErrors`
	tokens.bracketPos(index + 1);
	return expectedTokens.length + checkBlock(tokens, index + 1);
}

/// Checks a Function call for syntax errors
/// Adds error, if any, to misc.compileErrors
/// Returns the number of tokens occupied by the function call
/// 
/// tokens is he TokenList containing the whole script's tokens
/// index is the index of the first token for to-be-checked
private uinteger checkFunctionCall(TokenList tokens, uinteger index){
	
}

/// Checks an if/while statement for syntax errors
/// Adds error, if any, to misc.compileErrors
/// Returns the number of tokens occupied by the statement
/// 
/// tokens is he TokenList containing the whole script's tokens
/// index is the index of the first token for to-be-checked
private uinteger checkIfWhileStatement(TokenList tokens, uinteger index){
	
}

/// Checks a block-of-code (i.e `{this}`) for syntax errors
/// Adds error, if any, to misc.compileErrors
/// Returns the number of tokens occupied by the block
/// 
/// tokens is he TokenList containing the whole script's tokens
/// index is the index of the first token for to-be-checked
private uinteger checkBlock(TokenList tokens, uinteger index){
	
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