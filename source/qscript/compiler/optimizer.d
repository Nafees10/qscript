module qscript.compiler.optimizer;

import qscript.compiler.ast;
import qscript.compiler.misc;
import utils.misc;

/// struct providing functions to optimize an check the AST for errors
struct ASTOptimize{
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