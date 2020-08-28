/++
Functions to check if a script is valid (or certain nodes) by its generated AST
+/
module qscript.compiler.astcheck;

import qscript.compiler.misc;
import qscript.compiler.ast;

import utils.misc;
import utils.lists;

import std.conv : to;

/// Contains functions to check ASTs for errors  
/// One instance of this class can be used to check for errors in a script's AST.
class ASTCheck{
private:
	/// stores the libraries available. Index is the library ID.
	Library[] _libraries;
	/// stores all declarations of this script, public and private
	Library _this;
	/// stores this script's public declarations, this is what is exported at end
	Library _exports;
	/// stores number of variables in a scope. The 1st item is global variables, then come function-local ones
	Stack!uinteger _scopeVarCount;
	/// stores all the errors that are there in the AST being checked
	LinkedList!CompileError compileErrors;
	/// stores expected return type of currently-being-checked function
	DataType functionReturnType;
	/// registers a new  var in current scope
	/// 
	/// Returns: false if it was already registered or global variable with same name exists,  
	/// true if it was successful
	bool addVar(string name, DataType type, bool isGlobal = false){
		foreach (var; _this.vars){
			if (var.name == name)
				return false;
		}
		if (isGlobal && _scopeVarCount.count == 1)
			_exports.vars ~= Library.Variable(name, type);
		_this.vars ~= Library.Variable(name, type);
		_scopeVarCount.push(_scopeVarCount.pop + 1);
		return true;
	}
	/// Returns: true if a var exists. False if not.
	/// also sets the variable data type to `type` and id to `id`, and library id to `libraryId`, and 
	/// if it is global, sets `isGlobal` to `true`
	bool getVar(string name, ref DataType type, ref uinteger id, ref integer libraryId, ref bool isGlobal){
		foreach (i, var; _this.vars){
			if (var.name == name){
				type = var.type;
				id = i;
				isGlobal = false;
				libraryId = -1;
				return true;
			}
		}
		foreach (libId, library; _libraries){
			foreach (i, var; library.vars){
				if (var.name == name){
					type = var.type;
					id = i;
					isGlobal = true;
					libraryId = libId;
					return true;
				}
			}
		}
		return false;
	}
	/// Returns: variable ID for a variable with a name. Only use when you know the variable is local
	uinteger getVarID(string name){
		DataType type;
		uinteger id;
		integer libraryId;
		bool isGlobal;
		getVar(name, type, id, libraryId, isGlobal);
		return id;
	}
	/// Returns: true if a variable with a name is found
	bool varExists(string name){
		DataType type;
		uinteger id;
		integer libraryId;
		bool isGlobal;
		return getVar(name, type, id, libraryId, isGlobal);
	}
	/// increases the scope-depth
	/// 
	/// this function should be called before any AST-checking in a sub-BlockNode or anything like that is started
	void increaseScope(){
		_scopeVarCount.push(0);
	}
	/// decreases the scope-depth
	/// 
	/// this function should be called right after checking in a sub-BlockNode or anything like that is finished  
	/// it will put the vars declared inside that scope go out of scope
	void decreaseScope(){
		if (_scopeVarCount.count > 1){
			_this.vars.length -= _scopeVarCount.pop;
		}
	}
	/// Returns: true if a function exists, false if not. Sets function return type to `type`,
	/// id to `id`, and library id to `libraryId`
	bool getFunction(string name, DataType[] argTypes, ref DataType type, ref uinteger id,
		ref integer libraryId){
		foreach (i, func; _this.functions){
			if (func.name == name && func.argTypes == argTypes){
				type = func.returnType;
				id = i;
				libraryId = -1;
				return true;
			}
		}
		foreach (libId, lib; _libraries){
			foreach (i, func; lib.functions){
				if (func.name == name && func.argTypes == argTypes){
					type = func.returnType;
					id = i;
					libraryId  =libId;
					return true;
				}
			}
		}
		return false;
	}
	/// Returns: true if a struct exists, false if not. Sets struct data to `structData`
	bool getStruct(string name, ref Library.Struct structData){
		foreach (library; _this ~ _libraries){
			foreach (str; library.structs){
				if (str.name == name){
					structData = str;
					return true;
				}
			}
		}
		return false;
	}
	/// Returns: true if an enum exists, false if not. Sets enum data to `enumData`
	bool getEnum(string name, ref Library.Enum enumData){
		foreach (library; _this ~ _libraries){
			foreach (enu; library.enums){
				if (enu.name == name){
					enumData = enu;
					return true;
				}
			}
		}
		return false;
	}
	/// reads all FunctionNode from ScriptNode
	/// 
	/// any error is appended to compileErrors
	void readFunctions(ScriptNode node){
		/// first check for conflicts, also append public functions
		bool thisFunctionDeclared = false; // if the `this()` function has been declared
		foreach (funcId; 0 .. node.functions.length){
			FunctionNode funcA = node.functions[funcId];
			if (funcA.name == "this"){
				if (thisFunctionDeclared)
					compileErrors.append(CompileError(funcA.lineno, "`this` function defined multiple times"));
				else
					thisFunctionDeclared = true;
			}
			foreach (i; 0 .. funcId){
				FunctionNode funcB = node.functions[i];
				if (funcA.name == funcB.name && funcA.argTypes == funcB.argTypes)
					compileErrors.append(CompileError(funcB.lineno,
						"functions with same name must have different argument types"));
			}
			// append if public
			if (funcA.visibility == Visibility.Public){
				_this.functions ~= Function(funcA.name, funcA.returnType, funcA.argTypes);
				_exports.functions ~= _this.functions[$-1];
			}
		}
		// now append private functions
		foreach (i, func; node.functions){
			if (func.visibility == Visibility.Private)
				_this.functions ~= Function(func.name, func.returnType, func.argTypes);
		}
	}
	/// Reads all `VarDeclareNode`s from ScriptNode (global variable declarations)
	/// 
	/// any error is appended to compileErrors
	void readGlobVars(ref ScriptNode node){
		// check for conflicts among names, and append public 
		foreach (ref varDeclare; node.variables){
			foreach (varName; varDeclare.vars){
				// conflict check
				foreach (var; _this.vars){
					if (var.name == varName)
						compileErrors.append(CompileError(varDeclare.lineno, "global variable "~var.name~" is declared multiple times"));
				}
				// append
				if (varDeclare.visibility == Visibility.Public){
					// just assign it an id, it wont be used anywhere, but why not do it anyways?
					varDeclare.setVarID(varName, _this.vars.length);
					_this.vars ~= Library.Variable(varName, varDeclare.type);
					_exports.vars ~= _this.vars[$-1];
				}
			}
		}
		// now append the private ones
		foreach (ref varDeclare; node.variables){
			if (varDeclare.visibility == Visibility.Private){
				foreach (varName; varDeclare.vars){
					varDeclare.setVarID(varName, _this.vars.length);
					_this.vars ~= Library.Variable(varName, varDeclare.type);
				}
			}
		}
	}
	/// reads all EnumNode from ScriptNode
	/// 
	/// any error is appended to compileErrors
	void readEnums(ScriptNode node){
		// check for conflicts, and append public enums
		foreach (id; 0 .. node.enums.length){
			EnumNode enumA = node.enums[id];
			foreach (i; 0 .. id){
				EnumNode enumB = node.enums[i];
				if (enumA.name == enumB.name)
					compileErrors.append(CompileError(enumB.lineno, enumB.name~" is declared multiple times"));
			}
			if (enumA.visibility == Visibility.Public){
				_this.enums ~= enumA.toEnum;
				_exports.enums ~= _this.enums[$-1];
			}
		}
		// now do private enums
		foreach (currentEnum; node.enums){
			if (currentEnum.visibility == Visibility.Private)
				_this.enums ~= Library.Enum(currentEnum.name, currentEnum.members.dup);
		}
	}
	/// Reads all structs from ScriptNode
	/// 
	/// Checks for any circular dependency, and other issues. Appends errors to compileErrors
	void readStructs(ScriptNode node){
		// first check for conflicts in name, and append public struct to _exports
		foreach (id, currentStruct; node.structs){
			foreach (i; 0 .. id){
				if (node.structs[i].name == currentStruct.name)
					compileErrors.append(CompileError(currentStruct.lineno, currentStruct.name~" is declared multiple times"));
			}
			if (currentStruct.visibility == Visibility.Public){
				_this.structs ~= currentStruct.toStruct;
				_exports.structs ~= _this.structs[$-1];
			}
		}
		// now add private structs to _this
		foreach (currentStruct; node.structs){
			if (currentStruct.visibility == Visibility.Private)
				_this.structs ~= currentStruct.toStruct;
		}
		// now to check for recursive dependency
		List!string conflicts = new List!string;
		foreach (str; _this.structs)
			checkRecursiveDependency(str.name, conflicts);
		// add errors for all structs named in conflicts
		for (conflicts.seek = 0; conflicts.seek < conflicts.length; ){
			immutable string name = conflicts.read();
			// locate it's line number
			uinteger lineno;
			foreach (str; node.structs){
				if (str.name == name){
					lineno = str.lineno;
					break;
				}
			}
			compileErrors.append(CompileError(lineno, "recursive dependency detected"));
		}
		.destroy(conflicts);
	}
	/// Checks for circular dependency in a struct
	/// `name` is name of struct to check
	/// Puts names of structs where conflicts occur in `conflicting`
	/// `parents` are the structs that `name` struct is used in (i.e have member of type `name` struct)
	void checkRecursiveDependency(string name, List!string conflicting, immutable string[] parents = []){
		/// Returns: true if a string is a locally defined struct name
		static bool isLocalStruct(string name, Library.Struct[] structs){
			foreach (currStr; structs){
				if (currStr.name == name)
					return true;
			}
			return false;
		}
		// find that struct in _this, if not found, no big deal
		integer structId = -1;
		foreach (i, str; _this.structs){
			if (str.name == name){
				structId = i;
				break;
			}
		}
		if (structId >= 0){
			Library.Struct str = _this.structs[structId];
			/// structs must not be in members' data types
			immutable string[] notAllowed = parents ~ cast(immutable string[])[name];
			foreach (i; 0 .. str.membersName.length){
				string memberTypeName = str.membersDataType[i].typeName;
				// if not a locally defined struct, or is a ref, skip
				if (!isLocalStruct(memberTypeName, _this.structs) || str.membersDataType[i].isRef)
					continue;
				if (notAllowed.hasElement(memberTypeName)){
					if (conflicting.indexOf(name) < 0)
						conflicting.append(name);
				}else{
					// I used the recursion to destroy recursive dependency
					checkRecursiveDependency(str.membersName[i], conflicting, notAllowed);
				}
			}
		}
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
			getFunction(fCall.fName, argTypes, fCall.returnType, fCall.id, fCall.libraryId);
			return fCall.returnType;
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
			getVar(varNode.varName, varNode.returnType, varNode.id, varNode.libraryId, varNode.isGlobal);
			return varNode.returnType;
		}else if (node.type == CodeNode.Type.Array){
			ArrayNode arNode = node.node!(CodeNode.Type.Array);
			if (arNode.elements.length == 0){
				return DataType(DataType.Type.Void,1);
			}
			DataType r = getReturnType(arNode.elements[0]);
			r.arrayDimensionCount ++;
			return r;
		}else if (node.type == CodeNode.Type.MemberSelector){
			// TODO: implement getReturnType for MemberSelectorNode
		}
		return DataType(DataType.Type.Void);
	}
protected:
	/// checks if a FunctionNode is valid
	void checkAST(ref FunctionNode node){
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
		if (!getFunction(node.fName, argTypes, node.returnType, node.id, node.libraryId))
			compileErrors.append(CompileError(node.lineno,
					"function "~node.fName~" does not exist or cannot be called with these arguments"));
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
		}else if (node.type == CodeNode.Type.MemberSelector){
			checkAST(node.node!(CodeNode.Type.MemberSelector));
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
			if (operandType.isArray || operandType.isRef || 
				![DataType.Type.Byte, DataType.Type.Double, DataType.Type.Int,
				DataType.Type.Ubyte, DataType.Type.Uint].hasElement(operandType.type)){
				compileErrors.append (CompileError(node.lineno, "invalid data type for operand"));
			}
			node.returnType = operandType;
		}else if (["&&", "||"].hasElement(node.operator)){
			if (operandType != DataType(DataType.Type.Bool)){
				compileErrors.append (CompileError(node.lineno, "that operator can only be used on bool"));
			}
			node.returnType = DataType(DataType.Type.Bool);
		}else if (node.operator == "~"){
			if (operandType.arrayDimensionCount == 0){
				compileErrors.append (CompileError(node.lineno, "~ operator can only be used on arrays"));
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
			if (getReturnType(node.operand) != DataType(DataType.Type.Bool)){
				compileErrors.append (CompileError(node.operand.lineno, "can only use ! with a bool"));
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
		if (getReturnType(node.index) != DataType(DataType.Type.Uint)){
			compileErrors.append (CompileError(node.index.lineno, "index must be of type uint"));
		}
		// now make sure that the data is an array or a string
		DataType readFromType = getReturnType (node.readFromNode);
		if (readFromType.arrayDimensionCount == 0){
			compileErrors.append (CompileError(node.readFromNode.lineno, "cannnot use [..] on non-array data"));
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
		getVar(node.varName, node.returnType, node.id, node.libraryId, node.isGlobal);
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
	/// checks a MemberSelectorNode
	void checkAST(ref MemberSelectorNode node){
		// first check parent
		checkAST(node.parent);
		DataType rType = node.parent.returnType;
		// it's either going to be an enum, or a 
		// TODO
	}
public:
	/// constructor
	this (Library[] libraries){
		compileErrors = new LinkedList!CompileError;
		_scopeVarCount = new Stack!uinteger;
		_libraries = libraries.dup;
	}
	~this(){
		.destroy(compileErrors);
		.destroy(_scopeVarCount);
	}
	/// checks a script's AST for any errors
	/// 
	/// Arguments:
	/// `node` is the ScriptNode for the script
	/// 
	/// Returns: errors in CompileError[] or just an empty array if there were no errors
	CompileError[] checkAST(ref ScriptNode node){
		// empty everything
		compileErrors.clear;
		_scopeVarCount.clear;
		_this.clear;
		_exports.clear;
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
	CompileError[] checkAST(ref ScriptNode node, ref Library script){
		CompileError[] errors = checkAST(node);
		script = _exports;
		return errors;
	}
}
