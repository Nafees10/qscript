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
private uinteger checkFunctionDefinition(TokenList tokens){
	
}

/// Checks a Function call for syntax errors
/// Adds error, if any, to misc.compileErrors
/// Returns the number of tokens occupied by the function call
private uinteger checkFunctionCall(TokenList tokens){
	
}

/// Checks an if/while statement for syntax errors
/// Adds error, if any, to misc.compileErrors
/// Returns the number of tokens occupied by the statement
private uinteger checkIfWhileStatement(TokenList tokens){
	
}

/// Checks a block-of-code (i.e `{this}`) for syntax errors
/// Adds error, if any, to misc.compileErrors
/// Returns the number of tokens occupied by the block
private uinteger checkBlock(TokenList tokens){
	
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