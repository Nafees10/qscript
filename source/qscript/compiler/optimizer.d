module qscript.compiler.optimizer;

import qscript.compiler.ast;
import qscript.compiler.misc;
import utils.misc;
import utils.lists;

/// Used by ASTOptimize to temporarily store information about a var
struct Var{
	enum Type{
		Number,
		String,
		Array,
		Undefined
	}
	string name; /// the variable name
	Type type; /// the type of data stored in the var, if not static, or not known, it is `Var.Type.Undefined`
	bool valueKnown; /// stores whether the value of the var is static (true) or not (false)
	union{
		string stringValue; /// to store value if type==string
		double numberValue; /// to store value if type==number
		string[] stringArrayValue; /// to store value if type==array of string
		double[] numberArrayValue; /// to store value if type==array of number
	}
}

/// struct providing functions to optimize an check the AST for errors
public struct ASTOptimize{
	/// stores the variable with their types, and value (if static), the index is the name of the var
	Var[string] vars;
	/// optimizes and looks for errors in the scriptNode. returns the optimized scriptNode
	/// 
	/// Errors are appended to `qscript.compiler.misc.compileErrors`
	public ASTNode optimizeScript(ASTNode script){
		// make sure scriptNode was received
		if (script.type == ASTNode.Type.Script){
			// ok
			// make sure all suNodes are functions, and call functions to optimize & check those nodes as well
			ASTNode[] subNodes = script.getSubNodes();
			foreach (subNode; subNodes){

			}
		}else{
			compileErrors.append(CompileError("ASTOptimize.optimizeScript can only be called with a node of type script"));
			return script;
		}
	}

	/// optimizes and looks for errors in functions nodes
	private ASTNode optimizeFunction(ASTNode functionNode){
		// make sure it is a function
		if (functionNode.type == ASTNode.Type.Function){
			// ok
			// check and optimize each and every node
			ASTNode[] statements = functionNode.getSubNodes;
			foreach (statement; statements){

			}
		}else{
			compileErrors.append(CompileError("ASTOptimize.optimizeFunction can only be called with a node of type function"));
			return functionNode;
		}
	}

	/// optimizes and looks for errors in a statement
	private ASTNode optimizeStatement(ASTNode statement){
		// make sure it is a statement
		// TODO continue from here
	}
}