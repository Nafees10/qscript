/++
For generating byte code from AST
+/
module qscript.compiler.codegen;

import qscript.compiler.ast;
import qscript.compiler.astcheck;
import qscript.compiler.misc;
import qscript.compiler.compiler : Function;

import utils.misc;
import utils.lists;

import std.conv : to;

/// class to generate byte code for an AST and performing checks on the AST (using ASTCheck class)
class CodeGen{
private:
	/// stores the pre-defined functions
	Function[] preDefFunctions;
	/// stores byte code style names of preDefFunctions
	string[] preDefFunctionNames;
	/// stores the name, arg types, and return types for script defined functions
	Function[] scriptDefFunctions;
	/// stores the byte code style names of scriptDefFunctions, match by index
	string[] scriptDefFunctionNames;
	/// stores instruction functions
	Function[] instFunctions;
	/// stores the instruction name for instruction functions, match by index
	string[] instFunctionName;
	/// stores the data type of variables
	DataType[string] varTypes;
	/// stores the maximum/highest variable ID
	uinteger maxVarID;
	/// stores the next avialable ID for a jump position
	uinteger jumpID;
	/// stores the bytecode as instructions are added to it line-by-line
	List!string byteCode;
	/// encodes function names into byte code style ones and writes them into 
	/// `scriptDefFunctionNames` & `preDefFunctionNames`
	void encodeAllFunctionNames (){
		scriptDefFunctionNames.length = scriptDefFunctions.length;
		preDefFunctionNames.length = preDefFunctions.length;
		foreach (i, func; preDefFunctions){
			preDefFunctionNames[i] = encodeFunctionName(func.name, func.argTypes);
		}
		foreach (i, func; scriptDefFunctions){
			scriptDefFunctionNames[i] = encodeFunctionName(func.name, func.argTypes);
		}
	}
protected:
	/// generates byte code for FunctionNode
	void generateByteCode(FunctionNode node){
		// add the name 
		DataType[] argTypes;
		argTypes.length = node.arguments.length;
		foreach (i ,arg; node.arguments)
			argTypes[i] = arg.argType;
		byteCode.add (encodeFunctionName(node.name, argTypes));
		// now add the placeholder for the instruction to set the variable-storing-array length
		byteCode.add ("\tvarCount ?");
		// save it's index
		uinteger varCountIndex = byteCode.length-1;
		// now add the statements
		maxVarID = argTypes.length == 0 ? 0 : argTypes.length - 1;
		jumpID = 0;
		generateByteCode (node.bodyBlock);
		// set the varCount now
		byteCode.set (varCountIndex, "\tvarCount i"~to!string(maxVarID));
	}
	/// generates byte code for BlockNode
	void generateByteCode (BlockNode node){
		foreach (statement; node.statements){
			generateByteCode (statement);
		}
	}
	/// generates byte code for a StatementNode
	void generateByteCode (StatementNode node){
		if (node.type == StatementNode.Type.Assignment){
			generateByteCode (node.node!(StatementNode.Type.Assignment));
		}else if (node.type == StatementNode.Type.Block){
			generateByteCode (node.node!(StatementNode.Type.Block));
		}else if (node.type == StatementNode.Type.DoWhile){
			generateByteCode (node.node!(StatementNode.Type.DoWhile));
		}else if (node.type == StatementNode.Type.For){
			generateByteCode (node.node!(StatementNode.Type.For));
		}else if (node.type == StatementNode.Type.FunctionCall){
			generateByteCode (node.node!(StatementNode.Type.FunctionCall), true);
		}else if (node.type == StatementNode.Type.If){
			generateByteCode (node.node!(StatementNode.Type.If));
		}else if (node.type == StatementNode.Type.VarDeclare){
			generateByteCode (node.node!(StatementNode.Type.VarDeclare));
		}else if (node.type == StatementNode.Type.While){
			generateByteCode (node.node!(StatementNode.Type.While));
		}
	}
	/// generates byte code for AssignmentNode
	void generateByteCode (AssignmentNode node){
		uinteger varID = node.var.id;
		// first check if the var is an array
		if (node.indexes.length > 0){
			// push the original value of var, then push all the indexes, then call modifyArray, and setVar
			byteCode.add("\tgetVar i"~to!string(varID));
			// now push the val
			generateByteCode(node.val);
			// now the indexes
			foreach (index; node.indexes){
				generateByteCode(index);
			}
			// then modifyArray
			byteCode.add("\tmodifyArray i"~to!string(node.indexes.length));
			// finally, set the new array back
			byteCode.add("\tsetVar i"~to!string(varID));
		}else{
			// just push the val, and call setVar on the varID
			generateByteCode(node.val);
			byteCode.add ("\tsetVar i"~to!string(varID));
		}
	}
	/// generates byte code for DoWhileNode
	void generateByteCode (DoWhileNode node){
		// get the jump ID
		uinteger jumpPos = jumpID;
		// make this jumpPos taken for this function
		jumpID ++;
		// mark start of loop, and add the loop body
		byteCode.add ("\t"~to!string (jumpPos)~":");
		generateByteCode (node.statement);
		// now the condition
		generateByteCode (node.condition);
		// jump back
		byteCode.addArray([
				"\tnot",
				"\tskipTrue",
				"\tjump "~to!string(jumpPos)
			]);
	}
	/// generates byte code for ForNode
	void generateByteCode (ForNode node){
		// get jump ID
		uinteger jumpPos = jumpID;
		jumpPos ++;
		// init statement
		generateByteCode (node.initStatement);
		// then the condition, skip to after the inc-statement
		generateByteCode (node.condition);
		byteCode.addArray ([
				"\tskipTrue",
				"\tjmup "~to!string (jumpPos)
			]);
		// now the loop body
		generateByteCode (node.statement);
		// and inc statement, followed by loop-end-jump-position
		generateByteCode (node.incStatement);
		byteCode.add ("\t"~to!string (jumpPos));
	}
	/// generates byte code for FunctionCallNode
	void generateByteCode (FunctionCallNode node, bool popReturnValue = false){
		// get the byte code style name of the function
		DataType[] argTypes;
		argTypes.length = node.arguments.length;
		foreach (i, arg; node.arguments){
			argTypes[i] = arg.argType;
		}
		// push the args
		foreach (arg; node.arguments){
			generateByteCode (arg);
		}
		// first check if it's an instruction-function
		/// stores whether a function with the the name existed
		bool functionNameExists = false;
		/// stores whether a suitable function was found
		bool found = false;
		foreach (i, func; instFunctions){
			if (func.name == node.fName){
				functionNameExists =  true;
				if (matchArguments(func.argTypes, argTypes)){
					byteCode.add ("\t"~instFunctionName[i]);
					found = true;
					break;
				}
			}
		}
		// check if it's a script defined one
		foreach (i, func; scriptDefFunctions){
			if (func.name == node.fName){
				functionNameExists = true;
				// in script defined functions, arguments must match exactly
				if (func.argTypes == argTypes){
					byteCode.add ("\texecFuncS s\""~scriptDefFunctionNames[i]~"\" i"~to!string(argTypes.length));
					found = true;
					break;
				}
			}
		}
		// finally, if it's pre def function
		foreach (i, func; preDefFunctions){
			if (func.name == node.fName){
				functionNameExists = true;
				if (matchArguments(func.argTypes, argTypes)){
					byteCode.add ("\texecFuncE s\""~preDefFunctionNames[i]~"\" i"~to!string(argTypes.length));
					found = true;
					break;
				}
			}
		}
		if (popReturnValue)
			byteCode.add ("\tpop i1");
	}
	/// generates byte code for IfNode
	void generateByteCode (IfNode node){
		// execute condition
		generateByteCode (node.condition);
		/// jump id for if-end, and else-end
		uinteger endJump = jumpID, elseEndJump = jumpID+1;
		jumpID = elseEndJump+1;
		// skip to end of if-true-body if false
		byteCode.addArray([
				"\tskipTrue",
				"\tjump "~to!string (endJump)
				]);
		// now if-true-body
		generateByteCode (node.statement);
		// if else part exists, make if-true-body skip it
		if (node.hasElse){
			// and add position of endJump right before else-body
			byteCode.addArray ([
					"\tjump "~to!string (elseEndJump),
					"\t"~to!string (endJump)~':'
					]);
			generateByteCode (node.elseStatement);
			byteCode.add ("\t"~to!string (elseEndJump)~':');
		}
	}
	/// generates byte code for VarDeclareNode
	void generateByteCode (VarDeclareNode node){
		// add to record what type the vars are
		foreach (var; node.vars){
			varTypes[var] = node.type;
			// if a value was assigned to it, assign it
			if (node.hasValue(var)){
				generateByteCode (node.getValue(var));
				byteCode.add ("\tsetVar i"~to!string (node.varIDs[var]));
			}
		}
	}
	/// generates byte code for WhileNode
	void generateByteCode (WhileNode node){
		/// jump to start of loop (before condition) & to end of loop
		uinteger startJump = jumpID, endJump = jumpID + 1;
		jumpID = endJump + 1;
		byteCode.add ("\t"~to!string (startJump)~':');
		// condition
		generateByteCode (node.condition);
		// skip jump-to-end if true
		byteCode.addArray ([
				"\tskipTrue",
				"\tjump "~to!string (endJump)
				]);
		generateByteCode (node.statement);
		byteCode.add ("\t"~to!string (endJump)~':');
	}
public:
	this (Function[] preDefFunctions){
		byteCode = new List!string;
		this.preDefFunctions = preDefFunctions.dup;
	}
	~this (){
		.destroy(byteCode);
	}
	/// adds a new "instruction-function". Any call that matches this function will be converted to an instruction rather than a 
	/// function call.
	/// 
	/// if an instruction already exists for that function, it will be overwritten
	void addInstructionFunction(Function f, string instruction){
		instFunctions ~= f;
		instFunctionName ~= instruction;
	}
	/// generates byte code for ScriptNode
	/// 
	/// Arguments:
	/// `node` is the ScriptNode to generate byte code for  
	/// `errors` is the array in which any errors will be put
	/// 
	/// Returns: the bytecode for the script
	string[] generateByteCode(ScriptNode node, ref CompileError[] errors){
		// first do the ASTCheck on the script
		ASTCheck check = new ASTCheck(preDefFunctions.dup);
		errors = [];
		errors = check.checkAST(node, scriptDefFunctions);
		if (errors.length == 0){
			// clean everything
			varTypes.clear;
			byteCode.clear;
			// now start with the codegen
			encodeAllFunctionNames(); // required for generating byte code for FunctionCallNode
			foreach (functionNode; node.functions){
				generateByteCode(functionNode);
			}
		}
		string[] r = byteCode.toArray;
		byteCode.clear;
		return r;
	}
}

/// contains functions to generate byte code from AST
/*package struct CodeGen{
	/// generates byte code for a script
	public string[] generateByteCode(ScriptNode scriptNode, ref CompileError[] errors){
		compileErrors = new LinkedList!CompileError;
		LinkedList!string byteCode = new LinkedList!string;
		// remove all previous errors
		compileErrors.clear;
		// prepare a list of script-defind functions
		scriptDefinedFunctions.length = scriptNode.functions.length;
		foreach (i, functionNode; scriptNode.functions){
			scriptDefinedFunctions[i] = functionNode.name;
		}
		// go through all nodes/ functions, and generate byte-code for them
		foreach (functionNode; scriptNode.functions){
			byteCode.append(generateByteCode(functionNode));
		}

		string[] r = byteCode.toArray;
		.destroy(byteCode);
		// put in errors
		errors = compileErrors.toArray;
		.destroy(compileErrors);
		return r;
	}

	/// provides functions to deal with converting vars to IDs
	private struct{
		/// stores IDs for vars
		private string[uinteger] varIDs;
		/// stores the scope "depth" for each varID
		private uinteger[uinteger] varScopeDepth;
		/// stores the current scope depth
		private uinteger scopeDepth;
		/// creates a new var, returns the ID, throws Exception if var already exists
		public uinteger getNewVarID(string varName){
			// check if already exists
			foreach (id, name; varIDs){
				if (varName == name){
					throw new Exception("variable '"~varName~"' declared twice");
				}
			}
			// find an empty ID
			uinteger newID = 0;
			while (newID in varIDs){
				newID ++;
			}
			varIDs[newID] = varName;
			// put it in varScopeDepth
			varScopeDepth[newID] = scopeDepth;
			return newID;
		}
		/// returns ID of a var. throws exception if var is not declared
		public uinteger getVarID(string varName){
			foreach (key; varIDs.keys){
				if (varIDs[key] == varName){
					return key;
				}
			}
			throw new Exception("variable '"~varName~"' not declared but used");
		}
	}

	/// contains a list of script0-defined functions
	private string[] scriptDefinedFunctions;

	/// Returns true if a function is script-defined
	private bool isScriptDefined(string fName){
		foreach (scriptDefined; scriptDefinedFunctions){
			if (fName == scriptDefined){
				return true;
			}
		}
		return false;
	}

	/// returns the number of max vars that exist at one time in a StatementNode[]
	private static uinteger getMaxVarCount(StatementNode[] statements){
		uinteger r = 0;
		uinteger maxSub = 0;
		foreach (statement; statements){
			if (statement.type == StatementNode.Type.VarDeclare){
				// get the number of vars
				r += statement.node!(StatementNode.Type.VarDeclare).vars.length;
			}else{
				uinteger newMaxSub = getVarCountStatement (statement);
				if (newMaxSub > maxSub){
					maxSub = newMaxSub;
				}
			}
		}
		return r + maxSub;
	}
	
	/// returns the number of vars defined in a statement
	private static uinteger getVarCountStatement (StatementNode statement){
		if (statement.type == StatementNode.Type.VarDeclare){
			return statement.node!(StatementNode.Type.VarDeclare).vars.length;
		}else if (statement.type == StatementNode.Type.Block){
			return getMaxVarCount (statement.node!(StatementNode.Type.Block).statements);
		}else if (statement.type == StatementNode.Type.If){
			uinteger onTrueCount = 0, onFalseCount = 0;
			IfNode ifStatement = statement.node!(StatementNode.Type.If);
			onTrueCount = getVarCountStatement (ifStatement.statement);
			if (ifStatement.hasElse){
				onFalseCount = getVarCountStatement (ifStatement.elseStatement);
			}
			return (onTrueCount > onFalseCount ? onTrueCount : onFalseCount);
		}else if (statement.type == StatementNode.Type.While){
			return getVarCountStatement (statement.node!(StatementNode.Type.While).statement);
		}else if (statement.type == StatementNode.Type.For){
			ForNode forNode = statement.node!(StatementNode.Type.For);
			return getVarCountStatement (forNode.initStatement) + getVarCountStatement (forNode.incStatement) + 
				getVarCountStatement (forNode.statement);
		}else if (statement.type == StatementNode.Type.DoWhile){
			return getVarCountStatement (statement.node!(StatementNode.Type.DoWhile).statement);
		}
		return 0;
	}

	/// stores the list of errors
	private LinkedList!CompileError compileErrors;

	/// generates byte code for FunctionNode
	private string[] generateByteCode(FunctionNode node){
		LinkedList!string byteCode = new LinkedList!string;
		// push the function name
		byteCode.append (node.name);
		// then set the max var count
		uinteger maxVars = getMaxVarCount(node.bodyBlock.statements);
		// add the arguments count to this
		maxVars += node.arguments.length;
		byteCode.append("\tvarCount i"~to!string(maxVars));
		// then assign the arguments their var IDs
		increaseScope();
		foreach (arg; node.arguments){
			try{
				getNewVarID(arg.argName);
			}catch (Exception e){
				compileErrors.append(CompileError(0, "bug in compiler - argument name '"~arg.argName~"' not available"));
				.destroy (e);
			}
		}
		// then append the instructions
		byteCode.append (generateByteCode (node.bodyBlock));
		decreaseScope();

		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for BlockNode
	private string[] generateByteCode(BlockNode node){
		LinkedList!string byteCode = new LinkedList!string;
		increaseScope();
		foreach (statement; node.statements){
			byteCode.append(generateByteCode(statement));
		}
		decreaseScope();
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for StatementNode
	private string[] generateByteCode(StatementNode node){
		if (node.type == StatementNode.Type.Assignment){
			return generateByteCode(node.node!(StatementNode.Type.Assignment));
		}else if (node.type == StatementNode.Type.Block){
			return generateByteCode(node.node!(StatementNode.Type.Block));
		}else if (node.type == StatementNode.Type.FunctionCall){
			return generateByteCode(node.node!(StatementNode.Type.FunctionCall));
		}else if (node.type == StatementNode.Type.If){
			return generateByteCode(node.node!(StatementNode.Type.If));
		}else if (node.type == StatementNode.Type.While){
			return generateByteCode(node.node!(StatementNode.Type.While));
		}else if (node.type == StatementNode.Type.For){
			return generateByteCode(node.node!(StatementNode.Type.For));
		}else if (node.type == StatementNode.Type.DoWhile){
			return generateByteCode(node.node!(StatementNode.Type.DoWhile));
		}else if (node.type == StatementNode.Type.VarDeclare){
			return generateByteCode(node.node!(StatementNode.Type.VarDeclare));
		}else{
			compileErrors.append(CompileError(0, "invalid AST generated"));
			return [];
		}
	}

	/// generates byte code for FunctionCallNode
	private string[] generateByteCode(FunctionCallNode node, bool pushReturn = false){
		auto byteCode = new LinkedList!string;
		// push the args
		uinteger argCount = 0;
		foreach (arg; node.arguments){
			byteCode.append(generateByteCode(arg));
			argCount ++;
		}
		// check if is a predefined-QScript-function
		const string[string] predefinedFunctions = [
			"setLength"		: "setLen",
			"getLength"		: "getLen",
			"strLen"		: "strLen",
			"array"			: "makeArray",
			"return"		: "return",
			"strToInt"		: "strToInt",
			"strToDouble"	: "strToDouble",
			"intToStr"		: "intToStr",
			"intToDouble"	: "intToDouble",
			"doubleToStr"	: "doubleToStr",
			"doubleToInt"	: "doubleToInt",
			"not"			: "not"
		];
		if (node.fName in predefinedFunctions){
			// then use the predefined function's instruction
			if (node.fName == "array"){
				byteCode.append ('\t'~predefinedFunctions[node.fName]~" i"~to!string(node.arguments.length));
			}else{
				byteCode.append('\t'~predefinedFunctions[node.fName]);
			}
		}else{
			// then append the instruction to execute this function
			if (isScriptDefined(node.fName)){
				byteCode.append("\texecFuncS s\""~node.fName~"\" i"~to!string(argCount));
			}else{
				byteCode.append("\texecFuncE s\""~node.fName~"\" i"~to!string(argCount));
			}
		}
		// pop the return, if result not required
		if (!pushReturn){
			byteCode.append("\tpop i1");
		}
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for CodeNode
	private string[] generateByteCode(CodeNode node){
		if (node.type == CodeNode.Type.FunctionCall){
			return generateByteCode(node.node!(CodeNode.Type.FunctionCall), true);
		}else if (node.type == CodeNode.Type.Literal){
			return generateByteCode(node.node!(CodeNode.Type.Literal));
		}else if (node.type == CodeNode.Type.Operator){
			return generateByteCode(node.node!(CodeNode.Type.Operator));
		}else if (node.type == CodeNode.Type.Variable){
			return generateByteCode(node.node!(CodeNode.Type.Variable));
		}else if (node.type == CodeNode.Type.ReadElement){
			return generateByteCode(node.node!(CodeNode.Type.ReadElement));
		}else{
			compileErrors.append(CompileError(0, "invalid AST generated"));
			return [];
		}
	}

	/// generates byte code for OperatorNode
	private string[] generateByteCode(OperatorNode node){
		const string[string] operatorInstructions = [
			"*" : "multiply",
			"/" : "divide",
			"+" : "add",
			"-" : "subtract",
			"%" : "mod",
			"~" : "concat",
			"<" : "isLesser",
			"==": "isSame",
			">" : "isGreater",
			"&&": "and",
			"||": "or"
		];
		// check if types are ok
		const static string[] ArtithmaticOperators = ["*", "/", "+", "-", "%", "<", ">"];
		const static string[] IntOperators = ["&&", "||"];
		const static string[] ArrayStringOperators = ["~"];
		const static string[] NonArrayOperators = ["==", "&&", "||"];
		bool errorFree = true;
		// first make sure both operands are of same type
		if (node.operands[0].returnType != node.operands[1].returnType){
			compileErrors.append(CompileError(0, "data type of both operands must be same"));
		}
		if (ArtithmaticOperators.hasElement(node.operator)){
			// must be either int, or double
			if (node.operands[0].returnType.isArray == true){
				compileErrors.append(CompileError(0, "arithmatic operators cannot be used on arrays"));
				errorFree = false;
			}
			if (node.operands[0].returnType.type != DataType.Type.Double &&
				node.operands[0].returnType.type != DataType.Type.Integer){
				compileErrors.append(CompileError(0, "arithmatic operators can only be used on integer or double"));
				errorFree = false;
			}
		}else if (IntOperators.hasElement(node.operator)){
			// make sure is int
			if (node.operands[0].returnType != DataType(DataType.Type.Integer)){
				compileErrors.append(CompileError(0, node.operator~" can only be used on integers"));
				errorFree = false;
			}
		}else if (ArrayStringOperators.hasElement(node.operator)){
			if (!node.operands[0].returnType.isArray && node.operands[0].returnType.type != DataType.Type.String){
				compileErrors.append(CompileError(0, "cannot use this operator on non-string and non-array data"));
				errorFree = false;
			}
		}else if (NonArrayOperators.hasElement(node.operator)){
			// make sure type's not array
			if (node.operands[0].returnType.isArray){
				compileErrors.append(CompileError(0, node.operator~" cannot be used with arrays"));
				errorFree = false;
			}
		}else{
			compileErrors.append(CompileError(0, "invalid operator"));
			errorFree = false;
		}
		if (errorFree){
			// now push the operands
			auto byteCode = new LinkedList!string;
			byteCode.append(generateByteCode(node.operands[0])~generateByteCode(node.operands[1]));
			// now get the operator instruction name
			string instruction = operatorInstructions[node.operator];
			// append the data type at the end to get the exact name, only if is not IntOperator
			if (!IntOperators.hasElement(node.operator)){
				if (node.operands[0].returnType.isArray){
					instruction ~= "Array";
				}else if (node.operands[0].returnType.type == DataType.Type.String){
					instruction ~= "String";
				}else if (node.operands[0].returnType.type == DataType.Type.Integer){
					instruction ~= "Int";
				}else if (node.operands[0].returnType.type == DataType.Type.Double){
					instruction ~= "Double";
				}else{
					compileErrors.append(CompileError(0, "unsupported data type"));
				}
			}
			// call the instruction
			byteCode.append("\t"~instruction);
			string[] r = byteCode.toArray;
			.destroy(byteCode);
			return r;
		}else{
			return [];
		}
	}

	/// generates byte code for VariableNode
	private string[] generateByteCode(VariableNode node){
		auto byteCode = new LinkedList!string;
		// first get the var's value on stack
		uinteger varID;
		try{
			varID = getVarID(node.varName);
		}catch (Exception e){
			compileErrors.append(CompileError(0, e.msg));
			.destroy(e);
		}
		return ["\tgetVar i"~to!string(varID)];
	}

	/// generates byte code for ReadElement
	private string[] generateByteCode(ReadElement node){
		// use CodeNode's byte code generator to get byte code for readFromNode
		string[] r = generateByteCode(node.readFromNode)~generateByteCode(node.index);
		// use readChar or readElement
		if (node.readFromNode.returnType == DataType(DataType.Type.String)){
			// use ReadChar
			return r~["\treadChar"];
		}else{
			return r~["\treadElement"];
		}
	}

	/// generates byte code for AssignmentNode
	private string[] generateByteCode(AssignmentNode node){
		uinteger varID;
		try{
			varID = getVarID(node.var.varName);
		}catch (Exception e){
			compileErrors.append(CompileError(0, e.msg));
			.destroy(e);
		}
		// first check if the var is an array
		if (node.indexes.length > 0){
			// push the original value of var, then push all the indexes, then call modifyAray, and setVar
			auto byteCode = new LinkedList!string;
			byteCode.append("\tgetVar i"~to!string(varID));
			// now push the val
			byteCode.append(generateByteCode(node.val));
			// now the indexes
			foreach (index; node.indexes){
				byteCode.append(generateByteCode(index));
			}
			// then modifyArray
			byteCode.append("\tmodifyArray i"~to!string(node.indexes.length));
			// finally, set the new array back
			byteCode.append("\tsetVar i"~to!string(varID));
			string[] r = byteCode.toArray;
			.destroy(byteCode);
			return r;
		}else{
			// just push the val, and call setVar on the varID
			return generateByteCode(node.val)~
			["\tsetVar i"~to!string(varID)];
		}
	}

	/// generates byte code for VarDeclareNode
	private string[] generateByteCode(VarDeclareNode node){
		foreach (var; node.vars){
			try{
				getNewVarID(var);
			}catch (Exception e){
				compileErrors.append(CompileError(0, e.msg));
			}
		}
		auto byteCode = new LinkedList!string;
		// assign the assigned values
		foreach (var; node.vars){
			if (node.hasValue(var)){
				byteCode.append(generateByteCode(node.getValue(var)));
				byteCode.append("\tsetVar i"~to!string(getVarID(var)));
			}
		}
		// if is an array, then call emptyArray on all those vars that don't have a value assigned to them
		if (node.type.isArray){
			foreach (var; node.vars){
				if (!node.hasValue(var)){
					byteCode.append([
							"\temptyArray",
							"\tsetVar i"~to!string(getVarID(var))
						]);
				}
			}
		}
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for IfNode
	private string[] generateByteCode(IfNode node){
		// stores the `ID` of this if statement
		static uinteger ifCount = 0;
		uinteger currentCount = ifCount;
		ifCount ++;
		auto byteCode = new LinkedList!string;
		// first push the condition
		byteCode.append(generateByteCode(node.condition));
		// then the skipTrue, to skip the jump to else
		byteCode.append([
				"\tskipTrue",
				"\tjump ifEnd"~to!string(currentCount)
			]);
		// then comes the if-on-true body
		increaseScope();
		byteCode.append(generateByteCode(node.statement));
		decreaseScope();
		// then then jump to elseEnd to skip the else statements
		if (node.hasElse){
			byteCode.append("\tjump elseEnd"~to!string(currentCount));
		}
		byteCode.append("\tifEnd"~to!string(currentCount)~":");
		// now the elseBody
		if (node.hasElse){
			increaseScope();
			byteCode.append(generateByteCode(node.elseStatement)~
					["\telseEnd"~to!string(currentCount)~":"]);
			decreaseScope();
		}
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for WhileNode
	private string[] generateByteCode(WhileNode node){
		auto byteCode = new LinkedList!string;
		// stores the `ID` of the while statement
		static uinteger whileCount = 0;
		uinteger currentCount = whileCount;
		whileCount ++;
		// first comes the jump-back-here position
		byteCode.append("\twhileStart"~to!string(currentCount)~":");
		// then comes the condition
		byteCode.append(generateByteCode(node.condition));
		// then skip the jump-to-end if true
		byteCode.append([
				"\tskipTrue",
				"\tjump whileEnd"~to!string(currentCount)
			]);
		// then the loop body
		increaseScope();
		byteCode.append(generateByteCode(node.statement));
		decreaseScope();
		// then jump back to condition, to see if it'll start again
		byteCode.append("\tjump whileStart"~to!string(currentCount));
		// then mark the loop end
		byteCode.append("\twhileEnd"~to!string(currentCount)~":");
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for ForNode
	private string[] generateByteCode(ForNode node){
		auto byteCode = new LinkedList!string;
		// stores `ID` of the for loop statements
		static uinteger forCount = 0;
		uinteger currentCount = forCount;
		forCount ++;
		// increase the var scope
		increaseScope();
		// now the init statement
		byteCode.append(generateByteCode(node.initStatement));
		// jump-back position
		byteCode.append("\tforStart"~to!string(currentCount)~":");
		// now the condition
		byteCode.append(generateByteCode(node.condition));
		// skip to end if not true
		byteCode.append([
				"\tskipTrue",
				"\tjump forEnd"~to!string(currentCount)
			]);
		// loop body
		byteCode.append(generateByteCode(node.statement));
		// increment statement
		byteCode.append(generateByteCode(node.incStatement));
		// end point
		byteCode.append([
				"\tjump forStart"~to!string(currentCount),
				"\tforEnd"~to!string(currentCount)~":"
			]);
		// decrease scope
		decreaseScope();
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for a do-while loop statement
	private string[] generateByteCode(DoWhileNode node){
		auto byteCode = new LinkedList!string;
		/// stores the `ID` of the do-while loop statements
		static uinteger doWhileCount = 0;
		uinteger currentCount = doWhileCount;
		doWhileCount ++;
		// increase var scope
		increaseScope();
		// jump back position
		byteCode.append("\tdoWhileStart"~to!string(currentCount)~":");
		// now for the loop statement
		// if its a block, any var declared in it wont be availiable to the `while(...)`
		// because generateByteCode(BlockNode ...) decreases scope, so in case of block, this will generate byte code for that itself
		if (node.statement.type == StatementNode.Type.Block){
			BlockNode block = node.statement.node!(StatementNode.Type.Block);
			foreach (statement; block.statements){
				byteCode.append(generateByteCode(statement));
			}
		}else{
			byteCode.append (generateByteCode(node.statement));
		}
		// now the condition
		byteCode.append(generateByteCode(node.condition));
		// now the jump. This jump is different, the jump-back will only be made if the condition is true. That means skipTrue should
		// only be executed if condition is false, so condition=false -> skip-jump -> loop-over. Just use not instruction on condition
		byteCode.append([
				"\tnot",
				"\tskipTrue i1",
				"\tjump doWhileStart"~to!string(currentCount)
			]);
		decreaseScope();
		// thats it
		string[] r = byteCode.toArray;
		.destroy(byteCode);
		return r;
	}

	/// generates byte code for a LiteralNode
	private string[] generateByteCode(LiteralNode node){
		// just use LiteralNode.toByteCode
		string literal;
		try{
			literal = node.toByteCode;
		}catch (Exception e){
			compileErrors.append(CompileError(0, e.msg));
		}
		return ["\tpush "~literal];
	}

}*/
