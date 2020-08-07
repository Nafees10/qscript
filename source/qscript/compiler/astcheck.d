/++
Functions to check if a script is valid (or certain nodes) by its generated AST
+/
module qscript.compiler.astcheck;

import qscript.compiler.misc;
import qscript.compiler.ast;

import utils.misc;
import utils.lists;

/// Contains functions to check ASTs for errors  
/// One instance of this class can be used to check for errors in a script's AST.
class ASTCheck{
private:
	/// stores the libraries available. Index is the library ID. Index=0 is this script
	Library[] _libraries;
	/// stores private functions
	Function[] _privateFunctions;
	/// stores all the errors that are there in the AST being checked
	LinkedList!CompileError compileErrors;
	/// stores data types of variables in currently-being-checked-FunctionNode
	DataType[string] varTypes;
	/// stores the IDs (as index) for vars
	string[uinteger] varIDs;
	/// stores the scope-depth of each var in currently-being-checked-FunctionNode which is currently in scope
	uinteger[string] varScope;
	/// stores expected return type of currently-being-checked function
	DataType functionReturnType;
	/// the largest variable id in currectly being-checked function
	integer maxVarId;
	/// stores current scope-depth
	uinteger scopeDepth = 0;
	/// registers a new var in current scope
	/// 
	/// Returns: false if it was already registered or global variable with same name exists,  
	/// true if it was successful
	bool addVar(string name, DataType type, bool isPublic = false){
		if (name in varTypes){
			return false;
		}
		foreach (library; _libraries){
			foreach (globVar; library.vars){
				if (globVar.name == name)
					return false;
			}
		}
		if (scopeDepth == 0 && isPublic)
			_libraries[0].vars ~= Library.GlobalVar(name, type);
		else
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
		foreach (library; _libraries){
			foreach (globVar; library.vars){
				if (globVar.name == name)
					return globVar.type;
			}
		}
		return DataType();
	}
	/// Returns: the ID for a variable. or -1 if it does not exist  
	/// libraryId is only valid if isGlobal == true 
	integer getVarID(string name, ref bool isGlobal, ref uinteger libraryId){
		libraryId = 0;
		foreach (id, varName; varIDs){
			if (name == varName){
				isGlobal = varScope[name] == 0 ? true : false;
				return id;
			}
		}
		foreach (libId, library; _libraries){
			foreach (i, globVar; library.vars){
				if (globVar.name == name){
					isGlobal = true;
					libraryId = libId;
					return i;
				}
			}
		}
		return -1;
	}
	/// ditto
	integer getVarID(string name){
		
	}
	/// Returns: true if a var is available in current scope
	bool varExists(string name){
		foreach (lib; _libraries){
			foreach (var; lib.vars){
				if (var.name == name)
					return true;
			}
		}
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
		if (scopeDepth > 0){
			foreach (key; varScope.keys){
				if (varScope[key] == scopeDepth){
					varScope.remove(key);
					// remove from varDataTypes too!
					if (key in varTypes)
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
			scopeDepth --;
		}
	}
	/// Returns: return type of a function, works for both script-defined and predefined functions  
	/// or if the function does not exist, it'll return `DataType()`
	DataType getFunctionType(string name, DataType[] argTypes){
		foreach (func; _privateFunctions){
			if (func.name == name && func.argTypes == argTypes){
				return func.returnType;
			}
		}
		foreach (lib; _libraries){
			foreach (func; lib.functions){
				if (func.name == name && func.argTypes == argTypes)
					return func.returnType;
			}
		}
		return DataType();
	}
	/// Returns: return type for a CodeNode
	/// 
	/// In case there's an error, returns `DataType()`
	DataType getReturnType(CodeNode node){
		if (node.returnType != DataType(DataType.Type.Void)){
			return node.returnType;
		}
		if (node.type == CodeNode.Type.FunctionCall){
			DataType[] argTypes;
			FunctionCallNode fCall = node.node!(CodeNode.Type.FunctionCall);
			argTypes.length = fCall.arguments.length;
			foreach (i, arg; fCall.arguments){
				argTypes[i] = getReturnType(arg);
			}
			node.returnType = getFunctionType(fCall.fName, argTypes);
			return node.returnType;
		}else if (node.type == CodeNode.Type.Literal){
			return node.node!(CodeNode.Type.Literal).returnType;
		}else if (node.type == CodeNode.Type.Operator){
			OperatorNode opNode = node.node!(CodeNode.Type.Operator);
			if (BOOL_OPERATORS.hasElement(opNode.operator))
				return DataType(DataType.Type.Int);
			return opNode.operands[0].returnType;
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
				return DataType();
			}
			readFromType.arrayDimensionCount --;
			return readFromType;
		}else if (node.type == CodeNode.Type.Variable){
			VariableNode varNode = node.node!(CodeNode.Type.Variable);
			return getVarType(varNode.varName);
		}else if (node.type == CodeNode.Type.Array){
			ArrayNode arNode = node.node!(CodeNode.Type.Array);
			if (arNode.elements.length == 0){
				return DataType(DataType.Type.Void,1);
			}
			DataType r = getReturnType(arNode.elements[0]);
			r.arrayDimensionCount ++;
			return r;
		}
		return DataType(DataType.Type.Void);
	}
	/// reads all FunctionNode from ScriptNode and writes them into `scriptDefFunctions` & `_libraries[0].functions`
	/// 
	/// any error is appended to compileErrors
	void readFunctions(ScriptNode node){
		/// stores the functions in byte code style, coz that way, its easier to check if same function with same
		/// arg types has been used more than once
		string[] byteCodefunctionNames;
		byteCodefunctionNames.length = node.functions.length;
		foreach (i, func; node.functions){
			// read arg types into a single array
			DataType[] argTypes;
			argTypes.length = func.arguments.length;
			foreach (index, arg; func.arguments)
				argTypes[index] = arg.argType;
			if (func.visibility == Visibility.Private)
				_privateFunctions ~= Function(func.name, func.returnType, argTypes);
			else
				_libraries[0].functions ~= Function(func.name, func.returnType, argTypes);
			// check if it was previously declared as a private function
			byteCodefunctionNames[i] = encodeFunctionName(func.name, argTypes);
			if (byteCodefunctionNames[0 .. i].hasElement(byteCodefunctionNames[i])){
				compileErrors.append (CompileError(func.lineno,
						"functions with same name must have different argument types"));
			}
			/// check if it was previously declared as a public function
			foreach (libFunc; _libraries[0].functions){
				if (func.name == libFunc.name && argTypes == libFunc.argTypes)
					compileErrors.append (CompileError(func.lineno,
						"functions with same name must have different argument types"));
			}
		}
	}
protected:
	/// checks if a FunctionNode is valid
	void checkAST(ref FunctionNode node){
		maxVarId = (cast(integer)node.arguments.length) - 1;
		increaseScope();
		functionReturnType = node.returnType;
		// add the arg's to the var scope. make sure one arg name is not used more than once
		foreach (i, arg; node.arguments){
			if (!addVar(arg.argName, arg.argType)){
				compileErrors.append(CompileError(node.lineno, "argument name '"~arg.argName~"' has been used more than once"));
			}
		}
		// now check the statements
		checkAST(node.bodyBlock);
		node.varCount = maxVarId + 1;
		decreaseScope();
	}
	/// checks if a StatementNode is valid
	void checkAST(ref StatementNode node){
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
		}else if (node.type == StatementNode.Type.Return){
			checkAST(node.node!(StatementNode.Type.Return));
		}
	}
	/// checks a AssignmentNode
	void checkAST(ref AssignmentNode node){
		// make sure var exists, checkAST(VariableNode) does that
		checkAST(node.lvalue);
		checkAST(node.rvalue);
		const DataType lType = node.lvalue.returnType, rType = node.rvalue.returnType;
		// allow only de-ref-ing references
		if (node.deref && !lType.isRef){
			compileErrors.append(CompileError(node.lvalue.lineno, "can only deref (@) a reference"));
		}else{
			// go on, do some more tests
			if (node.deref){
				if (lType.isRef == rType.isRef){
					compileErrors.append(CompileError(node.lineno, "rvalue and lvalue data type not matching"));
				}
			}else{
				if (lType.arrayDimensionCount != rType.arrayDimensionCount || lType.type != rType.type ||
				lType.isRef != rType.isRef){
					compileErrors.append(CompileError(node.lineno, "rvalue and lvalue data type not matching"));
				}
			}
		}
	}
	/// checks a BlockNode
	void checkAST(ref BlockNode node, bool ownScope = true){
		if (ownScope)
			increaseScope();
		for (uinteger i=0; i < node.statements.length; i ++){
			checkAST(node.statements[i]);
		}
		if (ownScope)
			decreaseScope();
	}
	/// checks a DoWhileNode
	void checkAST(ref DoWhileNode node){
		increaseScope();
		checkAST(node.condition);
		if (node.statement.type == StatementNode.Type.Block){
			checkAST(node.statement.node!(StatementNode.Type.Block), false);
		}else{
			checkAST(node.statement);
		}
		decreaseScope();
	}
	/// checks a ForNode
	void checkAST(ref ForNode node){
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
	void checkAST(ref FunctionCallNode node){
		/// store the arguments types
		DataType[] argTypes;
		argTypes.length = node.arguments.length;
		// while moving the type into separate array, perform the checks on the args themselves
		for (uinteger i=0; i < node.arguments.length; i ++){
			checkAST(node.arguments[i]);
			argTypes[i] = node.arguments[i].returnType;
		}
		// now make sure that that function exists, and the arg types match
		bool functionExists = false;
		foreach (i, func; _privateFunctions){
			if (func.name == node.fName && func.argTypes == argTypes){
				functionExists = true;
				node.libraryId = 0;
				node.id = i;
				node.returnType = func.returnType;
			}
		}
		if (!functionExists){
			foreach (libId, library; _libraries){
				foreach (i, func; library.functions){
					if (func.name == node.fName && func.argTypes == argTypes){
						functionExists = true;
						node.libraryId = libId;
						node.id = i;
						node.returnType = func.returnType;
					}
				}
			}
		}
		if (!functionExists){
			compileErrors.append(CompileError(node.lineno,
					"function "~node.fName~" does not exist or cannot be called with these arguments"));
		}
	}
	/// checks an IfNode
	void checkAST(ref IfNode node){
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
				CodeNode* value = &(node.getValue(varName));
				checkAST(*value);
				// make sure that value can be assigned
				if (getReturnType(*value) != node.type){
					compileErrors.append(CompileError(node.lineno, "cannot assign value of different data type"));
				}
			}
			// assign it an id
			addVar (varName, node.type);
			// set it's ID
			uinteger vId = getVarID(varName);
			if (cast(integer)vId > maxVarId)
				maxVarId = cast(integer)vId;
			node.setVarID(varName, vId);
		}
	}
	/// checks a WhileNode
	void checkAST(ref WhileNode node){
		// first condition
		checkAST(node.condition);
		// the the statement
		increaseScope();
		checkAST(node.statement);
		decreaseScope();
	}
	/// checks a ReturnNode
	void checkAST(ref ReturnNode node){
		/// check the value
		checkAST(node.value);
		if (node.value.returnType != functionReturnType || functionReturnType.type == DataType.Type.Void){
			compileErrors.append(CompileError(node.value.lineno,"wrong data type for return value"));
		}
	}
	/// checks a CodeNode
	void checkAST(ref CodeNode node){
		if (node.type == CodeNode.Type.FunctionCall){
			checkAST(node.node!(CodeNode.Type.FunctionCall));
		}else if (node.type == CodeNode.Type.Literal){
			// nothing to check
		}else if (node.type == CodeNode.Type.Negative){
			checkAST(node.node!(CodeNode.Type.Negative));
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
	/// checks a NegativeValueNode
	void checkAST(ref NegativeValueNode node){
		// check the val
		checkAST(node.value);
		// make sure data type is either double or integer, nothing else works
		if (node.value.returnType.isArray || ![DataType.Type.Int, DataType.Type.Double].hasElement(node.returnType.type)){
			compileErrors.append(CompileError(node.lineno, "cannot do use - operator on non-int & non-double types"));
		}
		if (node.value.returnType.isRef){
			compileErrors.append(CompileError(node.lineno, "cannot use - operator on references"));
		}
	}
	/// checks a OperatorNode
	void checkAST(ref OperatorNode node){
		// check the operands
		for (uinteger i=0; i < node.operands.length; i ++){
			checkAST (node.operands[i]);
		}
		// make sure both operands are of same data type
		DataType operandType = getReturnType(node.operands[0]);
		if (getReturnType(node.operands[0]) != getReturnType(node.operands[1])){
			compileErrors.append(CompileError(node.lineno, "Both operands for operator must be of same type"));
		}
		// now make sure that the data type of operands is allowed with that operator
		if (["+","-","*","/","%", "<", ">", ">=", "<="].hasElement(node.operator)){
			// only double and int allowed
			if (operandType != DataType(DataType.Type.Int) && operandType != DataType(DataType.Type.Double)){
				compileErrors.append (CompileError(node.lineno, "that operator can only be used on double or int"));
			}
			node.returnType = operandType;
		}else if (["&&", "||"].hasElement(node.operator)){
			if (operandType != DataType(DataType.Type.Int)){
				compileErrors.append (CompileError(node.lineno, "that operator can only be used on int"));
			}
			node.returnType = DataType(DataType.Type.Int);
		}else if (node.operator == "~"){
			if (operandType.arrayDimensionCount == 0){
				compileErrors.append (CompileError(node.lineno, "~ operator can only be used on strings and arrays"));
			}
			node.returnType = operandType;
		}
	}
	/// checks a SOperatorNode
	void checkAST(ref SOperatorNode node){
		// check the operand
		checkAST(node.operand);
		// now it it's `!`, only accept int, if `@`, var
		if (node.operator == "!"){
			if (getReturnType(node.operand) != DataType(DataType.Type.Int)){
				compileErrors.append (CompileError(node.operand.lineno, "cannot use ! on a non-int data type"));
			}
			node.returnType = DataType(DataType.Type.Int);
		}else if (node.operator == "@"){
			node.returnType = node.operand.returnType;
			node.returnType.isRef = !node.returnType.isRef;
			// if it's used to get a ref, it can only be used on variables, nothing else.
			if (!node.operand.returnType.isRef && node.operand.type != CodeNode.Type.Variable){
				// could be that it's getting ref of ReadElement, check it that's the case
				CodeNode subNode = node.operand;
				while (subNode.type == CodeNode.Type.ReadElement){
					subNode = subNode.node!(CodeNode.Type.ReadElement).readFromNode;
				}
				if (subNode.type != CodeNode.Type.Variable)
					compileErrors.append(CompileError(node.lineno, "@ can only be used to get reference of variables"));
			}
		}else
			compileErrors.append (CompileError(node.lineno, "invalid operator"));
	}
	/// checks a ReadElement
	void checkAST(ref ReadElement node){
		// check the var, and the index
		checkAST (node.readFromNode);
		checkAST (node.index);
		// index must return int
		if (getReturnType(node.index) != DataType(DataType.Type.Int)){
			compileErrors.append (CompileError(node.index.lineno, "index must return integer"));
		}
		// now make sure that the data is an array or a string
		DataType readFromType = getReturnType (node.readFromNode);
		if (readFromType.arrayDimensionCount == 0){
			compileErrors.append (CompileError(node.readFromNode.lineno, "cannnot use [..] on non-string non-array data"));
		}
		node.returnType = readFromType;
		node.returnType.arrayDimensionCount --;
		/// `[..]` can not be used on refs
		if (readFromType.isRef){
			compileErrors.append (CompileError(node.readFromNode.lineno, "cannot use [..] on references"));
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
		// set it's type
		node.returnType = getVarType(node.varName);
	}
	/// checks an ArrayNode
	void checkAST(ref ArrayNode node){
		// check each element, and make sure all their types are same
		if (node.elements.length > 0){
			checkAST(node.elements[0]);
			DataType type = getReturnType(node.elements[0]);
			bool typeMatches = true;
			for (uinteger i=1; i < node.elements.length; i ++){
				checkAST (node.elements[i]);
				if (typeMatches && node.elements[i].returnType != type){
					compileErrors.append (CompileError(node.elements[i].lineno, "elements in array must be of same type"));
					typeMatches = false;
				}
			}
			node.returnType = type;
			node.returnType.arrayDimensionCount ++;
		}else
			node.returnType = DataType(DataType.Type.Void,1);
	}
public:
	this (Function[] predefinedFunctions){
		compileErrors = new LinkedList!CompileError;
		preDefFunctions = predefinedFunctions.dup;
	}
	~this(){
		.destroy(compileErrors);
	}
	/// checks a script's AST for any errors
	/// 
	/// Arguments:
	/// `node` is the ScriptNode for the script
	/// 
	/// Returns: errors in CompileError[] or just an empty array if there were no errors
	CompileError[] checkAST(ref ScriptNode node){
		// empty everything
		scriptDefFunctions = [];
		compileErrors.clear;
		varTypes.clear;
		varScope.clear;
		scopeDepth = 0;
		readFunctions(node);
		// call checkAST on every FunctionNode
		for (uinteger i=0; i < node.functions.length; i++){
			checkAST(node.functions[i]);
			node.functions[i].id = i; // set the id
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
	CompileError[] checkAST(ref ScriptNode node, ref Function[] scriptFunctions){
		CompileError[] errors = checkAST(node);
		scriptFunctions = scriptDefFunctions.dup;
		return errors;
	}
}
