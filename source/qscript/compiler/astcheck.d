/++
Functions to check if a script is valid (or certain nodes) by its generated AST
+/
module qscript.compiler.astcheck;

import qscript.compiler.misc;
import qscript.compiler.ast;
import qscript.compiler.compiler : Function;

import utils.misc;
import utils.lists;

/// Contains functions to check ASTs for errors  
/// One instance of this class can be used to check for errors in a script's AST.
class ASTCheck{
private:
	/// stores the pre defined functions' names, arg types, and return types
	Function[] preDefFunctions;
	/// stores the script defined functions' names, arg types, and return types
	Function[] scriptDefFunctions;
	/// stores all the errors that are there in the AST being checked
	LinkedList!CompileError compileErrors;
	/// functions that have their own instructions. Index is the byte-code style function name, val is the instruction name
	string[string] instructionFunctions;
	/// stores return types for instructionFunctions
	DataType[string] instructionFunctionReturnTypes;
	/// stores data types of variables in currently-being-checked-FunctionNode
	DataType[string] varTypes;
	/// stores the IDs (as index) for vars
	string[uinteger] varIDs;
	/// stores the scope-depth of each var in currently-being-checked-FunctionNode which is currently in scope
	uinteger[string] varScope;
	/// stores current scope-depth
	uinteger scopeDepth;
	/// registers a new var in current scope
	/// 
	/// Returns: false if it was already registered, true if it was successful
	bool addVar(string name, DataType type){
		if (name in varTypes){
			return false;
		}
		varTypes[name] = type;
		varScope[name] = scopeDepth;

		uinteger i;
		for (i = 0; ; i ++){
			if (i !in varIDs)
				break;
		}
		varIDs[i] = name;
		return true;
	}
	/// Returns: the data type of a variable  
	/// or if var does not exist, returns `DataType()`
	DataType getVarType(string name){
		if (name in varTypes){
			return varTypes[name];
		}
		return DataType();
	}
	/// Returns: the ID for a variable  
	/// or -1 if it does not exist
	integer getVarID(string name){
		foreach (id, varName; varIDs){
			if (name == varName){
				return id;
			}
		}
		return -1;
	}
	/// Returns: true if a var is available in current scope
	bool varExists(string name){
		if (name in varTypes)
			return true;
		return false;
	}
	/// increases the scope-depth
	/// 
	/// this function should be called before any AST-checking in a sub-BlockNode or anything like that is started
	void increaseScope(){
		scopeDepth ++;
	}
	/// decreases the scope-depth
	/// 
	/// this function should be called right after checking in a sub-BlockNode or anything like that is finished  
	/// it will put the vars declared inside that scope go out of scope
	void decreaseScope(){
		foreach (key; varScope.keys){
			if (varScope[key] == scopeDepth){
				varScope.remove(key);
				// remove from varDataTypes too!
				varTypes.remove(key);
				// remove it from varIDs too
				foreach (id; varIDs.keys){
					if (varIDs[id] == key){
						varIDs.remove (id);
						break;
					}
				}
			}
		}
		if (scopeDepth > 0){
			scopeDepth --;
		}
	}
	/// Returns: return type of a function, works for both script-defined and predefined functions  
	/// or if the function does not exist, it'll return `DataType()`
	DataType getFunctionType(string name, DataType[] argTypes){
		// check if it's an instruction function
		string byteCodeName = encodeFunctionName(name, argTypes);
		if (byteCodeName in instructionFunctions){
			return instructionFunctionReturnTypes[byteCodeName];
		}
		foreach (func; scriptDefFunctions){
			if (func.name == name && func.argTypes == argTypes){
				return func.returnType;
			}
		}
		foreach (func; preDefFunctions){
			if (func.name == name && func.argTypes == argTypes){
				return func.returnType;
			}
		}
		return DataType();
	}
	/// Returns: return type for a CodeNode
	/// 
	/// In case there's an error, returns `DataType()`
	DataType getReturnType(CodeNode node){
		if (node.type == CodeNode.Type.FunctionCall){
			DataType[] argTypes;
			FunctionCallNode fCall = node.node!(CodeNode.Type.FunctionCall);
			argTypes.length = fCall.arguments.length;
			foreach (i, arg; fCall.arguments){
				argTypes[i] = getReturnType(arg);
			}
			return getFunctionType(fCall.fName, argTypes);
		}else if (node.type == CodeNode.Type.Literal){
			return node.node!(CodeNode.Type.Literal).returnType;
		}else if (node.type == CodeNode.Type.Operator){
			OperatorNode opNode = node.node!(CodeNode.Type.Operator);
			DataType[2] operandTypes = [getReturnType(opNode.operands[0]), getReturnType(opNode.operands[1])];
			if (operandTypes[0] != operandTypes[1]){
				return DataType();
			}
			return operandTypes[0];
		}else if (node.type == CodeNode.Type.SOperator){
			SOperatorNode opNode = node.node!(CodeNode.Type.SOperator);
			DataType operandType = getReturnType(opNode.operand);
			// hardcoded stuff, beware
			if (opNode.operator == "@"){
				operandType.isRef = operandType.isRef ? false : true;
			}
			// </hardcoded>
			return operandType;
		}else if (node.type == CodeNode.Type.ReadElement){
			ReadElement arrayRead = node.node!(CodeNode.Type.ReadElement);
			DataType readFromType = getReturnType(arrayRead.readFromNode);
			if (readFromType.arrayDimensionCount == 0){
				if (readFromType.type == DataType.Type.String){
					return DataType(DataType.Type.String);
				}else{
					return DataType();
				}
			}
			readFromType.arrayDimensionCount --;
			return readFromType;
		}else if (node.type == CodeNode.Type.Variable){
			VariableNode varNode = node.node!(CodeNode.Type.Variable);
			return getVarType(varNode.varName);
		}
		return DataType(DataType.Type.Void);
	}
	/// reads all FunctionNode from ScriptNode and writes them into `scriptDefFunctions`
	/// 
	/// any error is appended to compileErrors
	void readFunctions(ScriptNode node){
		/// stores the functions in byte code style, coz that way, its easier to check if same function with same
		/// arg types has been used more than once
		string[] byteCodefunctionNames;
		scriptDefFunctions.length = node.functions.length;
		byteCodefunctionNames.length = node.functions.length;
		foreach (i, func; node.functions){
			// read arg types into a single array
			DataType[] argTypes;
			argTypes.length = func.arguments.length;
			foreach (index, arg; func.arguments)
				argTypes[index] = arg.argType;
			scriptDefFunctions[i] = Function(func.name, func.returnType, argTypes);
			byteCodefunctionNames[i] = encodeFunctionName(func.name, argTypes);
			if (byteCodefunctionNames[0 .. i].hasElement(byteCodefunctionNames[i])){
				compileErrors.append (CompileError(func.lineno,
						"functions with same name must have different argument types"
					));
			}
		}
	}
protected:
	/// checks if a FunctionNode is valid
	void checkAST(FunctionNode node){
		increaseScope();
		// add the arg's to the var scope. make sure one arg name is not used more than once
		foreach (i, arg; node.arguments){
			if (!addVar(arg.argName, arg.argType)){
				compileErrors.append(CompileError(node.lineno, "argument name '"~arg.argName~"' has been used more than once"));
			}
		}
		// now check the statements
		checkAST(node.bodyBlock);
		decreaseScope();
	}
	/// checks if a StatementNode is valid
	void checkAST(StatementNode node){
		if (node.type == StatementNode.Type.Assignment){
			checkAST(node.node!(StatementNode.Type.Assignment));
		}else if (node.type == StatementNode.Type.Block){
			checkAST(node.node!(StatementNode.Type.Block));
		}else if (node.type == StatementNode.Type.DoWhile){
			checkAST(node.node!(StatementNode.Type.DoWhile));
		}else if (node.type == StatementNode.Type.For){
			checkAST(node.node!(StatementNode.Type.For));
		}else if (node.type == StatementNode.Type.FunctionCall){
			checkAST(node.node!(StatementNode.Type.FunctionCall));
		}else if (node.type == StatementNode.Type.If){
			checkAST(node.node!(StatementNode.Type.If));
		}else if (node.type == StatementNode.Type.VarDeclare){
			checkAST(node.node!(StatementNode.Type.VarDeclare));
		}else if (node.type == StatementNode.Type.While){
			checkAST(node.node!(StatementNode.Type.While));
		}
	}
	/// checks a AssignmentNode
	void checkAST(AssignmentNode node){
		// make sure var exists, checkAST(VariableNode) does that
		checkAST(node.var);
		DataType varType = getVarType (node.var.varName);
		// check if the indexes provided for the var are possible, i.e if the var declaration has >= those indexes
		if (varType.arrayDimensionCount < node.indexes.length){
			compileErrors.append(CompileError(node.var.lineno, "array's dimension count in assignment differes from declaration"));
		}else{
			// check if the data type of the value and var (considering the indexes used) match
			DataType expectedType = varType;
			expectedType.arrayDimensionCount -= node.indexes.length;
			// check with deref (if has to deref the var)
			if (node.deref){
				expectedType.isRef = false;
				if (!varType.isRef){
					compileErrors.append (CompileError(node.val.lineno, "can only deref (@) a reference"));
				}
			}
			if (getReturnType(node.val) != expectedType){
				compileErrors.append(CompileError(node.val.lineno, "cannot assign value with different data type to variable"));
			}
			// now check the CodeNode's for indexes
			foreach (indexCodeNode; node.indexes){
				checkAST(indexCodeNode);
			}
			// now check the value's CodeNode
			checkAST(node.val);
		}
	}
	/// checks a BlockNode
	void checkAST(BlockNode node, bool ownScope = true){
		if (ownScope)
			increaseScope();
		foreach (statement; node.statements){
			checkAST(statement);
		}
		if (ownScope)
			decreaseScope();
	}
	/// checks a DoWhileNode
	void checkAST(DoWhileNode node){
		increaseScope();
		if (node.statement.type == StatementNode.Type.Block){
			checkAST(node.statement.node!(StatementNode.Type.Block), false);
		}else{
			checkAST(node.statement);
		}
		checkAST(node.condition);
		decreaseScope();
	}
	/// checks a ForNode
	void checkAST(ForNode node){
		increaseScope();
		// first the init statement
		checkAST(node.initStatement);
		// then the condition
		checkAST(node.condition);
		// then the increment one
		checkAST(node.incStatement);
		// finally the loop body
		checkAST(node.statement);
		decreaseScope();
	}
	/// checks a FunctionCallNode
	void checkAST(FunctionCallNode node){
		/// store the arguments types
		DataType[] argTypes;
		argTypes.length = node.arguments.length;
		// while moving the type into separate array, perform the checks on the args themselves
		foreach (i, arg; node.arguments){
			argTypes[i] = getReturnType(arg);
			checkAST(arg);
		}
		// now make sure that that function exists, and the arg types match
		bool functionExists = false;
		foreach (func; scriptDefFunctions){
			if (func.name == node.fName && func.argTypes == argTypes){
				functionExists = true;
			}
		}
		if (!functionExists){
			foreach (func; preDefFunctions){
				if (func.name == node.fName && matchArguments(func.argTypes, argTypes)){
					functionExists = true;
				}
			}
		}
		if (!functionExists){
			compileErrors.append(CompileError(node.lineno,
					"function "~node.fName~" does not exist or cannot be called with these arguments"));
		}
	}
	/// checks an IfNode
	void checkAST(IfNode node){
		// first the condition
		checkAST(node.condition);
		// then statements
		increaseScope();
		checkAST(node.statement);
		decreaseScope();
		if (node.hasElse){
			increaseScope();
			checkAST(node.elseStatement);
			decreaseScope();
		}
	}
	/// checks a VarDeclareNode
	void checkAST(ref VarDeclareNode node){
		foreach (i, varName; node.vars){
			if (varExists(varName)){
				compileErrors.append(CompileError(node.lineno, "variable "~varName~" has already been declared"));
			}else if (node.hasValue(varName)){
				// match values
				CodeNode value = node.getValue(varName);
				checkAST(value);
				// make sure that value can be assigned
				DataType valueType = getReturnType(value);
				if (valueType != node.type){
					compileErrors.append(CompileError(node.lineno, "cannot assign value of different data type"));
				}
				// assign it an id
				addVar (varName, node.type);
				// set it's ID
				node.setVarID(varName, getVarID(varName));
			}
		}
	}
	/// checks a WhileNode
	void checkAST(WhileNode node){
		// first condition
		checkAST(node.condition);
		// the the statement
		increaseScope();
		checkAST(node.statement);
		decreaseScope();
	}
	/// checks a CodeNode
	void checkAST(CodeNode node){
		if (node.type == CodeNode.Type.FunctionCall){
			checkAST(node.node!(CodeNode.Type.FunctionCall));
		}else if (node.type == CodeNode.Type.Literal){
			// nothing to check
		}else if (node.type == CodeNode.Type.Operator){
			checkAST(node.node!(CodeNode.Type.Operator));
		}else if (node.type == CodeNode.Type.SOperator){
			checkAST(node.node!(CodeNode.Type.SOperator));
		}else if (node.type == CodeNode.Type.ReadElement){
			checkAST(node.node!(CodeNode.Type.ReadElement));
		}else if (node.type == CodeNode.Type.Variable){
			checkAST(node.node!(CodeNode.Type.Variable));
		}else if (node.type == CodeNode.Type.Array){
			checkAST(node.node!(CodeNode.Type.Array));
		}
	}
	/// checks a OperatorNode
	void checkAST(OperatorNode node){
		// check the operands
		foreach (operand; node.operands){
			checkAST (operand);
		}
		// make sure both operands are of same data type
		DataType operandType = getReturnType(node.operands[0]);
		if (getReturnType(node.operands[0]) != getReturnType(node.operands[1])){
			compileErrors.append(CompileError(node.lineno, "Both operands for operator must be of same type"));
		}
		// now make sure that the data type of operands is allowed with that operator
		if (["+","-","*","/","%", "<", ">"].hasElement(node.operator)){
			// only double and int allowed
			if (operandType != DataType(DataType.Type.Integer) && operandType != DataType(DataType.Type.Double)){
				compileErrors.append (CompileError(node.lineno, "that operator can only be used on double or int"));
			}
		}else if (["&&", "||"].hasElement(node.operator)){
			if (operandType != DataType(DataType.Type.Integer)){
				compileErrors.append (CompileError(node.lineno, "that operator can only be used on int"));
			}
		}else if (node.operator == "~"){
			if (operandType != DataType(DataType.Type.String) && operandType.arrayDimensionCount == 0){
				compileErrors.append (CompileError(node.lineno, "~ operator can only be used on strings and arrays"));
			}
		}
	}
	/// checks a SOperatorNode
	void checkAST(SOperatorNode node){
		// check the operand
		checkAST(node.operand);
		// now it it's `!`, only accept int, if `@`, var
		if (node.operator == "!"){
			if (getReturnType(node.operand) != DataType(DataType.Type.Integer)){
				compileErrors.append (CompileError(node.operand.lineno, "cannot use ! a non-int data type"));
			}
		}else if (node.operator == "@"){
			if (node.operand.type != CodeNode.Type.Variable){
				compileErrors.append (CompileError(node.operand.lineno, "can only ref/deref (@) a variable"));
			}
		}else
			compileErrors.append (CompileError(node.lineno, "invalid operator"));
	}
	/// checks a ReadElement
	void checkAST(ReadElement node){
		// check the var, and the index
		checkAST (node.readFromNode);
		checkAST (node.index);
		// index must return int
		if (getReturnType(node.index) != DataType(DataType.Type.Integer)){
			compileErrors.append (CompileError(node.index.lineno, "index must return integer"));
		}
		// now make sure that the data is an array or a string
		DataType readFromType = getReturnType (node.readFromNode);
		if (readFromType.arrayDimensionCount == 0 && readFromType != DataType(DataType.Type.String)){
			compileErrors.append (CompileError(node.readFromNode.lineno, "cannnot use [..] on non-string non-array data"));
		}
	}
	/// checks a VariableNode
	void checkAST(ref VariableNode node){
		// make sure that that var was declared
		if (!varExists(node.varName)){
			compileErrors.append (CompileError(node.lineno,"variable "~node.varName~" not declared but used"));
		}
		// and put the assigned ID to it
		node.id = getVarID(node.varName);
	}
	/// checks an ArrayNode
	void checkAST(ArrayNode node){
		foreach (element; node.elements){
			checkAST (element);
		}
	}
public:
	this (Function[] predefinedFunctions){
		compileErrors = new LinkedList!CompileError;
		preDefFunctions = predefinedFunctions.dup;
	}
	~this(){
		.destroy(compileErrors);
	}
	/// adds a new "instruction-function". Any call that matches this function will be converted to an instruction rather than a 
	/// function call.
	/// 
	/// if an instruction already exists for that function, it will be overwritten
	void addInstructionFunction(Function f, string instruction){
		string fName = encodeFunctionName(f.name, f.argTypes);
		instructionFunctions[fName] = instruction;
	}
	/// checks a script's AST for any errors
	/// 
	/// Arguments:
	/// `node` is the ScriptNode for the script
	/// 
	/// Returns: errors in CompileError[] or just an empty array if there were no errors
	CompileError[] checkAST(ScriptNode node){
		// empty everything
		scriptDefFunctions = [];
		compileErrors.clear;
		varTypes.clear;
		varScope.clear;
		scopeDepth = 0;
		readFunctions(node);
		// call checkAST on every FunctionNode
		foreach (functionNode; node.functions){
			checkAST(functionNode);
		}
		CompileError[] r = compileErrors.toArray;
		.destroy(compileErrors);
		return r;
	}
	/// checks a script's AST for any errors
	/// 
	/// Arguments:
	/// `node` is the ScriptNode for the script  
	/// `scriptFunctions` is the array to put data about script defined functions in
	/// 
	/// Returns: errors in CompileError[], or empty array if there were no errors
	CompileError[] checkAST(ScriptNode node, ref Function[] scriptFunctions){
		CompileError[] errors = checkAST(node);
		scriptFunctions = scriptDefFunctions.dup;
		return errors;
	}
}
