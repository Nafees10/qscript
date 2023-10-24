module qscript.ast;

import std.json;

import qscript.compiler,
			 qscript.tokens;

import utils.ds;

/// Generic AST Node
public abstract class Node{
public:
	/// location in source
	uint line, col;
	/// parent node
	Node parent;

	/*abstract JSONValue toJSON() const;
	final override string toString() const {
		return toJSON.toString;
	}*/
}

public class ScriptNode : Node{
public:
	/// declarations
	DeclNode[] decls;
}

public abstract class DeclNode : Node{
public:
	/// name
	string name;
}

public class PubNode : DeclNode{
public:
	/// declaration
	DeclNode decl;
}

public class TemplateNode : DeclNode{
public:
	/// Template parameters
	TemplateParamNode[] params;
	/// declarations
	DeclNode[] decls;
}

public class FnNode : DeclNode{
public:
	/// Return type (can be null)
	ExpressionNode retType;
	/// Parameters
	ParamNode[] parameters;
	/// body
	StatementNode statement;
}

public class VarNode : DeclNode{
public:
	/// Data type
	ExpressionNode type;
	/// variable name to value map (value can be null)
	ExpressionNode[string] vars;
}

public class StructNode : DeclNode{
public:
	/// declarations
	DeclNode[] decls;
}

public class EnumNode : DeclNode{
public:
	/// data type
	ExpressionNode type;
	/// members to values map (value can be null)
	StatementNode[string] members;
}

public class AliasNode : DeclNode{
public:
	/// Expression used to identify what is being aliased
	ExpressionNode expAliasTo;
}

public class ParamNode : Node{
public:
	/// data type
	ExpressionNode dataType;
	/// name, can be null
	string name;
}

public class TemplateParamNode : Node{
public:
	/// Data Type (can be null)
	ExpressionNode dataType;
	/// name
	string name;
}

public abstract class StatementNode : Node{}

public class ReturnStatement : StatementNode{
public:
	/// return value
	ExpressionNode value;
}

public class IfNode : StatementNode{
public:
	/// condition
	ExpressionNode condition;
	/// statement
	StatementNode statement;
	/// else statement
	StatementNode elseStatement;
}

public class StaticIfNode : StatementNode{
public:
	/// condition
	ExpressionNode condition;
	/// statement
	StatementNode statement;
	/// else statement
	StatementNode elseStatement;
}

public class WhileNode : StatementNode{
public:
	/// condition
	ExpressionNode condition;
	/// statement
	StatementNode statement;
}

public class DoWhileNode : StatementNode{
public:
	/// condition
	ExpressionNode condition;
	/// statement
	StatementNode statement;
}

public class ForNode : StatementNode{
public:
	/// iteration counter name, can be null
	string counter;
	/// iterator name
	string iterator;
	/// range
	ExpressionNode range;
}

public class StaticForNode : StatementNode{
public:
	/// iteration counter name, can be null
	string counter;
	/// iterator name
	string iterator;
	/// range
	ExpressionNode range;
}

public class BreakNode : StatementNode{
public:
}

public class ContinueNode : StatementNode{
public:
}

public class BlockNode : StatementNode{
public:
	/// statements
	StatementNode[] statements;
}

public abstract class ExpressionNode : Node{}

public class LiteralIntNode : ExpressionNode{
public:
	/// integer value
	ptrdiff_t value;
}

public class LiteralFloatNode : ExpressionNode{
public:
	/// floating point value
	double value;
}

public class LiteralStringNode : ExpressionNode{
public:
	/// string value
	string value;
}

public class LiteralCharNode : ExpressionNode{
public:
	/// character value
	char value;
}

public class LiteralNullNode : ExpressionNode{
public:
	// no members
}

public class LiteralBoolNode : ExpressionNode{
public:
	/// boolean value
	bool value;
}

public class TraitNode : ExpressionNode{
public:
	/// trait name
	string name;
	/// trait parameters
	ExpressionNode params;
}

public class LoadNode : ExpressionNode{
public:
	/// module path (a.b.c will be [a,b,c])
	string[] modulePath;
}

public class ArrowParamNode : Node{
public:
	/// Data type (can be null)
	ExpressionNode dataType;
	/// name
	string name;
}

public class ArrowFuncNode : ExpressionNode{
public:
	/// parameters
	ArrowParamNode[] params;
}

public class BinOp : ExpressionNode{
public:
}

public class UnaryOp : ExpressionNode{
public:
}

public class OpDot : BinOp{
public:
}

public class OpIndex : BinOp{
public:
}

public class OpCall : BinOp{
public:
}

public class OpPostInc : UnaryOp{
public:
}

public class OpPostDec : UnaryOp{
public:
}

public class OpPreInc : UnaryOp{
public:
}

public class OpPreDec : UnaryOp{
public:
}

public class OpNot : UnaryOp{
public:
}

public class OpMul : BinOp{
public:
}

public class OpDiv : BinOp{
public:
}

public class OpMod : BinOp{
public:
}

public class OpAdd : BinOp{
public:
}

public class OpSub : BinOp{
public:
}

public class OpLShift : BinOp{
public:
}

public class OpRShift : BinOp{
public:
}

public class OpEquals : BinOp{
public:
}

public class OpNotEquals : BinOp{
public:
}

public class OpGreaterEquals : BinOp{
public:
}

public class OpLesserEquals : BinOp{
public:
}

public class OpGreater : BinOp{
public:
}

public class OpLesser : BinOp{
public:
}

public class OpIs : BinOp{
public:
}

public class OpNotIs : BinOp{
public:
}

public class OpBinAnd : BinOp{
public:
}

public class OpBinOr : BinOp{
public:
}

public class OpBinXor : BinOp{
public:
}

public class OpBoolAnd : BinOp{
public:
}

public class OpBoolOr : BinOp{
public:
}

public class OpAssign : BinOp{
public:
}

public class OpAddAssign : BinOp{
public:
}

public class OpSubAssign : BinOp{
public:
}

public class ObMulAssign : BinOp{
public:
}

public class OpDivAssign : BinOp{
public:
}

public class OpModAssign : BinOp{
public:
}

public class OpBinAndAssign : BinOp{
public:
}

public class OpBinOrAssign : BinOp{
public:
}

public class OpBinXorAssign : BinOp{
public:
}
