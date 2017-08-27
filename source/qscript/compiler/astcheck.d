﻿module qscript.compiler.astcheck;

import qscript.compiler.ast;
import qscript.compiler.misc;

import utils.lists;
import utils.misc;

/// Struct to check ASTs generated by ast.d
package struct ASTCheck{
	/// contains a list of currently available vars
	LinkedList!string definedVars;
	/// contains a list of vars already available
	const static string[] keyVars = [
		"args",
		"result"
	];
	/// contains types of nodes that return some data, like functionCall, stringLiteral...
	const static ASTNode.Type[] dataNodeTypes = [
		ASTNode.Type.FunctionCall,
		ASTNode.Type.NumberLiteral,
		ASTNode.Type.Operator,
		ASTNode.Type.StaticArray,
		ASTNode.Type.StringLiteral,
		ASTNode.Type.Variable
	];
	/// checks a script, and all subNodes, returns true if no error, otherwise, error is appended to misc.compileErrors
	bool checkScript(ASTNode script){
		bool r = true;
		// make sure all subNodes are functions, and check those functions
		foreach (node; script.subNodes){
			if (node.type != ASTNode.Type.Function){
				// error
				compileErrors.append(CompileError(node.lineno, "function definition expected"));
				r = false;
				// not a "fatal" error, so continue checking
			}else{
				// no error, but need to check inside the function
				r = checkFunction(node);
			}
		}
		return r;
	}

	/// identifies and checks an ASTNode
	private bool checkNode(ASTNode node){
		// check the type, call the function
		if (node.type == ASTNode.Type.Assign){
			return checkAssignment(node);
		}else if (node.type == ASTNode.Type.Block){
			return checkBlock(node);
		}else if (node.type == ASTNode.Type.Function){
			return checkFunction(node);
		}else if (node.type == ASTNode.Type.FunctionCall){
			return checkFunctionCall(node);
		}else if (node.type == ASTNode.Type.IfStatement || node.type == ASTNode.Type.WhileStatement){
			return checkIfWhileStatement(node);
		}else if (node.type == ASTNode.Type.Operator){
			return checkOperator(node);
		}else if (node.type == ASTNode.Type.VarDeclare){
			return checkVarDeclare(node);
		}else if (node.type == ASTNode.Type.NumberLiteral){
			return true;
		}else if (node.type == ASTNode.Type.StringLiteral){
			return true;
		}else if (node.type == ASTNode.Type.StaticArray){
			return checkStaticArray(node);
		}else if (node.type == ASTNode.Type.Variable){
			return checkVariable(node);
		}else{
			throw new Exception("checkNode called with unsupported ASTNode.Type");
		}
	}

	/// checks a function definition
	private bool checkFunction(ASTNode functionNode){
		// make sure it's a function
		if (functionNode.type == ASTNode.Type.Function){
			// ok
			// make sure there's only 1 subNode, and it's a block
			if (functionNode.subNodes.length != 1 || functionNode.subNodes[0].type != ASTNode.Type.Block){
				compileErrors.append(CompileError(functionNode.lineno, "invalid function definition"));
				return false;
			}else{
				// check it
				return checkBlock(functionNode.subNodes[0]);
			}
		}else{
			compileErrors.append(CompileError(functionNode.lineno, "function definition expected"));
			return false;
		}
	}

	/// checks a block
	private bool checkBlock(ASTNode block){
		// make sure it's a block
		if (block.type == ASTNode.Type.Block){
			foreach (statement; block.subNodes){
				if (statement.type == ASTNode.Type.FunctionCall){
					return checkFunctionCall(statement);
				}else if (statement.type == ASTNode.Type.Assign){
					return checkAssignment(statement);
				}else if (statement.type == ASTNode.Type.Block){
					return checkBlock(statement);
				}else if (statement.type == ASTNode.Type.IfStatement || statement.type == ASTNode.Type.WhileStatement){
					return checkIfWhileStatement(statement);
				}else if (statement.type == ASTNode.Type.VarDeclare){
					return checkVarDeclare(statement);
				}else{
					// not a valid statement
					compileErrors.append(CompileError(statement.lineno, "not a valid statement"));
					return false;
				}
			}
			return true;
		}else{
			compileErrors.append(CompileError(block.lineno, "block expected"));
			return false;
		}
	}

	/// checks a functionCall
	private bool checkFunctionCall(ASTNode fCall){
		// make sure it's a fCall
		if (fCall.type == ASTNode.Type.FunctionCall){
			// ok, make sure it has only 1 subNode, that is Args
			if (fCall.subNodes.length != 1 || fCall.subNodes[0].type != ASTNode.Type.Arguments){
				// error :(
				compileErrors.append(CompileError(fCall.lineno, "invalid function call"));
				return false;
			}else{
				// check the args
				bool r = true;
				foreach (arg; fCall.subNodes[0].subNodes){
					// make sure it's of correct type
					if (dataNodeTypes.hasElement(arg.type)){
						// type's ok, need to check the node
						r = checkNode(arg);
					}
				}
				return r;
			}

		}else{
			compileErrors.append(CompileError(fCall.lineno, "function call expected"));
			return false;
		}
	}

	/// checks an assignment statement
	private bool checkAssignment(ASTNode assign){
		// make sure it's an assignment
		if (assign.type == ASTNode.Type.Assign){
			// ok, check the if the var exists, and check the val, and there should be only s subNodes
			bool r = true;
			if (assign.subNodes.length != 2 || assign.subNodes[0].type != ASTNode.Type.Variable){
				compileErrors.append(CompileError(assign.lineno, "invalid assignment statement"));
				r = false;
				// not fatal, still need to check the val, but skip the var
			}else{
				// check the var
				if (keyVars.hasElement(assign.subNodes[0].data) || definedVars.hasElement(assign.subNodes[0].data)){
					r = checkVariable(assign.subNodes[0]);
				}else{
					// var wasn't defined
					compileErrors.append(CompileError(assign.subNodes[0].lineno,
							"variable `"~assign.subNodes[0].data~"` not defined"));
					r = false;
				}
			}
			// check the val
			if (dataNodeTypes.hasElement(assign.subNodes[1].type)){
				r = checkNode(assign.subNodes[1]);
			}else{
				compileErrors.append(CompileError(assign.lineno, "invalid assignment statement"));
				r = false;
			}
			return r;
		}else{
			compileErrors.append(CompileError(assign.lineno, "assignment statement expected"));
			return false;
		}
	}

	/// checks an if or while statement
	private bool checkIfWhileStatement(ASTNode ifStatement){
		// make sure it's an if statement
		if (ifStatement.type == ASTNode.Type.IfStatement || ifStatement.type == ASTNode.Type.WhileStatement){
			// ok
			// check that there are only 2 subNodes, the condition, and the block
			if (ifStatement.subNodes.length != 2 || ifStatement.subNodes[1].type != ASTNode.Type.Block){
				compileErrors.append(CompileError(ifStatement.lineno, "invalid if/while statement"));
				// that's a wierd error, so it's fatal
				return false;
			}
			bool r = true;
			// check the condition's type
			if (dataNodeTypes.hasElement(ifStatement.subNodes[0].type)){
				// check the condition
				r = checkNode(ifStatement.subNodes[0]);
			}else{
				// bad conditoin
				compileErrors.append(CompileError(ifStatement.subNodes[0].lineno, "invalid condition for if/while statement"));
				r = false;
				// keep checking the block;
			}
			r = checkBlock(ifStatement.subNodes[1]);
			return r;
		}else{
			compileErrors.append(CompileError(ifStatement.lineno, "if/while statement expected"));
			return false;
		}
	}

	/// checks varDeclare
	private bool checkVarDeclare(ASTNode varDeclare){
		// make sure its a varDeclare
		if (varDeclare.type == ASTNode.Type.VarDeclare){
			// ok, make sure there's at least one var, all subNodes are vars, and no var is being shadowed
			if (varDeclare.subNodes.length > 0){
				bool r = true;
				foreach (var; varDeclare.subNodes){
					if (keyVars.hasElement(var.data) || definedVars.hasElement(var.data)){
						// var's being shadowed
						compileErrors.append(CompileError(var.lineno, "variable `"~var.data~"` is being shadowed"));
						r = false;
					}
				}
				return r;
			}else{
				compileErrors.append(CompileError(varDeclare.lineno, "variables expected"));
				return false;
			}

		}else{
			compileErrors.append(CompileError(varDeclare.lineno, "variable declaration expected"));
			return false;
		}
	}

	/// checks operator
	private bool checkOperator(ASTNode operator){
		// make sure it's an operator
		if (operator.type == ASTNode.Type.Operator){
			// ok, make sure there's two operands
			if (operator.subNodes.length != 2){
				compileErrors.append(CompileError(operator.lineno, "operator must have 2 operands"));
				// no need to check them
				return false;
			}else{
				bool r = true;
				// check if the operator is a valid one
				if (!OPERATORS.hasElement(operator.data)){
					compileErrors.append(CompileError(operator.lineno, "invalid operator"));
					r = false;
					// check the operands
				}
				foreach (operand; operator.subNodes){
					if (!dataNodeTypes.hasElement(operand.type)){
						compileErrors.append(CompileError(operand.lineno, "invalid operand type"));
						r = false;
					}else{
						// check it
						r = checkNode(operand);
					}
				}
				return r;
			}
		}else{
			compileErrors.append(CompileError(operator.lineno, "operator expected"));
			return false;
		}
	}

	/// checks a static-length array (something like: `[a. b, c]`)
	private bool checkStaticArray(ASTNode array){
		// make sure it's a static array
		if (array.type == ASTNode.Type.StaticArray){
			// ok
			bool r = true;
			// check all it's subNodes
			foreach (element; array.subNodes){
				if (!dataNodeTypes.hasElement(element.type)){
					compileErrors.append(CompileError(element.lineno, "invalid element type"));
					r = false;
					// check other operands
				}else{
					// check this element
					r = checkNode(element);
				}
			}
			return r;
		}else{
			compileErrors.append(CompileError(array.lineno, "static-length array expected"));
			return false;
		}
	}

	/// checks a variable
	private bool checkVariable(ASTNode var){
		// make sure it's a var
		if (var.type == ASTNode.Type.Variable){
			// make sure it was defined
			if (!keyVars.hasElement(var.data) || !definedVars.hasElement(var.data)){
				compileErrors.append(CompileError(var.lineno, "variable `"~var.data~"` not defined"));
				return false;
			}
			return true;
		}else{
			compileErrors.append(CompileError(var.lineno, "variable expected"));
			return false;
		}
	}
}