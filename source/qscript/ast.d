module qscript.ast;

import std.json,
			 std.traits,
			 std.conv,
			 std.string,
			 std.stdio;

import qscript.compiler,
			 qscript.tokens;

import utils.ds;

/// A simple AST Node
public class Node{
public:
	Token token;
	Node[] children;
	NodeType type;

	JSONValue toJSON(){
		JSONValue ret;
		ret["token"] = token.token;
		ret["type"] = type.to!string;
		string typeStr;
		foreach (member; EnumMembers!TokenType){
			if (!token.type[member])
				continue;
			typeStr ~= member.to!string ~ ", ";
		}
		if (typeStr.length)
			ret["tokentype"] = typeStr.chomp(", ");
		JSONValue[] sub;
		foreach (child; children)
			sub ~= child.toJSON;
		if (sub.length)
			ret["children"] = sub;
		return ret;
	}
}

/// ASTNode builder function type
private alias BuilderFunc = Node function(Token[], ref uint, NodeType);

/// read function for a NodeType
private template ReadFunction(NodeType type){
	enum ReadFunction = getReadFunction();
	BuilderFunc getReadFunction(){
		static if (__traits(hasMember, qscript.ast, "read" ~ type.to!string)){
			auto fn = &__traits(getMember, qscript.ast, "read" ~ type.to!string);
			static if (is(typeof(fn) == BuilderFunc))
				return fn;
			else
				return null;
		}else{
			return null;
		}
	}
}

/// Tries to read a specific type of node from tokens
/// Will increment index to skip tokens consumed
///
/// Returns: Node, or null
Node read(NodeType type)(Token[] toks, ref uint index){
	static NodeType context = NodeType.Script;
	auto func = ReadFunction!type;
	if (!func)
		return null;
	NodeType prevContext = context;
	context = type;
	auto ret = func(toks, index, context);
	context = prevContext;
	return ret;
}

/// Tries to read token into node based off of token type hook
/// Will increment index to skip tokens consumed
///
/// Returns: Node or null
Node read(Token[] toks, ref uint index){
	if (index >= toks.length)
		return null;
	auto type = toks[index].type;
	static foreach (member; EnumMembers!NodeType){
		static foreach (Hook hook; getUDAs!(member, Hook)){
			if (type.get(hook.hook)){
				auto ret = read!member(toks, index);
				if (ret !is null){
					ret.type = member;
					return ret;
				}
			}
		}
	}
	return null;
}

/// UDA for hook in token type
private struct Hook{
	TokenType hook;
	this(TokenType hook){
		this.hook = hook;
	}
}

/// Node types
public enum NodeType{
																		Script,
	@Hook(TokenType.Pub)							Pub,

	@Hook(TokenType.Template)					Template,
	@Hook(TokenType.TemplateFn)				TemplateFn,
	@Hook(TokenType.TemplateEnum)			TemplateEnum,
	@Hook(TokenType.TemplateStruct)		TemplateStruct,
	@Hook(TokenType.TemplateVar)			TemplateVar,
	@Hook(TokenType.TemplateAlias)		TemplateAlias,
	@Hook(TokenType.Fn)								Fn,
	@Hook(TokenType.Var)							Var,
	@Hook(TokenType.Struct)						Struct,
	@Hook(TokenType.Enum)							Enum,
	@Hook(TokenType.Alias)						Alias,
																		DataType,
																		ParamList,

	@Hook(TokenType.If)								IfStatement,
	@Hook(TokenType.StaticIf)					StaticIfStatement,
	@Hook(TokenType.While)						WhileStatement,
	@Hook(TokenType.Do)								DoWhileStatement,
	@Hook(TokenType.For)							ForStatement,
	@Hook(TokenType.StaticFor)				StaticForStatement,
	@Hook(TokenType.Break)						BreakStatement,
	@Hook(TokenType.Continue)					ContinueStatement,
	@Hook(TokenType.CurlyOpen)				Block,
	@Hook(TokenType.Identifier)				Identifier,

	@Hook(TokenType.LiteralInt)
		@Hook(TokenType.LiteralHexadecimal)
		@Hook(TokenType.LiteralBinary)	IntLiteral,
	@Hook(TokenType.LiteralFloat)			FloatLiteral,
	@Hook(TokenType.LiteralString)		StringLiteral,
	@Hook(TokenType.LiteralChar)			CharLiteral,
	@Hook(TokenType.Null)							NullLiteral,
	@Hook(TokenType.True)							TrueLiteral,
	@Hook(TokenType.False)						FalseLiteral,
																		Expr,

	@Hook(TokenType.Load)							LoadExpr,
	@Hook(TokenType.Arrow)						ArrowExpr,
	@Hook(TokenType.OpDot)						DotOp,
	@Hook(TokenType.OpIndex)					OpIndex,
	@Hook(TokenType.OpFnCall)					OpCall,
	@Hook(TokenType.OpInc)						OpPreInc,
	@Hook(TokenType.OpInc)						OpPostInc,
	@Hook(TokenType.OpDec)						OpPreDec,
	@Hook(TokenType.OpDec)						OpPostDec,
	@Hook(TokenType.OpNot)						OpNot,
	@Hook(TokenType.OpMul)						OpMul,
	@Hook(TokenType.OpDiv)						OpDiv,
	@Hook(TokenType.OpMod)						OpMod,
	@Hook(TokenType.OpAdd)						OpAdd,
	@Hook(TokenType.OpSub)						OpSub,
	@Hook(TokenType.OpLShift)					OpLShift,
	@Hook(TokenType.OpRShift)					OpRShift,
	@Hook(TokenType.OpEquals)					OpEquals,
	@Hook(TokenType.OpNotEquals)			OpNotEquals,
	@Hook(TokenType.OpGreaterEquals)	OpGreaterEquals,
	@Hook(TokenType.OpLesserEquals)		OpLesserEquals,
	@Hook(TokenType.OpGreater)				OpGreater,
	@Hook(TokenType.OpLesser)					OpLesser,
	@Hook(TokenType.OpIs)							OpIs,
	@Hook(TokenType.OpNotIs)					OpNotIs,
	@Hook(TokenType.OpBinAnd)					OpBinAnd,
	@Hook(TokenType.OpBinOr)					OpBinOr,
	@Hook(TokenType.OpBinXor)					OpBinXor,
	@Hook(TokenType.OpBoolAnd)				OpBoolAnd,
	@Hook(TokenType.OpBoolOr)					OpBoolOr,
	@Hook(TokenType.OpAssign)					OpAssign,
	@Hook(TokenType.OpAddAssign)			OpAddAssign,
	@Hook(TokenType.OpSubAssign)			OpSubAssign,
	@Hook(TokenType.OpMulAssign)			OpMulAssign,
	@Hook(TokenType.OpDivAssign)			OpDivAssign,
	@Hook(TokenType.OpModAssign)			OpModAssign,
	@Hook(TokenType.OpSubAssign)			OpBinAndAssign,
	@Hook(TokenType.OpBinOrAssign)		OpBinOrAssign,
	@Hook(TokenType.OpBinXorAssign)		OpBinXorAssign,
	@Hook(TokenType.Trait)						Trait
}

private Node readScript(Token[] toks, ref uint index, NodeType context){
	Node ret = new Node;
	while (index < toks.length){
		uint prevIndex = index;
		Node node = read(toks, index);
		if (prevIndex == index || node is null)
			throw new CompileError(ErrorType.Expected, toks[index], ["declaration"]);
		ret.children ~= node;
	}
	return ret;
}

private Node readPub(Token[] toks, ref uint index, NodeType context){
	if (!toks[index].type.get!(TokenType.Pub))
		return null;
	if (index + 1 >= toks.length)
		throw new CompileError(ErrorType.UnexpectedEOF, toks[$ - 1]);
	Node node = new Node;
	node.token = toks[index];
	index ++;
	node.children = [read(toks, index)];
	return node;
}

private Node readTemplate(Token[] toks, ref uint index, NodeType context){
	if (!toks[index].type.get!(TokenType.Template))
		return null;
	// TODO continue from here
	return null;
}

private Node readIntLiteral(Token[] toks, ref uint index, NodeType context){
	Node ret = new Node;
	ret.token = toks[index];
	index ++;
	return ret;
}
