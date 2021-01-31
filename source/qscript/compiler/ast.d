/++
Contains definitions for "nodes" making the AST
+/
module qscript.compiler.ast;

import utils.misc;
import utils.lists;
import qscript.compiler.misc;
import qscript.compiler.tokengen : Token, TokenList;

import std.conv : to;

/// a node representing the script
package struct ScriptNode{
	/// list of functions defined in this script
	public FunctionNode[] functions;
	/// structs defined in this script
	public StructNode[] structs;
	/// enums defined in this script
	public EnumNode[] enums;
	/// global variables defined in this script
	public VarDeclareNode[] variables;
	/// stores what this script imports
	public string[] imports;
	/// constructor
	this (FunctionNode[] scriptFunctions){
		functions = scriptFunctions.dup;
	}
}

/// a node representing a function definition
package struct FunctionNode{
	/// struct to store arguments for function
	public struct Argument{
		string argName; /// the name of the var storing the arg
		DataType argType; /// the data type of the arg
		/// constructor
		this (string name, DataType type){
			argName = name;
			argType = type;
		}
	}
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// Stores visibility for this node
	public Visibility visibility = Visibility.Private;
	/// stores arguments with their data type
	public FunctionNode.Argument[] arguments;
	/// returns: data types of arguments
	public @property DataType[] argTypes(){
		DataType[] r;
		r.length = arguments.length;
		foreach (i, arg; arguments){
			r[i] = arg.argType;
		}
		return r;
	}
	/// the name of the function
	public string name;
	/// body block of this function
	public BlockNode bodyBlock;
	/// the data type of the return value of this function
	public DataType returnType = DataType(DataType.Type.Void);
	/// the id of this function, assigned after checkAST has been called on this
	public uinteger id;
	/// constructor
	this (DataType returnDataType, string fName, FunctionNode.Argument[] funcArgs, BlockNode fBody){
		bodyBlock = fBody;
		name = fName;
		arguments = funcArgs.dup;
		returnType = returnType;
	}
	/// Returns: the data types for arguments
	@property DataType[] argumentTypes(){
		DataType[] r;
		r.length = arguments.length;
		foreach (i, arg; arguments){
			r[i] = arg.argType;
		}
		return r;
	}
	/// Returns: the names for arguments
	@property string[] argumentNames(){
		string[] r;
		r.length = arguments.length;
		foreach (i, arg; arguments){
			r[i] = arg.argName;
		}
		return r;
	}
}

/// To store a struct definition
package struct StructNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// Stores visibility for this node
	public Visibility visibility = Visibility.Private;
	/// the actual struct
	private Library.Struct _struct;
	/// the name of this struct
	public @property string name(){
		return _struct.name;
	}
	/// ditto
	public @property string name(string newName){
		return _struct.name = newName;
	}
	/// name of members of this struct
	public @property ref string[] membersName() return {
		return _struct.membersName;
	}
	/// ditto
	public @property ref string[] membersName(string[] newMembersName) return {
		return _struct.membersName = newMembersName;
	}
	/// data types of members of this struct
	public @property ref DataType[] membersDataType() return{
		return _struct.membersDataType;
	}
	/// ditto
	public @property ref DataType[] membersDataType(DataType[] newMembersDataType) return{
		return _struct.membersDataType = newMembersDataType;
	}
	/// Returns: true if this struct contains a reference
	public @property bool containsRef(){
		foreach (type; _struct.membersDataType){
			if (type.isRef)
				return true;
		}
		return false;
	}
	/// Returns: Library.Struct representing this
	public @property Library.Struct toStruct(){
		return _struct;
	}
}

/// To store a enum definition
package struct EnumNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// Stores visibility for this node
	public Visibility visibility = Visibility.Private;
	/// stores the actual enum
	private Library.Enum _enum;
	/// Returns: the name of this enum
	public @property string name() return{
		return _enum.name;
	}
	/// ditto
	public @property string name(string newName) return{
		return _enum.name = newName;
	}
	/// Returns: the members' names (index is the int value it gets replaced with)
	public @property ref string[] members() return{
		return _enum.members;
	}
	/// ditto
	public @property ref string[] members(string[] newMembers) return{
		return _enum.members = newMembers;
	}
	/// returns: misc.Enum representing this enum
	public Library.Enum toEnum(){
		return _enum;
	}
}

/// to store var declaration
package struct VarDeclareNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// Stores visibility for this node
	public Visibility visibility = Visibility.Private;
	/// the data typre of defined vars
	public DataType type;
	/// stores names of vars declared
	private string[] varNames;
	/// stores IDs of vars declared, only assigned after ASTCheck has checked it
	private uinteger[string] _varIDs;
	/// stores vars' assigned values, with key=varName
	private CodeNode[string] varValues;
	/// returns: array contataining names of declared vars. Modifying this array won't have any effect
	public @property string[] vars(){
		return varNames.dup;
	}
	/// returns: array containig ID's of variables in assoc_array
	public @property uinteger[string] varIDs(){
		return _varIDs.dup;
	}
	/// Returns: assigned value for a var
	/// 
	/// Throws: Exception if that variable was not assigned in this statement, or no value was assigned to it
	public ref CodeNode getValue(string varName){
		if (varName in varValues){
			return varValues[varName];
		}
		throw new Exception ("variable "~varName~" does not exist in array");
	}
	/// Returns: true if a variable has a value assigned to it
	public bool hasValue(string varName){
		if (varName in varValues)
			return true;
		return false;
	}
	/// adds a variable to the list
	public void addVar(string varName){
		varNames = varNames ~ varName;
	}
	/// adds a variable to the list, along with it's assigned value
	public void addVar(string varName, CodeNode value){
		varValues[varName] = value;
		varNames = varNames ~ varName;
	}
	/// sets a stored var's assigned value
	public void setVarValue(string varName, CodeNode value){
		varValues[varName] = value;
	}
	/// sets a stored var's ID
	public void setVarID(string varName, uinteger id){
		_varIDs[varName] = id;
	}
	/// constructor
	this (string[] vars){
		varNames = vars.dup;
	}
}

/// a node representing a "set-of-statements" AKA a "block"
package struct BlockNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// an array of statements that make this block
	public StatementNode[] statements;
	/// constructor
	this (StatementNode[] blockStatements){
		statements = blockStatements.dup;
	}
}

/// a node to represent code that evaluates to some data.
/// 
/// This node can contain:  
/// 1. Function call - to only those functions that return some data
/// 2. Literals
/// 3. Operators
/// 4. Variables
/// 5. Arrays (Literal, or with variable elements)
package struct CodeNode{
	/// Returns: the line number (starts from 1) from which this node begins, or ends
	@property uinteger lineno(){
		if (_type == Type.FunctionCall){
			return fCall.lineno;
		}else if (_type == Type.Literal){
			return literal.lineno;
		}else if (_type == Type.Operator){
			return operator.lineno;
		}else if (_type == Type.Variable){
			return var.lineno;
		}else if (_type == Type.ReadElement){
			return arrayRead.lineno;
		}else if (_type == Type.Array){
			return array.lineno;
		}else if (_type == Type.SOperator){
			return sOperator.lineno;
		}else if (_type == Type.MemberSelector){
			return memberSelector.lineno;
		}
		return 0;
	}
	/// ditto
	@property uinteger lineno(uinteger newLineno){
		if (_type == Type.FunctionCall){
			return fCall.lineno = newLineno;
		}else if (_type == Type.Literal){
			return literal.lineno = newLineno;
		}else if (_type == Type.Operator){
			return operator.lineno = newLineno;
		}else if (_type == Type.Variable){
			return var.lineno = newLineno;
		}else if (_type == Type.ReadElement){
			return arrayRead.lineno = newLineno;
		}else if (_type == Type.Array){
			return array.lineno = newLineno;
		}else if (_type == Type.SOperator){
			return sOperator.lineno = newLineno;
		}else if (_type == Type.MemberSelector){
			return memberSelector.lineno = newLineno;
		}
		return 0;
	}
	/// enum defining the possible types this node can store
	public enum Type{
		FunctionCall,
		Literal,
		Negative,
		Operator, // double operand operator
		SOperator, // single operand operator
		Variable,
		ReadElement,
		Array,
		MemberSelector
	}
	/// the stored type
	private Type _type;
	/// union storing all possible nodes
	private union{
		FunctionCallNode fCall;
		LiteralNode literal;
		NegativeValueNode negativeVal;
		OperatorNode operator;
		SOperatorNode sOperator;
		VariableNode var;
		ReadElement arrayRead;
		ArrayNode array;
		MemberSelectorNode memberSelector;
	}
	/// returns the type of the stored type
	@property CodeNode.Type type(){
		return _type;
	}
	/// sets the stored node
	@property auto ref node (T)(T newNode){
		static if (is (T == FunctionCallNode)){
			_type = CodeNode.Type.FunctionCall;
			return fCall = newNode;
		}else static if (is (T == LiteralNode)){
			_type = CodeNode.Type.Literal;
			return literal = newNode;
		}else static if (is (T == NegativeValueNode)){
			_type = CodeNode.Type.Negative;
			return negativeVal = newNode;
		}else static if (is (T == OperatorNode)){
			_type = CodeNode.Type.Operator;
			return operator = newNode;
		}else static if (is (T == VariableNode)){
			_type = CodeNode.Type.Variable;
			return var = newNode;
		}else static if (is (T == ReadElement)){
			_type = CodeNode.Type.ReadElement;
			return arrayRead = newNode;
		}else static if(is (T == ArrayNode)){
			_type = CodeNode.Type.Array;
			return array = newNode;
		}else static if (is (T == SOperatorNode)){
			_type = CodeNode.Type.SOperator;
			return sOperator = newNode;
		}else static if (is (T == MemberSelectorNode)){
			_type = CodeNode.Type.MemberSelector;
			return memberSelector = newNode;
		}
	}
	/// returns the stored type
	@property auto ref node(CodeNode.Type T)(){
		// make sure it's the correct type
		if (T != _type){
			throw new Exception("attempting to retrieve invalid type from CodeNode.node");
		}
		static if (T == CodeNode.Type.FunctionCall){
			return fCall;
		}else static if (T == CodeNode.Type.Literal){
			return literal;
		}else static if (T == CodeNode.Type.Negative){
			return negativeVal;
		}else static if (T == CodeNode.Type.Operator){
			return operator;
		}else static if (T == CodeNode.Type.Variable){
			return var;
		}else static if (T == CodeNode.Type.ReadElement){
			return arrayRead;
		}else static if (T == CodeNode.Type.Array){
			return array;
		}else static if (T == CodeNode.Type.SOperator){
			return sOperator;
		}else static if (T == CodeNode.Type.MemberSelector){
			return memberSelector;
		}else{
			throw new Exception("attempting to retrieve invalid type from CodeNode.node");
		}
	}
	/// Returns: true if the stored data is literal
	public @property bool isLiteral (){
		if (_type == CodeNode.Type.Literal)
			return true;
		if (_type == CodeNode.Type.Negative)
			return negativeVal.isLiteral;
		if (_type == CodeNode.Type.Array)
			return array.isLiteral;
		if (_type == CodeNode.Type.Operator)
			return operator.isLiteral;
		if (_type == CodeNode.Type.ReadElement)
			return arrayRead.isLiteral;
		if (_type == CodeNode.Type.SOperator)
			return sOperator.isLiteral;
		if (_type == CodeNode.Type.Variable)
			return var.isLiteral;
		if (_type == CodeNode.Type.MemberSelector)
			return memberSelector.isLiteral;
		return false;
	}
	/// the return type, only available after ASTCheck has checked it
	@property DataType returnType (){
		if (_type == CodeNode.Type.Array){
			return array.returnType;
		}else if (_type == CodeNode.Type.FunctionCall){
			return fCall.returnType;
		}else if (_type == CodeNode.Type.Literal){
			return literal.returnType;
		}else if (_type == CodeNode.Type.Negative){
			return negativeVal.returnType;
		}else if (_type == CodeNode.Type.Operator){
			return operator.returnType;
		}else if (_type == CodeNode.Type.ReadElement){
			return arrayRead.returnType;
		}else if (_type == CodeNode.Type.SOperator){
			return sOperator.returnType;
		}else if (_type == CodeNode.Type.Variable){
			return var.returnType;
		}else if (_type == CodeNode.Type.MemberSelector){
			return memberSelector.returnType;
		}
		return DataType();
	}
	/// ditto
	@property DataType returnType (DataType newType){
		if (_type == CodeNode.Type.Array){
			return array.returnType = newType;
		}else if (_type == CodeNode.Type.FunctionCall){
			return fCall.returnType = newType;
		}else if (_type == CodeNode.Type.Literal){
			return literal.returnType = newType;
		}else if (_type == CodeNode.Type.Negative){
			return negativeVal.returnType = newType;
		}else if (_type == CodeNode.Type.Operator){
			return operator.returnType = newType;
		}else if (_type == CodeNode.Type.ReadElement){
			return arrayRead.returnType = newType;
		}else if (_type == CodeNode.Type.SOperator){
			return sOperator.returnType = newType;
		}else if (_type == CodeNode.Type.Variable){
			return var.returnType = newType;
		}else if (_type == CodeNode.Type.MemberSelector){
			return memberSelector.returnType = newType;
		}
		return DataType();
	}
	/// constructor
	this (T)(T newNode){
		node = newNode;
	}
}

/// to store a member selection (someStructOrEnum.memberName)
package struct MemberSelectorNode{
	/// Types
	public enum Type{
		EnumMemberRead, /// reading a member from an enum
		StructMemberRead, /// reading a member from a struct
	}
	/// stores the type this MemberSelector is of. Only valid after ASTCheck has been called on this
	public Type type;
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the parent node (to select member from)
	private CodeNode* _parentPtr;
	/// name of member, this is valid for Type.EnumMemberRead & Type.StructMemberRead
	public string memberName;
	/// Return type. Only valid after ASTCheck
	public DataType returnType;
	/// index of memberName in struct definition or enum definition. Only valid after ASTCheck
	public integer memberNameIndex = -1;
	/// stores if value is static
	public bool isLiteral = false;
	/// Returns: the parent node
	@property ref CodeNode parent(){
		return *_parentPtr;
	}
	/// ditto
	@property CodeNode parent(CodeNode newParent){
		if (!_parentPtr)
			_parentPtr = new CodeNode;
		return *_parentPtr = newParent;
	}
	/// Constructor
	this(CodeNode parent, string member, uinteger lineno){
		this.parent = parent;
		this.memberName = member;
		this.lineno = lineno;
	}
}

/// stores a variable
package struct VariableNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the name of this var
	public string varName;
	/// the ID of the variable. This is assigned in the ASTCheck stage, not in ASTGen
	public integer id;
	/// the library ID where this is defined
	public integer libraryId = -1;
	/// stores if this is a global variable. Only valid valid after ASTCheck has been called on this.
	public bool isGlobal = false;
	/// if the variable is script defined (global or not), assigned after checkAST has been called on this
	public deprecated @property bool isScriptDefined(){
		return libraryId == -1;
	}
	/// stores the return type. Only stored after ASTCheck has checked it
	public DataType returnType = DataType(DataType.Type.Void);
	/// true if its return value is static, i.e, will always return same value when evaluated
	/// 
	/// determined by ASTCheck
	/// 
	/// TODO yet to be implemented, probably won't be done till 0.7.1
	public bool isLiteral = false;
	/// constructor
	this (string name){
		varName = name;
		isLiteral = false;
		returnType = DataType(DataType.Type.Void);
		libraryId = -1;
		isGlobal = false;
	}
}

/// stores array, for example, `[0, 1, x, y]` will be stored using this
package struct ArrayNode{
	/// the line number (starts from 1) from which this node begins, or ends
	uinteger lineno;
	/// stores the elements
	public CodeNode[] elements;
	/// Returns: true if its return value is static, i.e, will always return same value when executed
	public @property bool isLiteral (){
		foreach (element; elements)
			if (!element.isLiteral)
				return false;
		return true;
	}
	/// the return type
	@property DataType returnType (){
		if (elements.length == 0)
			return DataType(DataType.Type.Void,1);
		DataType r = elements[0].returnType;
		if (r.type == DataType.Type.Void)
			return r;
		r.arrayDimensionCount++;
		return r;
	}
	/// does nothing (besides existing)
	@property DataType returnType(DataType newType){
		return this.returnType;
	}
	/// constructor
	this (CodeNode[] elements){
		this.elements = elements;
	}
}

/// stores literal data, i.e data that was availabe at runtime. Can store strings, double, integer,  
/// but arrays (even ones without variables, only literals) are stored in ArrayNode
package struct LiteralNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// stores the data type for the literal
	public DataType returnType = DataType(DataType.Type.Void);
	/// stores the literal in a QData
	public string literal;
	/// constructor
	this (string data, DataType dataType){
		literal = data;
		returnType = dataType;
	}
	/// constructor using `fromTokens`
	this (Token tokenLiteral){
		fromToken(tokenLiteral);
	}
	/// reads the literal from a string
	/// 
	/// throws Exception on error
	void fromToken(Token token){
		returnType.fromData(token);
	}
}

/// stores `-x`
package struct NegativeValueNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// stores the value to make negative
	private CodeNode* _valuePtr;
	/// value to make negative
	@property ref CodeNode value(){
		return *_valuePtr;
	}
	/// ditto
	@property ref CodeNode value(CodeNode newVal){
		if (_valuePtr is null)
			_valuePtr = new CodeNode();
		return *_valuePtr = newVal;
	}
	/// return data type
	public @property DataType returnType(){
		return (*_valuePtr).returnType;
	}
	/// ditto
	public @property DataType returnType(DataType newType){
		return this.returnType;
	}
	/// Returns: true if it's value is literal, i.e fixed/constant
	@property bool isLiteral(){
		return (*_valuePtr).isLiteral;
	}
	/// constructor
	this(CodeNode val){
		value = val;
	}
}

/// stores an operator with two operands
package struct OperatorNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// stores the operator (like '+' ...)
	public string operator;
	/// operands. [0] = left, [1] = right
	public CodeNode[] operands;
	/// Returns: true if its return value is static, i.e, will always return same value when executed
	public @property bool isLiteral (){
		foreach (operand; operands){
			if (!operand.isLiteral)
				return false;
		}
		return true;
	}
	/// stores the return type. Only stored after ASTCheck has checked it
	public DataType returnType = DataType(DataType.Type.Void);
	/// constructor
	this (string operatorString, CodeNode a, CodeNode b){
		operator = operatorString;
		operands.length = 2;
		operands[0] = a;
		operands[1] = b;
		returnType = DataType(DataType.Type.Void);
	}
}

/// stores an operator with single operand (like ! and @)
package struct SOperatorNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the operator string
	public string operator;
	/// the stored operand
	private CodeNode* operandPtr;
	/// the operand
	public @property ref CodeNode operand(CodeNode newOperand){
		if (operandPtr is null){
			operandPtr = new CodeNode;
		}
		return *operandPtr = newOperand;
	}
	/// the operand
	public @property ref CodeNode operand(){
		return *operandPtr;
	}
	/// stores the return type. Only stored after ASTCheck has checked it
	public DataType returnType = DataType(DataType.Type.Void);
	/// Returns: true if its return value is static, i.e will always be same when executed
	@property bool isLiteral(){
		return (operandPtr !is null && operand.isLiteral);
	}
}

/// stores an "array-read" (instruction `readElement` or for string, `readChar`)
package struct ReadElement{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the node to read from
	private CodeNode* readFromPtr = null;
	/// the index to read at
	private CodeNode* readIndexPtr = null;
	/// the node to read from
	public @property ref CodeNode readFromNode(){
		if (readFromPtr is null)
			readFromPtr = new CodeNode;
		return *readFromPtr;
	}
	/// the node to read from
	public @property ref CodeNode readFromNode(CodeNode newNode){
		if (readFromPtr is null)
			readFromPtr = new CodeNode;
		return *readFromPtr = newNode;
	}
	/// the index to read at
	public @property ref CodeNode index(){
		if (readIndexPtr is null)
			readIndexPtr = new CodeNode;
		return *readIndexPtr;
	}
	/// the index to read at
	public @property ref CodeNode index(CodeNode newNode){
		if (readIndexPtr is null)
			readIndexPtr = new CodeNode;
		return *readIndexPtr = newNode;
	}
	/// returns the data type this node will return
	public @property DataType returnType(){
		DataType r = (*readFromPtr).returnType;
		r.arrayDimensionCount --;
		return r;
	}
	/// does nothing, besides existing but needed for compiling
	public @property DataType returnType(DataType newType){
		return this.returnType;
	}
	/// Returns: true if its return value is static, i.e, will always return same value when executed
	@property bool isLiteral(){
		return (readFromPtr !is null && readIndexPtr !is null && readFromNode.isLiteral && index.isLiteral);
	}
	/// constructor
	this (CodeNode toReadNode, CodeNode index){
		this.readFromNode = toReadNode;
		this.index = index;
	}
}

/// a node representing statements, including: if, while, function-call..
package struct StatementNode{
	/// types of a statement
	public enum Type{
		If,
		While,
		For,
		DoWhile,
		Block,
		Assignment,
		FunctionCall,
		VarDeclare,
		Return
	}
	/// Returns: the line number (starts from 1) from which this node begins, or ends
	public @property uinteger lineno(){
		if (_type == Type.If){
			return ifNode.lineno;
		}else if (_type == Type.While){
			return whileNode.lineno;
		}else if (_type == Type.For){
			return forNode.lineno;
		}else if (_type == Type.DoWhile){
			return doWhile.lineno;
		}else if (_type == Type.Block){
			return blockNode.lineno;
		}else if (_type == Type.Assignment){
			return assignNode.lineno;
		}else if (_type == Type.FunctionCall){
			return functionCallNode.lineno;
		}else if (_type == Type.VarDeclare){
			return varDeclareNode.lineno;
		}else if (_type == Type.Return){
			return returnNode.lineno;
		}
		return 0;
	}
	/// ditto
	public @property uinteger lineno(uinteger newLineno){
		if (_type == Type.If){
			return ifNode.lineno = newLineno;
		}else if (_type == Type.While){
			return whileNode.lineno = newLineno;
		}else if (_type == Type.For){
			return forNode.lineno = newLineno;
		}else if (_type == Type.DoWhile){
			return doWhile.lineno = newLineno;
		}else if (_type == Type.Block){
			return blockNode.lineno = newLineno;
		}else if (_type == Type.Assignment){
			return assignNode.lineno = newLineno;
		}else if (_type == Type.FunctionCall){
			return functionCallNode.lineno = newLineno;
		}else if (_type == Type.VarDeclare){
			return varDeclareNode.lineno = newLineno;
		}else if (_type == Type.Return){
			return returnNode.lineno = newLineno;
		}
		return 0;
	}
	/// type of this statement
	private Type _type;
	/// the stored node, is in this union
	private union{
		IfNode ifNode;
		WhileNode whileNode;
		ForNode forNode;
		DoWhileNode doWhile;
		BlockNode blockNode;
		FunctionCallNode functionCallNode;
		VarDeclareNode varDeclareNode;
		AssignmentNode assignNode;
		ReturnNode returnNode;
	}
	/// modifies the stored node
	@property void node(T)(T newNode){
		static if (is (T == IfNode)){
			_type = StatementNode.Type.If;
			ifNode = newNode;
		}else static if (is (T == WhileNode)){
			_type = StatementNode.Type.While;
			whileNode = newNode;
		}else static if (is (T == ForNode)){
			_type = StatementNode.Type.For;
			forNode = newNode;
		}else static if (is (T == DoWhileNode)){
			_type = StatementNode.Type.DoWhile;
			doWhile = newNode;
		}else static if (is (T == BlockNode)){
			_type = StatementNode.Type.Block;
			blockNode = newNode;
		}else static if (is (T == FunctionCallNode)){
			_type = StatementNode.Type.FunctionCall;
			functionCallNode = newNode;
		}else static if (is (T == VarDeclareNode)){
			_type = StatementNode.Type.VarDeclare;
			varDeclareNode = newNode;
		}else static if (is (T == AssignmentNode)){
			_type = StatementNode.Type.Assignment;
			assignNode = newNode;
		}else static if (is (T == ReturnNode)){
			_type = Type.Return;
			returnNode = newNode;
		}else{
			throw new Exception("attempting to assign invalid node type to StatementNode.node");
		}
	}
	/// returns the stored type
	@property auto ref node(StatementNode.Type T)(){
		// make sure type is correct
		if (T != _type){
			throw new Exception("stored type does not match with type being retrieved");
		}
		static if (T == StatementNode.Type.If){
			return ifNode;
		}else static if (T == StatementNode.Type.While){
			return whileNode;
		}else static if (T == StatementNode.Type.For){
			return forNode;
		}else static if (T == StatementNode.Type.DoWhile){
			return doWhile;
		}else static if (T == StatementNode.Type.Block){
			return blockNode;
		}else static  if (T == StatementNode.Type.FunctionCall){
			return functionCallNode;
		}else static if (T == StatementNode.Type.VarDeclare){
			return varDeclareNode;
		}else static if (T == StatementNode.Type.Assignment){
			return assignNode;
		}else static if (T == StatementNode.Type.Return){
			return returnNode;
		}else{
			throw new Exception("attempting to retrieve invalid type from StatementNode.node");
		}
	}
	/// returns the type of the stored node
	@property StatementNode.Type type(){
		return _type;
	}
	/// constructor
	this (T)(T newNode){
		node = newNode;
	}
}

/// to store assignment statements
package struct AssignmentNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// stores whether the assignment is to a variable (false) or if it has to dereference first (true)
	public bool deref = false;
	/// the variable to assign to
	public CodeNode lvalue;
	/// the value to assign
	public CodeNode rvalue;
	/// constructor
	this (CodeNode lv, CodeNode rv, bool deref = false){
		lvalue = lv;
		rvalue = rv;
		this.deref = deref;
	}
}

/// to store if statements
package struct IfNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the condition for this if statement
	public CodeNode condition;
	/// stores the pointer to the statement to execute
	private StatementNode* statementPtr;
	/// returns the statement to execute, if true
	public @property ref StatementNode statement(){
		if (statementPtr is null)
			statementPtr = new StatementNode;
		return *statementPtr;
	}
	/// sets the statement to execute, if true
	public @property ref StatementNode statement(StatementNode newStatement){
		if (statementPtr is null){
			statementPtr = new StatementNode;
		}
		return *statementPtr = newStatement;
	}
	/// stores the pointer to the statement to execute if the condition is false.
	private StatementNode* elseStatementPtr;
	/// returns the statement to execute, if false
	public @property ref StatementNode elseStatement(){
		if (elseStatementPtr is null)
			elseStatementPtr = new StatementNode;
		return *elseStatementPtr;
	}
	/// sets the statement to execute, if true
	public @property ref StatementNode elseStatement(StatementNode newElseStatement){
		if (elseStatementPtr is null){
			elseStatementPtr = new StatementNode;
		}
		return *elseStatementPtr = newElseStatement;
	}

	/// stores whether this if has an else statement too
	public bool hasElse = false;
	/// constructor
	this (CodeNode conditionNode, StatementNode statementToExecute, StatementNode elseStatementToExec){
		condition = conditionNode;
		statement = statementToExecute;
		elseStatement = elseStatementToExec;
		hasElse = true;
	}
	/// constructor
	this (CodeNode conditionNode,  StatementNode statementsToExecute){
		condition = conditionNode;
		statement = statementsToExecute;
		hasElse = false;
	}
}

/// to store while statements
package struct WhileNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the condition for this while statement
	public CodeNode condition;
	/// stores the pointer to the statement to execute in loop while the condition is true
	private StatementNode* statementPtr;
	/// returns the statement to execute, while true
	public @property ref StatementNode statement(){
		if (statementPtr is null)
			statementPtr = new StatementNode;
		return *statementPtr;
	}
	/// sets the statement to execute, while true
	public @property ref StatementNode statement(StatementNode newStatement){
		if (statementPtr is null){
			statementPtr = new StatementNode;
		}
		return *statementPtr = newStatement;
	}
	/// constructor
	this (CodeNode conditionNode, StatementNode statementToExec){
		condition = conditionNode;
		statement = statementToExec;
	}
}

/// to store do-while statements
package struct DoWhileNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the condition for this do-while statement
	public CodeNode condition;
	/// stores pointer to the statement to execute in this loop
	private StatementNode* statementPtr;
	/// the statement to execute in this loop
	public @property ref StatementNode statement(){
		if (statementPtr is null)
			statementPtr = new StatementNode;
		return *statementPtr;
	}
	/// ditto
	public @property ref StatementNode statement(StatementNode newStatement){
		if (statementPtr is null){
			statementPtr = new StatementNode;
		}
		return *statementPtr = newStatement;
	}
	/// constructor
	this (CodeNode conditionNode, StatementNode statementToExec){
		condition = conditionNode;
		statement = statementToExec;
	}
}

/// to store for loop statements
package struct ForNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// stores the pointer to initialization statement, i.e: `for (<this one>; bla; bla)...`
	private StatementNode* initStatementPtr;
	/// stores the pointer to the increment statement, i.e: `for (bla; bla; <this one>)...`
	private StatementNode* incStatementPtr;
	/// stores the condition CodeNode
	public CodeNode condition;
	/// stores the pointer to the statement to execute in loop
	private StatementNode* statementPtr;
	/// the init statement for this for loop
	public @property ref StatementNode initStatement(){
		if (initStatementPtr is null)
			initStatementPtr = new StatementNode;
		return *initStatementPtr;
	}
	/// ditto
	public @property ref StatementNode initStatement(StatementNode newStatement){
		if (initStatementPtr is null){
			initStatementPtr = new StatementNode;
		}
		return *initStatementPtr = newStatement;
	}
	/// the increment statement for this for loop
	public @property ref StatementNode incStatement(){
		if (incStatementPtr is null)
			incStatementPtr = new StatementNode;
		return *incStatementPtr;
	}
	/// ditto
	public @property ref StatementNode incStatement(StatementNode newStatement){
		if (incStatementPtr is null){
			incStatementPtr = new StatementNode;
		}
		return *incStatementPtr = newStatement;
	}
	/// the statement to execute in loop
	public @property ref StatementNode statement(){
		if (statementPtr is null)
			statementPtr = new StatementNode;
		return *statementPtr;
	}
	/// ditto
	public @property ref StatementNode statement(StatementNode newStatement){
		if (statementPtr is null){
			statementPtr = new StatementNode;
		}
		return *statementPtr = newStatement;
	}
	/// constructor
	this (StatementNode initNode, CodeNode conditionNode, StatementNode incNode, StatementNode statementToExec){
		initStatement = initNode;
		condition = conditionNode;
		incStatement = incNode;
		statement = statementToExec;
	}
}

/// to store functionCall nodes
package struct FunctionCallNode{
	/// the line number (starts from 1) from which this node begins, or ends
	public uinteger lineno;
	/// the id of the library this function is from.
	public integer libraryId = -1;
	/// the name of the function
	public string fName;
	/// the id of the function, assigned after checkAST has been called on this
	public integer id;
	/// if the function being called is script defined or not, assigned after checkAST has been called on this
	public deprecated @property bool isScriptDefined(){
		return libraryId == -1;
	}
	/// the arguments for this function.
	private CodeNode[] _arguments;
	/// returns the values for arguments
	@property ref CodeNode[] arguments() return{
		return _arguments;
	}
	/// sets value for storedArguments
	@property ref CodeNode[] arguments(CodeNode[] newArgs) return{
		return _arguments = newArgs.dup;
	}
	/// stores the return type. Only stored after ASTCheck has checked it
	public DataType returnType = DataType(DataType.Type.Void);
	/// constructor
	this (string functionName, CodeNode[] functionArguments){
		fName = functionName;
		arguments = functionArguments;
		returnType = DataType(DataType.Type.Void);
		libraryId = -1;
	}
}

package struct ReturnNode{
	/// the line number on which this node was read from
	public uinteger lineno;
	/// the value to return from function
	public CodeNode value;
}