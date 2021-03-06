/++
Functions to check if a script is valid (or certain nodes) by its generated AST
+/
module qscript.compiler.astcheck;

import qscript.compiler.compiler;
import qscript.compiler.ast;

import utils.misc;
import utils.lists;

import std.conv : to;

/// To temporarily store variables
private class VarStore{
private:
	/// variables exported by this library. index is ID
	List!Variable _vars;
	/// number of variables in different scopes
	List!uinteger _scopeVarCount;
	/// maximum number of variables declared in and after a specific scope (inside function)
	uinteger _scopeMaxVars;
	/// the scope to count max variables from
	uinteger _scopeIndexVarCount;
public:
	/// constructor
	this(){
		_scopeVarCount = new List!uinteger;
		_vars = new List!Variable;
		_scopeVarCount.append(0);
		_scopeMaxVars = 0;
		_scopeIndexVarCount = -1;
	}
	~this(){
		.destroy(_vars);
		.destroy(_scopeVarCount);
	}
	/// clears
	void clear(){
		_vars.clear();
		_scopeVarCount.clear;
		_scopeVarCount.append(0);
		_scopeMaxVars = 0;
		_scopeIndexVarCount = -1;
	}
	/// removes a number of variables
	void removeVars(uinteger count){
		if (count > _vars.length)
			_vars.clear;
		else
			_vars.removeLast(count);
	}
	/// increases scope
	void scopeIncrease(){
		_scopeVarCount.append(0);
	}
	/// decrease scope
	void scopeDecrease(){
		// count how many variables going away
		uinteger varCount = 0;
		if (_scopeIndexVarCount != -1){
			foreach (i; _scopeIndexVarCount .. _scopeVarCount.length)
				varCount += _scopeVarCount.read(i);
			if (varCount > _scopeMaxVars)
				_scopeMaxVars = varCount;
		}
		_vars.removeLast(_scopeVarCount.readLast);
		_scopeVarCount.removeLast();
		if (_scopeVarCount.length == 0)
			_scopeVarCount.append(0);
	}
	/// Start counting how many variables are going to be available in current scope
	void scopeVarCountStart(){
		_scopeIndexVarCount = cast(integer)_scopeVarCount.length-1;
		_scopeMaxVars = 0;
	}
	/// how many variables are in a scope (and in scopes within this scope and in...). Use `scopeVarCountStart` to specify scope
	/// 
	/// Call this AFTER `decreaseScope`
	/// 
	/// Returns: number of variables in scope
	@property uinteger scopeVarCount(){
		_scopeIndexVarCount = -1;
		return _scopeMaxVars;
	}
	/// variables exported by this library. index is ID
	@property Variable[] vars(){
		return _vars.toArray;
	}
	/// Returns: variable ID, or -1 if doesnt exist
	integer hasVar(string name, ref DataType type){
		_vars.seek = 0;
		while (_vars.seek < _vars.length){
			immutable Variable var = _vars.read;
			if (var.name == name){
				type = var.type;
				return _vars.seek - 1;
			}
		}
		return -1;
	}
	/// Returns: true if variable exists
	bool hasVar(string name){
		DataType dummy;
		return this.hasVar(name, dummy) > 0;
	}
	/// Adds a new variable.
	/// 
	/// Returns: Variable ID, or -1 if it already exists
	integer addVar(Variable var){
		if (this.hasVar(var.name))
			return -1;
		_vars.append(var);
		_scopeVarCount.set(cast(integer)_scopeVarCount.length-1, _scopeVarCount.readLast+1);
		return cast(integer)_vars.length-1;
	}
}

/// Contains functions to check ASTs for errors  
/// One instance of this class can be used to check for errors in a script's AST.
class ASTCheck{
private:
	/// stores the libraries available. Index is the library ID.
	Library[] _libraries;
	/// stores whether a library was imported. Index is library id
	bool[integer] _isImported;
	/// stores all declarations of this script, public and private. But not variables, those keep changes as going from function to function.
	/// _vars store them
	Library _this;
	/// variables that are curerntly in scope
	VarStore _vars;
	/// stores this script's public declarations, this is what is exported at end
	Library _exports;
	/// stores all the errors that are there in the AST being checked
	LinkedList!CompileError compileErrors;
	/// stores expected return type of currently-being-checked function
	DataType functionReturnType;
	/// registers a new  var in current scope
	/// 
	/// Returns: false if it was already registered or global variable with same name exists,  
	/// true if it was successful
	bool addVar(string name, DataType type, bool isGlobal = false){
		if (_vars.hasVar(name))
			return false;
		if (isGlobal)
			_exports.addVar(Variable(name, type));
		_vars.addVar(Variable(name, type));
		return true;
	}
	/// Returns: true if a var exists. False if not.
	/// also sets the variable data type to `type` and id to `id`, and library id to `libraryId`, and 
	/// if it is global, sets `isGlobal` to `true`
	bool getVar(string name, ref DataType type, ref integer id, ref integer libraryId, ref bool isGlobal){
		id = _vars.hasVar(name, type);
		if (id > -1){
			isGlobal = id < _exports.vars.length;
			libraryId = -1;
			return true;
		}
		foreach (libId, library; _libraries){
			if (!isImported(libId))
				continue;
			id = library.hasVar(name, type);
			if (id > -1){
				isGlobal = true;
				libraryId = libId;
				return true;
			}
		}
		return false;
	}
	/// Returns: variable ID for a variable with a name. Only use when you know the variable is local
	uinteger getVarID(string name){
		DataType type;
		integer id;
		integer libraryId;
		bool isGlobal;
		getVar(name, type, id, libraryId, isGlobal);
		return id;
	}
	/// Returns: true if a variable with a name is found
	bool varExists(string name){
		DataType type;
		integer id;
		integer libraryId;
		bool isGlobal;
		return getVar(name, type, id, libraryId, isGlobal);
	}
	/// Returns: true if a function exists, false if not. Sets function return type to `type`,
	/// id to `id`, and library id to `libraryId`
	bool getFunction(string name, DataType[] argTypes, ref DataType type, ref integer id,
		ref integer libraryId){
		id = _this.hasFunction(name, argTypes, type);
		if (id > -1){
			libraryId = -1;
			return true;
		}
		foreach (libId, lib; _libraries){
			if (!isImported(libId))
				continue;
			id = lib.hasFunction(name, argTypes, type);
			if (id > -1){
				libraryId = libId;
				return true;
			}
		}
		return false;
	}
	/// Returns: true if a struct exists, false if not. Sets struct data to `structData`
	bool getStruct(string name, ref Struct structData){
		if (_this.hasStruct(name, structData))
			return true;
		foreach (integer libId, lib; _libraries){
			if (!isImported(libId))
				continue;
			if (lib.hasStruct(name, structData))
				return true;
		}
		return false;
	}
	/// Returns: true if an enum exists, false if not. Sets enum data to `enumData`
	bool getEnum(string name, ref Enum enumData){
		if (_this.hasEnum(name, enumData))
			return true;
		foreach (integer libId, library; _libraries){
			if (!isImported(libId))
				continue;
			if (library.hasEnum(name, enumData))
				return true;
		}
		return false;
	}
	/// reads all imports from ScriptNode
	void readImports(ScriptNode node){
		_isImported[-1] = true; // first mark -1 as imported, coz thats used for local stuff
		foreach (importName; node.imports){
			integer index = -1;
			foreach (i, library; _libraries){
				if (library.name == importName){
					index = i;
					break;
				}
			}
			if (index == -1)
				compileErrors.append(CompileError(0, "cannot import "~importName~", does not exist"));
			_isImported[index] = true;
		}
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
			// if return type is an enum, change it to int
			if (funcA.returnType.isCustom){
				Enum dummyEnum;
				Struct dummyStruct;
				if (getEnum(funcA.returnType.typeName, dummyEnum))
					node.functions[funcId].returnType.type = DataType.Type.Int;
				else if (!getStruct(funcA.returnType.typeName, dummyStruct)){
					compileErrors.append(CompileError(funcA.lineno, "invalid data type "~funcA.returnType.typeName));
					continue;
				}
			}
			// append if public
			if (funcA.visibility == Visibility.Public){
				_this.addFunction(Function(funcA.name, funcA.returnType, funcA.argTypes));
				_exports.addFunction(Function(funcA.name, funcA.returnType, funcA.argTypes));
			}
		}
		// now append private functions
		foreach (i, func; node.functions){
			if (func.visibility == Visibility.Private)
				_this.addFunction(Function(func.name, func.returnType, func.argTypes));
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
				if (_vars.hasVar(varName))
					compileErrors.append(CompileError(varDeclare.lineno, "global variable "~varName~" is declared multiple times"));
				// append
				if (varDeclare.visibility == Visibility.Public){
					// just assign it an id, it wont be used anywhere, but why not do it anyways?
					varDeclare.setVarID(varName, _vars.vars.length);
					_vars.addVar(Variable(varName, varDeclare.type));
					_exports.addVar(Variable(varName, varDeclare.type));
				}
				// check type
				if (!isValidType(varDeclare.type))
					compileErrors.append(CompileError(varDeclare.lineno, "invalid data type"));
			}
		}
		// now append the private ones
		foreach (ref varDeclare; node.variables){
			if (varDeclare.visibility == Visibility.Private){
				foreach (varName; varDeclare.vars){
					varDeclare.setVarID(varName, _vars.vars.length);
					_vars.addVar(Variable(varName, varDeclare.type));
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
				_this.addEnum(enumA.toEnum);
				_exports.addEnum(enumA.toEnum);
			}
		}
		// now do private enums
		foreach (currentEnum; node.enums){
			if (currentEnum.visibility == Visibility.Private)
				_this.addEnum(Enum(currentEnum.name, currentEnum.members.dup));
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
				_this.addStruct(currentStruct.toStruct);
				_exports.addStruct(currentStruct.toStruct);
			}
		}
		// now add private structs to _this
		foreach (currentStruct; node.structs){
			if (currentStruct.visibility == Visibility.Private)
				_this.addStruct(currentStruct.toStruct);
		}
		// now look at data types of members
		foreach (currentStruct; node.structs){
			foreach (i, type; currentStruct.membersDataType){
				if (!isValidType(currentStruct.membersDataType[i]))
					compileErrors.append(CompileError(currentStruct.lineno,
						"struct member "~currentStruct.membersName[i]~" has invalid data type"));
			}
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
		static bool isLocalStruct(string name, Struct[] structs){
			foreach (currStr; structs){
				if (currStr.name == name)
					return true;
			}
			return false;
		}
		Struct str;
		if (_this.hasStruct(name, str)){
			// structs must not be in members' data types
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
			// hardcoded 2 lines below, beware
			if (opNode.operator == "@")
				operandType.isRef = operandType.isRef ? false : true;
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
			MemberSelectorNode memberSelector = node.node!(CodeNode.Type.MemberSelector);
			if (memberSelector.returnType.type == DataType.Type.Void)
				checkAST(memberSelector);
			return memberSelector.returnType;
		}
		return DataType(DataType.Type.Void);
	}
	/// Returns: true if a data type is valid (enum name is a not a valid data type btw, use int)
	bool isValidType(ref DataType type){
		if (!type.isCustom)
			return true;
		Struct str;
		if (_this.hasStruct(type.typeName, str)){
			type.customLength = str.membersName.length;
			return true;
		}
		// now time to search in all libraries' structs names
		foreach (integer libId, lib; _libraries){
			if (!isImported(libId-1))
				continue;
			if (lib.hasStruct(type.typeName, str)){
				type.customLength = str.membersName.length;
				return true;
			}
		}
		return false;
	}
	/// Returns: true if a library is imported
	bool isImported(integer id){
		if (id >= _libraries.length)
			return false;
		if (_libraries[id].autoImport)
			return true;
		if (id in _isImported)
			return _isImported[id];
		return false;
	}
protected:
	/// checks if a FunctionNode is valid
	void checkAST(ref FunctionNode node){
		_vars.scopeIncrease();
		_vars.scopeVarCountStart();
		functionReturnType = node.returnType;
		if (!isValidType(node.returnType))
			compileErrors.append(CompileError(node.lineno, "invalid data type"));
		// add the arg's to the var scope. make sure one arg name is not used more than once
		foreach (i, arg; node.arguments){
			if (!addVar(arg.argName, arg.argType)){
				compileErrors.append(CompileError(node.lineno, "argument name '"~arg.argName~"' has been used more than once"));
			}
		}
		// now check the statements
		checkAST(node.bodyBlock);
		_vars.scopeDecrease();
		node.varStackCount = _vars.scopeVarCount/* + node.arguments.length*/;
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
				if (lType.arrayDimensionCount != rType.arrayDimensionCount || !lType.type.canImplicitCast(rType.type) ||
				lType.isRef != rType.isRef){
					compileErrors.append(CompileError(node.lineno, "rvalue and lvalue data type not matching"));
				}
			}
		}
	}
	/// checks a BlockNode
	void checkAST(ref BlockNode node, bool ownScope = true){
		if (ownScope)
			_vars.scopeIncrease();
		for (uinteger i=0; i < node.statements.length; i ++){
			checkAST(node.statements[i]);
		}
		if (ownScope)
			_vars.scopeDecrease();
	}
	/// checks a DoWhileNode
	void checkAST(ref DoWhileNode node){
		_vars.scopeIncrease();
		checkAST(node.condition);
		if (node.condition.returnType.canImplicitCast(DataType(DataType.Type.Bool)))
			compileErrors.append(CompileError(node.condition.lineno, "condition must return a bool value"));
		if (node.statement.type == StatementNode.Type.Block){
			checkAST(node.statement.node!(StatementNode.Type.Block), false);
		}else{
			checkAST(node.statement);
		}
		_vars.scopeDecrease();
	}
	/// checks a ForNode
	void checkAST(ref ForNode node){
		_vars.scopeIncrease();
		// first the init statement
		checkAST(node.initStatement);
		// then the condition
		checkAST(node.condition);
		if (!node.condition.returnType.canImplicitCast(DataType(DataType.Type.Bool)))
			compileErrors.append(CompileError(node.condition.lineno, "condition must return a bool value"));
		// then the increment one
		checkAST(node.incStatement);
		// finally the loop body
		checkAST(node.statement);
		_vars.scopeDecrease();
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
		// do not let it call `this`
		else if (node.fName == "this")
			compileErrors.append(CompileError(node.lineno, "calling `this` function is not allowed"));
	}
	/// checks an IfNode
	void checkAST(ref IfNode node){
		// first the condition
		checkAST(node.condition);
		if (!node.condition.returnType.canImplicitCast(DataType(DataType.Type.Bool)))
			compileErrors.append(CompileError(node.condition.lineno, "condition must return a bool value"));
		// then statements
		_vars.scopeIncrease();
		checkAST(node.statement);
		_vars.scopeDecrease();
		if (node.hasElse){
			_vars.scopeIncrease();
			checkAST(node.elseStatement);
			_vars.scopeDecrease();
		}
	}
	/// checks a VarDeclareNode
	void checkAST(ref VarDeclareNode node){
		// check data type
		if (!isValidType(node.type))
			compileErrors.append(CompileError(node.lineno, "invalid data type"));
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
		if (!node.condition.returnType.canImplicitCast(DataType(DataType.Type.Bool)))
			compileErrors.append(CompileError(node.condition.lineno, "condition must return a bool value"));
		// the the statement
		_vars.scopeIncrease();
		checkAST(node.statement);
		_vars.scopeDecrease();
	}
	/// checks a ReturnNode
	void checkAST(ref ReturnNode node){
		/// check the value
		checkAST(node.value);
		if (!node.value.returnType.canImplicitCast(functionReturnType) && 
			!(functionReturnType.type == DataType.Type.Void && // let `return null;` be valid for void functions
			node.value.returnType.canImplicitCast(DataType(DataType.Type.Void,0,true)))){

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
		CompileError err = CompileError(node.lineno, "can only use - operator on numerical data types");
		if (node.value.returnType.isArray || node.returnType.isRef)
			compileErrors.append(err);
		else if (!node.value.returnType.type.canImplicitCast(DataType.Type.Int) && 
			!node.value.returnType.type.canImplicitCast(DataType.Type.Double))
			compileErrors.append(err);
	}
	/// checks a OperatorNode
	void checkAST(ref OperatorNode node){
		if (node.operator !in OPERATOR_FUNCTIONS){
			compileErrors.append(CompileError(node.lineno, "operator has no corresponding function"));
			return;
		}
		node.fCall = FunctionCallNode(OPERATOR_FUNCTIONS[node.operator], node.operands);
		node.fCall.lineno = node.lineno;
		// just use the FunctionCallNode
		checkAST(node.fCall);
	}
	/// checks a SOperatorNode
	void checkAST(ref SOperatorNode node){
		if (node.operator !in OPERATOR_FUNCTIONS){
			compileErrors.append(CompileError(node.lineno, "operator has no corresponding function"));
			return;
		}
		if (node.operator == "@"){
			checkAST(node.operand);
			DataType type = node.operand.returnType;
			type.isRef = !type.isRef;
			node.returnType = type;
			// do not allow ref from or deref from any type involving void
			if (type.type == DataType.Type.Void)
				compileErrors.append(CompileError(node.lineno, "Cannot use @ operator on a void"));
			return;
		}
		node.fCall = FunctionCallNode(OPERATOR_FUNCTIONS[node.operator], [node.operand]);
		node.fCall.lineno = node.lineno;
		checkAST(node.fCall);
	}
	/// checks a ReadElement
	void checkAST(ref ReadElement node){
		// check the var, and the index
		checkAST (node.readFromNode);
		checkAST (node.index);
		// index must return int
		if (getReturnType(node.index).canImplicitCast(DataType(DataType.Type.Int))){
			compileErrors.append (CompileError(node.index.lineno,
				"cannot implicitly cast "~getReturnType(node.index).name~" to uint"));
		}
		// now make sure that the data is an array or a string
		immutable DataType readFromType = getReturnType (node.readFromNode);
		if (readFromType.arrayDimensionCount == 0)
			compileErrors.append (CompileError(node.readFromNode.lineno, "cannnot use [..] on non-array data"));
		if (readFromType.isRef)
			compileErrors.append (CompileError(node.readFromNode.lineno, "cannot use [..] on references"));
		node.returnType = readFromType;
		node.returnType.arrayDimensionCount --;
	}
	/// checks a VariableNode
	void checkAST(ref VariableNode node){
		// make sure that that var was declared
		if (!varExists(node.varName)){
			compileErrors.append (CompileError(node.lineno,"variable "~node.varName~" not declared but used"));
		}
		// just call this to write struct size just in case it is a struct
		isValidType(node.returnType);
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
				if (typeMatches && !node.elements[i].returnType.canImplicitCast(type)){
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
		// first check parent, could be an enum, so first match names
		if (node.parent.type == CodeNode.Type.Variable){
			Enum enumData;
			string enumName = node.parent.node!(CodeNode.Type.Variable).varName;
			if (getEnum(enumName, enumData)){
				node.memberNameIndex = enumData.members.indexOf(node.memberName);
				if (node.memberNameIndex < 0){
					compileErrors.append(CompileError(node.lineno, "enum "~enumName~" has no member named "~node.memberName));
				}
				node.type = MemberSelectorNode.Type.EnumMemberRead;
				node.returnType = DataType(DataType.Type.Int);
				return;
			}
		}
		checkAST(node.parent);
		string parentDataTypeName = node.parent.returnType.name;
		Struct parentStructType;
		// not gonna work if its a reference to that type, or an array
		if (getStruct(parentDataTypeName, parentStructType)){
			// check if that struct has some member of that name
			node.memberNameIndex = parentStructType.membersName.indexOf(node.memberName);
			if (node.memberNameIndex > -1){
				node.type = MemberSelectorNode.Type.StructMemberRead;
				node.returnType = parentStructType.membersDataType[node.memberNameIndex];
			}else
				compileErrors.append(
					CompileError(node.lineno, "no member with name "~node.memberName~" exists in struct "~parentDataTypeName));
		}else{
			compileErrors.append(CompileError(node.parent.lineno, "invalid data type of operand for . operator"));
		}
	}
public:
	/// constructor
	this (Library[] libraries){
		compileErrors = new LinkedList!CompileError;
		_libraries = libraries.dup;
		_vars = new VarStore();
	}
	~this(){
		.destroy(compileErrors);
		.destroy(_vars);
	}
	/// checks a script's AST for any errors
	/// 
	/// Arguments:
	/// `node` is the ScriptNode for the script  
	/// `scriptFunctions` is the array to put data about script defined functions in
	/// 
	/// Returns: errors in CompileError[] or just an empty array if there were no errors
	CompileError[] checkAST(ref ScriptNode node, Library exports, Library allDeclerations){
		// empty everything
		compileErrors.clear;
		_vars.clear;
		_exports = exports;
		_this = allDeclerations;
		readImports(node);
		readEnums(node);
		readStructs(node);
		readGlobVars(node);
		readFunctions(node);
		// call checkAST on every FunctionNode
		for (uinteger i=0; i < node.functions.length; i++){
			checkAST(node.functions[i]);
			node.functions[i].id = i; // set the id
		}
		_exports = null;
		_this = null;
		CompileError[] r = compileErrors.toArray;
		.destroy(compileErrors);
		return r;
	}
	/// checks a script's AST for any errors
	CompileError[] checkAST(ref ScriptNode node){
		Library lib = new Library("THIS"), priv = new Library("_THIS");
		CompileError[] r = checkAST(node, lib, priv);
		.destroy(lib);
		.destroy(priv);
		return r;
	}
}
