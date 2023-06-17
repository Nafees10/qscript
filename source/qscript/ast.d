module qscript.ast;

import std.json,
			 std.traits,
			 std.conv,
			 std.string,
			 std.stdio;

import qscript.compiler,
			 qscript.tokens;

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
alias BuilderFunc = Node function(Token[] toks, ref uint index);

/// Tries to read a specific type of node from tokens
/// Will increment index to skip tokens consumed
///
/// Returns: Node, or null
Node read(NodeType type)(Token[] toks, ref uint index){
	static foreach (sym; EnumMembers!NodeType){
		static if (sym == type){
			static foreach (builder; getUDAs!(sym, Builder)){
				Node ret = builder.func(toks, index);
				if (ret)
					return ret;
			}
		}
	}
	return null;
}

/// Tries to read a specific type of node from tokens
///
/// Returns: Node, or null
Node read(NodeType type)(Token[] toks){
	uint i;
	return read!type(toks, i);
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

/// Tries to read token into node based off of token type hook
///
/// Returns: Node or null
Node read(Token[] toks){
	uint i;
	return read(toks, i);
}


/// UDA for builder function
private struct Builder{
	BuilderFunc func;
	this(BuilderFunc func){
		this.func = func;
	}
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
	@Builder(&readScript)													Script,
	@Builder(&readPubDecl) @Hook(TokenType.Pub)		Pub,
	@Builder(&readTemplateDecl)
						 @Hook(TokenType.Template)					TemplateDecl,
	@Builder() @Hook(TokenType.TemplateFn)				TemplateFnDecl,
	@Builder() @Hook(TokenType.TemplateEnum)			TemplateEnumDecl,
	@Builder() @Hook(TokenType.TemplateStruct)		TemplateStructDecl,
	@Builder() @Hook(TokenType.TemplateVar)				TemplateVarDecl,
	@Builder() @Hook(TokenType.TemplateAlias)			TemplateAliasDecl,
	@Builder() @Hook(TokenType.Fn)								FnDecl,
	@Builder() @Hook(TokenType.Var)								VarDecl,
	@Builder() @Hook(TokenType.Struct)						StructDecl,
	@Builder() @Hook(TokenType.Enum)							EnumDecl,
	@Builder() @Hook(TokenType.Alias)							AliasDecl,
	@Builder()																		DataType,
	@Builder()																		ParamList,

	@Builder() @Hook(TokenType.If)								IfStatement,
	@Builder() @Hook(TokenType.StaticIf)					StaticIfStatement,
	@Builder() @Hook(TokenType.While)							WhileStatement,
	@Builder() @Hook(TokenType.Do)								DoWhileStatement,
	@Builder() @Hook(TokenType.For)								ForStatement,
	@Builder() @Hook(TokenType.StaticFor)					StaticForStatement,
	@Builder() @Hook(TokenType.Break)							BreakStatement,
	@Builder() @Hook(TokenType.Continue)					ContinueStatement,
	@Builder() @Hook(TokenType.CurlyOpen)					Block,
	@Builder() @Hook(TokenType.Identifier)				Identifier,

	@Builder(&readIntLiteral)
						 @Hook(TokenType.LiteralInt)
						 @Hook(TokenType.LiteralHexadecimal)
						 @Hook(TokenType.LiteralBinary)			IntLiteral,
	@Builder() @Hook(TokenType.LiteralFloat)			FloatLiteral,
	@Builder() @Hook(TokenType.LiteralString)			StringLiteral,
	@Builder() @Hook(TokenType.LiteralChar)				CharLiteral,
	@Builder() @Hook(TokenType.Null)							NullLiteral,
	@Builder() @Hook(TokenType.True)							TrueLiteral,
	@Builder() @Hook(TokenType.False)							FalseLiteral,
	@Builder()																		Expr,

	@Builder() @Hook(TokenType.Load)							LoadExpr,
	@Builder() @Hook(TokenType.Arrow)							ArrowExpr,
	@Builder() @Hook(TokenType.OpDot)							DotOp,
	@Builder() @Hook(TokenType.OpIndex)						OpIndex,
	@Builder() @Hook(TokenType.OpFnCall)					OpCall,
	@Builder() @Hook(TokenType.OpInc)							OpPreInc,
	@Builder() @Hook(TokenType.OpInc)							OpPostInc,
	@Builder() @Hook(TokenType.OpDec)							OpPreDec,
	@Builder() @Hook(TokenType.OpDec)							OpPostDec,
	@Builder() @Hook(TokenType.OpNot)							OpNot,
	@Builder() @Hook(TokenType.OpMul)							OpMul,
	@Builder() @Hook(TokenType.OpDiv)							OpDiv,
	@Builder() @Hook(TokenType.OpMod)							OpMod,
	@Builder() @Hook(TokenType.OpAdd)							OpAdd,
	@Builder() @Hook(TokenType.OpSub)							OpSub,
	@Builder() @Hook(TokenType.OpLShift)					OpLShift,
	@Builder() @Hook(TokenType.OpRShift)					OpRShift,
	@Builder() @Hook(TokenType.OpEquals)					OpEquals,
	@Builder() @Hook(TokenType.OpNotEquals)				OpNotEquals,
	@Builder() @Hook(TokenType.OpGreaterEquals)		OpGreaterEquals,
	@Builder() @Hook(TokenType.OpLesserEquals)		OpLesserEquals,
	@Builder() @Hook(TokenType.OpGreater)					OpGreater,
	@Builder() @Hook(TokenType.OpLesser)					OpLesser,
	@Builder() @Hook(TokenType.OpIs)							OpIs,
	@Builder() @Hook(TokenType.OpNotIs)						OpNotIs,
	@Builder() @Hook(TokenType.OpBinAnd)					OpBinAnd,
	@Builder() @Hook(TokenType.OpBinOr)						OpBinOr,
	@Builder() @Hook(TokenType.OpBinXor)					OpBinXor,
	@Builder() @Hook(TokenType.OpBoolAnd)					OpBoolAnd,
	@Builder() @Hook(TokenType.OpBoolOr)					OpBoolOr,
	@Builder() @Hook(TokenType.OpAssign)					OpAssign,
	@Builder() @Hook(TokenType.OpAddAssign)				OpAddAssign,
	@Builder() @Hook(TokenType.OpSubAssign)				OpSubAssign,
	@Builder() @Hook(TokenType.OpMulAssign)				OpMulAssign,
	@Builder() @Hook(TokenType.OpDivAssign)				OpDivAssign,
	@Builder() @Hook(TokenType.OpModAssign)				OpModAssign,
	@Builder() @Hook(TokenType.OpSubAssign)				OpBinAndAssign,
	@Builder() @Hook(TokenType.OpBinOrAssign)			OpBinOrAssign,
	@Builder() @Hook(TokenType.OpBinXorAssign)		OpBinXorAssign,
	@Builder() @Hook(TokenType.Trait)							Trait
}

private Node readScript(Token[] toks, ref uint index){
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

private Node readPubDecl(Token[] toks, ref uint index){
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

private Node readTemplateDecl(Token[] toks, ref uint index){
	if (!toks[index].type.get!(TokenType.Template))
		return null;
	// TODO continue from here
}

private Node readIntLiteral(Token[] toks, ref uint index){
	Node ret = new Node;
	ret.token = toks[index];
	index ++;
	return ret;
}
