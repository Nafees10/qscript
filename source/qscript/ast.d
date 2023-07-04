module qscript.ast;

import std.json;

import qscript.compiler,
			 qscript.tokens;

import utils.ds;

/// Generic AST Node
public abstract class ASTNode{
public:
	/// location in source
	uint line, col;
	/// parent node
	ASTNode parent;

	/*abstract JSONValue toJSON() const;
	final override string toString() const {
		return toJSON.toString;
	}*/
}

public class ScriptNode : ASTNode{
public:
	/// declarations
	DeclNode[] decls;
}

public abstract class DeclNode : ASTNode{
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
	ParamNode[] params;
	/// body
	StatementNode statement;
}

public class EnumNode : DeclNode{
public:
	/// data type
	ExpressionNode type;
	/// members to values map (value can be null)
	StatementNode[string] members;
}

public class StructNode : DeclNode{
public:
	/// declarations
	DeclNode[] decls;
}

public class VarNode : DeclNode{
public:
	/// Data type
	ExpressionNode type;
	/// variable name to value map (value can be null)
	ExpressionNode[string] vars;
}

public class AliasNode : DeclNode{
public:
	/// Expression used to identify what is being aliased
	ExpressionNode expAliasTo;
}

public class TemplateParamNode : ASTNode{
public:
	/// Data Type (optional)
}

public class ParamNode : ASTNode{
public:
}

public abstract class StatementNode : ASTNode{}

public class IfNode : StatementNode{
public:
}

public class StaticIfNode : StatementNode{
public:
}

public class WhileNode : StatementNode{
public:
}

public class DoWhileNode : StatementNode{
public:
}

public class ForNode : StatementNode{
public:
}

public class StaticForNode : StatementNode{
public:
}

public class BreakNode : StatementNode{
public:
}

public class ContinueNode : StatementNode{
public:
}

public class BlockNode : StatementNode{
public:
}

public abstract class ExpressionNode : ASTNode{}

public class IdentifierNode : ExpressionNode{
public:
}

public class LiteralIntNode : ExpressionNode{
public:
}

public class LiteralFloatNode : ExpressionNode{
public:
}

public class LiteralStringNode : ExpressionNode{
public:
}

public class LiteralCharNode : ExpressionNode{
public:
}

public class LiteralNullNode : ExpressionNode{
public:
}

public class LiteralBoolNode : ExpressionNode{
public:
}

public class TraitNode : ExpressionNode{
public:
}

public class LoadNode : ExpressionNode{
public:
}

public class ArrowFuncNode : ExpressionNode{
public:
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
