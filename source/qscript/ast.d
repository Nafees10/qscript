module qscript.ast;

import std.json,
			 std.traits,
			 std.conv,
			 std.string,
			 std.stdio,
			 std.functional,
			 std.algorithm;

import qscript.compiler,
			 qscript.tokens;

import utils.ds;

/// A simple AST Node
public class Node{
public:
	Token token;
	NodeType type;
	Node[] children;

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
private alias BuilderFunc = Node function(ref Tokenizer, NodeType);

/// ASTNode builder function type for Binary and Postfix unary operators
private alias OpPostBuilderFunc = Node function(ref Tokenizer, Node, NodeType);

/// Returns: Flags constructed from array
private template FlagsFromArray(T, T[] vals) if (is(T == enum)){
	enum FlagsFromArray = getFlags;
	Flags!T getFlags(){
		Flags!T ret;
		static foreach (val; vals)
			ret |= val;
		return ret;
	}
}

/// read function for a NodeType
private template ReadFunction(NodeType type){
	enum ReadFunction = getReadFunction();
	BuilderFunc getReadFunction(){
		BuilderFunc ret = null;
		static foreach (sym; EnumMembers!NodeType){
			static if (type == sym && hasUDA!(sym, Builder)){
				ret = getUDAs!(sym, Builder)[0].builder;
			}
		}
		return ret;
	}
}

/// Precedence (if none found, default is 0)
private template PrecedenceOf(NodeType type){
	enum PrecedenceOf = getPrecedenceOf;
	private uint getPrecedenceOf(){
		uint ret;
		static foreach (node; EnumMembers!NodeType){
			static if (node == type){
				static if (hasUDA!(node, Precedence))
					ret = getUDAs!(node, Precedence)[0].precedence;
			}
		}
		return ret;
	}
}

/// if a node type is a operator
private template IsOperator(NodeType type){
	enum IsOperator = isOperator;
	private bool isOperator(){
		bool ret = false;
		static foreach (node; EnumMembers!NodeType){
			static if (node == type){
				ret = ret ||
					hasUDA!(node, BinOp) ||
					hasUDA!(node, PreOp) ||
					hasUDA!(node, PostOp);
			}
		}
		return ret;
	}
}

/// Operators that have a precedence equal to or greater
private template OfPrecedence(uint p){
	enum OfPrecedence = getOfPrecedence;
	private NodeType[] getOfPrecedence(){
		NodeType[] ret;
		static foreach (node; EnumMembers!NodeType){
			static if (IsOperator!node){
				static if (PrecedenceOf!node >= p)
					ret ~= node;
			}
		}
		return ret;
	}
}

/// Binary Operators
private enum BinOps = getBinOps;
private Flags!NodeType getBinOps(){
	NodeType[] ret;
	static foreach (type; EnumMembers!NodeType){
		static if (hasUDA!(type, BinOp))
			ret ~= type;
	}
	return ret;
}

/// Unary prefix operators
private enum PreOps = getPreOps;
private Flags!NodeType getPreOps(){
	NodeType[] ret;
	static foreach (type; EnumMembers!NodeType){
		static if (hasUDA!(type, PreOp))
			ret ~= type;
	}
	return ret;
}

/// Unary postfix operators
private enum PostOps = getPostOps;
private Flags!NodeType getPostOps(){
	NodeType[] ret;
	static foreach (type; EnumMembers!NodeType){
		static if (hasUDA!(type, PostOp))
			ret ~= type;
	}
	return ret;
}

/// Checks if token at front is matching type.
///
/// Returns: true if matched
private bool expect(TokenType type)(ref Tokenizer toks){
	return !toks.empty && toks.front.type.get!type;
}
/// ditto
private bool expect(TokenType[] types)(ref Tokenizer toks){
	if (toks.empty)
		return false;
	enum Flags!TokenType match = FlagsFromArray!(TokenType, types);
	return cast(bool)(match & toks.front.type);
}

/// Checks if token at front is matching type.
///
/// Throws: CompileError if not matching
private void expectThrow(TokenType type)(ref Tokenizer toks){
	if (!toks.expect!type)
		throw new CompileError(ErrorType.Expected, toks.front, [type.to!string]);
}

/// ditto
private void expectThrow(TokenType[] types)(ref Tokenizer toks){
	if (toks.expect!types)
		return;
	enum valsStr = types.map!(a => a.to!string).join(" or ");
	throw new CompileError(ErrorType.Expected, toks.front, [valsStr]);
}

/// Checks if token at front is matching type. Pops it if matching
///
/// Returns: true if matched
private bool expectPop(TokenType type)(ref Tokenizer toks){
	if (toks.expect!type){
		toks.popFront;
		return true;
	}
	return false;
}

/// ditto
private bool expectPop(TokenType[] types)(ref Tokenizer toks){
	if (toks.expect!types){
		toks.popFront;
		return true;
	}
	return false;
}

/// Checks if token at front is matching type.
///
/// Throws: CompileError if not matching
private void expectPopThrow(TokenType type)(ref Tokenizer toks){
	if (!toks.expectPop!type)
		throw new CompileError(ErrorType.Expected, toks.front, [type.to!string]);
}

/// ditto
private void expectPopThrow(TokenType[] types)(ref Tokenizer toks){
	if (toks.expectPop!types)
		return;
	enum valsStr = types.map!(a => a.to!string).join(" or ");
	throw new CompileError(ErrorType.Expected, toks.front, valsStr);
}

/// Tries to read a specific type of node from tokens
/// Will increment index to skip tokens consumed
///
/// Returns: Node
///
/// Throws: CompileError if node was going to be null
Node read(NodeType type)(ref Tokenizer toks){
	static NodeType context = NodeType.Script;
	if (toks.empty)
		throw new CompileError(ErrorType.UnexpectedEOF, toks.front);
	auto func = ReadFunction!type;
	static assert(ReadFunction!type !is null,
			"No build function for " ~ type.to!string);

	NodeType prevContext = context;
	context = type;
	auto branch = toks;
	auto ret = func(branch, context);
	context = prevContext;
	if (ret is null)
		throw new CompileError(ErrorType.Expected, toks.front, [type.to!string]);

	ret.type = type;
	toks = branch;
	return ret;
}

/// Tries to read node from one of specific types, based on hook
/// Will increment index to skip tokens consumed
///
/// Returns: Node, or null
Node read(NodeType[] types)(ref Tokenizer toks){
	if (toks.empty)
		throw new CompileError(ErrorType.UnexpectedEOF, toks.front);
	auto type = toks.front.type;
	static foreach (member; types){
		static foreach (Hook hook; getUDAs!(member, Hook)){
			if (type.get!(hook.hook)){
				auto branch = toks;
				auto ret = branch.read!member;
				if (ret !is null){
					toks = branch;
					return ret;
				}
			}
		}
	}
	enum valsStr = types.map!(a => a.to!string).join(" or ");
	throw new CompileError(ErrorType.Expected, toks.front, [valsStr]);
}

/// Tries to read token into node based off of token type hook
/// Will increment index to skip tokens consumed
///
/// Returns: Node or null
public Node read(ref Tokenizer toks){
	if (toks.empty)
		throw new CompileError(ErrorType.UnexpectedEOF, toks.front);
	auto type = toks.front.type;
	auto branch = toks;
	static foreach (member; EnumMembers!NodeType){
		static foreach (Hook hook; getUDAs!(member, Hook)){
			if (type.get!(hook.hook)){
				auto ret = branch.read!member;
				if (ret !is null){
					toks = branch;
					return ret;
				}
			}
		}
	}
	return null;
}

/// UDA for Builder function
private struct Builder{
	bool isOpPost;
	union{
		BuilderFunc builder;
		OpPostBuilderFunc opBuilder;
	}

	@disable this();
	this (BuilderFunc builder){
		this.builder = builder;
		this.isOpPost = false;
	}
	this (OpPostBuilderFunc opBuilder){
		this.opBuilder = opBuilder;
		this.isOpPost = true;
	}
}

/// UDA for hook in token type
private struct Hook{
	TokenType hook;
	this(TokenType hook){
		this.hook = hook;
	}
}

/// UDA for precedence. greater number is first
private struct Precedence{
	uint precedence;
	this(uint precedence){
		this.precedence = precedence;
	}
}

/// UDA for Binary Operator
enum BinOp;
/// UDA for Unary Pre Operator
enum PreOp;
/// UDA for Unary Post Operator
enum PostOp;

/// Node types
public enum NodeType{
	@Builder(&readScript)								Script,
	@Builder(&readPub)
		@Hook(TokenType.Pub)							Pub,

	@Builder(&readDeclaration)					Declaration,
	@Builder(&readTemplate)
		@Hook(TokenType.Template)					Template,
	@Builder(&readTemplateFn)
		@Hook(TokenType.TemplateFn)				TemplateFn,
	@Builder(&readTemplateEnum)
		@Hook(TokenType.TemplateEnum)			TemplateEnum,
	@Builder(&readTemplateStruct)
		@Hook(TokenType.TemplateStruct)		TemplateStruct,
	@Builder(&readTemplateVar)
		@Hook(TokenType.TemplateVar)			TemplateVar,
	@Builder(&readTemplateAlias)
		@Hook(TokenType.TemplateAlias)		TemplateAlias,
	@Builder(&readFn)
		@Hook(TokenType.Fn)								Fn,
	@Builder(&readVar)
		@Hook(TokenType.Var)							Var,
	@Builder(&readStruct)
		@Hook(TokenType.Struct)						Struct,
	@Builder(&readEnum)
		@Hook(TokenType.Enum)							Enum,
	@Builder(&readAlias)
		@Hook(TokenType.Alias)						Alias,

	@Builder(&readDataType)							DataType,
	@Builder(&readIndexBracketPair)			IndexBracketPair,
	@Builder(&readTemplateParamList)		TemplateParamList,
	@Builder(&readTemplateParam)				TemplateParam,
	@Builder(&readParamList)						ParamList,
	@Builder(&readParam)								Param,
	@Builder(&readNamedValue)						NamedValue,

	@Builder(&readStatement)						Statement,
	@Builder(&readIfStatement)
		@Hook(TokenType.If)								IfStatement,
	@Builder(&readStaticIfStatement)
		@Hook(TokenType.StaticIf)					StaticIfStatement,
	@Builder(&readWhileStatement)
		@Hook(TokenType.While)						WhileStatement,
	@Builder(&readDoWhileStatement)
		@Hook(TokenType.Do)								DoWhileStatement,
	@Builder(&readForStatement)
		@Hook(TokenType.For)							ForStatement,
	@Builder(&readStaticForStatement)
		@Hook(TokenType.StaticFor)				StaticForStatement,
	@Builder(&readBreakStatement)
		@Hook(TokenType.Break)						BreakStatement,
	@Builder(&readContinueStatement)
		@Hook(TokenType.Continue)					ContinueStatement,
	@Builder(&readBlock)
		@Hook(TokenType.CurlyOpen)				Block,

	@Builder(&readIdentifier)
		@Hook(TokenType.Identifier)				Identifier,
	@Builder(&readIntLiteral)
		@Hook(TokenType.LiteralInt)
		@Hook(TokenType.LiteralHexadecimal)
		@Hook(TokenType.LiteralBinary)		IntLiteral,
	@Builder(&readFloatLiteral)
		@Hook(TokenType.LiteralFloat)			FloatLiteral,
	@Builder(&readStringLiteral)
		@Hook(TokenType.LiteralString)		StringLiteral,
	@Builder(&readCharLiteral)
		@Hook(TokenType.LiteralChar)			CharLiteral,
	@Builder(&readNullLiteral)
		@Hook(TokenType.Null)							NullLiteral,
	@Builder(&readBoolLiteral)
		@Hook(TokenType.True)
		@Hook(TokenType.False)						BoolLiteral,

	@Builder(&readArgList)							ArgList,

	@Builder(&readTrait)
		@Hook(TokenType.Trait)						Trait,

	@Builder(&readExpression)						Expression,

	@Builder(&readLoadExpr)
		@Precedence(110)
		@PreOp
		@Hook(TokenType.Load)							LoadExpr,
	@Builder(&readBracketExpr)
		@Precedence(110)
		@PreOp
		@Hook(TokenType.BracketOpen)			BracketExpr,

	@Builder(&readArrowExpr)
		@Precedence(10)
		@BinOp
		@Hook(TokenType.Arrow)						ArrowExpr,
	@Builder(&readDotOp)
		@Precedence(100)
		@BinOp
		@Hook(TokenType.OpDot)						DotOp,
	@Builder(&readOpIndex)
		@Precedence(100)
		@BinOp
		@Hook(TokenType.OpIndex)					OpIndex,
	@Builder(&readOpCall)
		@Precedence(100)
		@BinOp
		@Hook(TokenType.OpFnCall)					OpCall,

	@Builder(&readOpPostInc)
		@Precedence(90)
		@PostOp
		@Hook(TokenType.OpInc)						OpPostInc,
	@Builder(&readOpPostDec)
		@Precedence(80)
		@PostOp
		@Hook(TokenType.OpDec)						OpPostDec,

	@Builder(&readOpPreInc)
		@Precedence(90)
		@PreOp
		@Hook(TokenType.OpInc)						OpPreInc,
	@Builder(&readOpPreDec)
		@Precedence(80)
		@PreOp
		@Hook(TokenType.OpDec)						OpPreDec,
	@Builder(&readOpNot)
		@Precedence(80)
		@PreOp
		@Hook(TokenType.OpNot)						OpNot,

	@Builder(&readOpMul)
		@Precedence(70)
		@BinOp
		@Hook(TokenType.OpMul)						OpMul,
	@Builder(&readOpDiv)
		@Precedence(70)
		@BinOp
		@Hook(TokenType.OpDiv)						OpDiv,
	@Builder(&readOpMod)
		@Precedence(70)
		@BinOp
		@Hook(TokenType.OpMod)						OpMod,

	@Builder(&readOpAdd)
		@Precedence(60)
		@BinOp
		@Hook(TokenType.OpAdd)						OpAdd,
	@Builder(&readOpSub)
		@Precedence(60)
		@BinOp
		@Hook(TokenType.OpSub)						OpSub,

	@Builder(&readOpLShift)
		@Precedence(50)
		@BinOp
		@Hook(TokenType.OpLShift)					OpLShift,
	@Builder(&readOpRShift)
		@Precedence(50)
		@BinOp
		@Hook(TokenType.OpRShift)					OpRShift,

	@Builder(&readOpEquals)
		@Precedence(40)
		@BinOp
		@Hook(TokenType.OpEquals)					OpEquals,
	@Builder(&readOpNotEquals)
		@Precedence(40)
		@BinOp
		@Hook(TokenType.OpNotEquals)			OpNotEquals,
	@Builder(&readOpGreaterEquals)
		@Precedence(40)
		@BinOp
		@Hook(TokenType.OpGreaterEquals)	OpGreaterEquals,
	@Builder(&readOpLesserEquals)
		@Precedence(40)
		@BinOp
		@Hook(TokenType.OpLesserEquals)		OpLesserEquals,
	@Builder(&readOpGreater)
		@Precedence(40)
		@BinOp
		@Hook(TokenType.OpGreater)				OpGreater,
	@Builder(&readOpLesser)
		@Precedence(40)
		@BinOp
		@Hook(TokenType.OpLesser)					OpLesser,
	@Builder(&readOpIs)
		@Precedence(40)
		@BinOp
		@Hook(TokenType.OpIs)							OpIs,
	@Builder(&readOpNotIs)
		@Precedence(40)
		@BinOp
		@Hook(TokenType.OpNotIs)					OpNotIs,

	@Builder(&readOpBinAnd)
		@Precedence(30)
		@BinOp
		@Hook(TokenType.OpBinAnd)					OpBinAnd,
	@Builder(&readOpBinOr)
		@Precedence(30)
		@BinOp
		@Hook(TokenType.OpBinOr)					OpBinOr,
	@Builder(&readOpBinXor)
		@Precedence(30)
		@BinOp
		@Hook(TokenType.OpBinXor)					OpBinXor,

	@Builder(&readOpBoolAnd)
		@Precedence(20)
		@BinOp
		@Hook(TokenType.OpBoolAnd)				OpBoolAnd,
	@Builder(&readOpBoolOr)
		@Precedence(20)
		@BinOp
		@Hook(TokenType.OpBoolOr)					OpBoolOr,

	@Builder(&readOpAssign)
		@Precedence(10)
		@BinOp
		@Hook(TokenType.OpAssign)					OpAssign,
	@Builder(&readOpAddAssign)
		@Precedence(10)
		@BinOp
		@Hook(TokenType.OpAddAssign)			OpAddAssign,
	@Builder(&readOpSubAssign)
		@Precedence(10)
		@BinOp
		@Hook(TokenType.OpSubAssign)			OpSubAssign,
	@Builder(&readOpMulAssign)
		@Precedence(10)
		@BinOp
		@Hook(TokenType.OpMulAssign)			OpMulAssign,
	@Builder(&readOpDivAssign)
		@Precedence(10)
		@BinOp
		@Hook(TokenType.OpDivAssign)			OpDivAssign,
	@Builder(&readOpModAssign)
		@Precedence(10)
		@BinOp
		@Hook(TokenType.OpModAssign)			OpModAssign,
	@Builder(&readOpBinAndAssign)
		@Precedence(10)
		@BinOp
		@Hook(TokenType.OpSubAssign)			OpBinAndAssign,
	@Builder(&readOpBinOrAssign)
		@Precedence(10)
		@BinOp
		@Hook(TokenType.OpBinOrAssign)		OpBinOrAssign,
	@Builder(&readOpBinXorAssign)
		@Precedence(10)
		@BinOp
		@Hook(TokenType.OpBinXorAssign)		OpBinXorAssign,
}

private Node readScript(ref Tokenizer toks, NodeType context){
	Node ret = new Node;
	while (!toks.empty)
		ret.children ~= toks.read!(NodeType.Declaration);
	return ret;
}

private Node readPub(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.Pub);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [toks.read!(NodeType.Declaration)];
	return ret;
}

private Node readDeclaration(ref Tokenizer toks, NodeType context){
	Node ret = new Node;
	ret.children = [
		toks.read!([
				NodeType.Pub,
				NodeType.LoadExpr,
				NodeType.Template,
				NodeType.TemplateFn,
				NodeType.TemplateEnum,
				NodeType.TemplateStruct,
				NodeType.TemplateVar,
				NodeType.TemplateAlias,
				NodeType.Fn,
				NodeType.Enum,
				NodeType.Struct,
				NodeType.Var,
				NodeType.Alias,
		])
	];
	return ret;
}

private Node readTemplate(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.Template);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.TemplateParamList),
		toks.read!(NodeType.Statement)
	];
	return ret;
}

private Node readTemplateFn(ref Tokenizer toks, NodeType context){
	toks.expect!(TokenType.TemplateFn);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.DataType),
		toks.read!(NodeType.Identifier),
		toks.read!(NodeType.TemplateParamList),
		toks.read!(NodeType.ParamList),
		toks.read!(NodeType.Statement)
	];
	return ret;
}

private Node readTemplateEnum(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.TemplateEnum);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.DataType),
		toks.read!(NodeType.Identifier),
		toks.read!(NodeType.TemplateParamList)
	];
	// from here on, there can be a block, or a single OpAssign
	if (toks.expectPop!(TokenType.OpAssign)){
		// single OpAssign
		ret.children ~= toks.read!(NodeType.Expression);
		// expect a semicolon
		if (!toks.expectPop!(TokenType.Semicolon))
			throw new CompileError(ErrorType.Expected, toks.front, [
					TokenType.Semicolon.to!string
			]);
		return ret;
	}
	// multiple values
	toks.expectPopThrow!(TokenType.CurlyOpen);

	while (true){
		ret.children ~= toks.read!(NodeType.NamedValue);
		if (toks.expectPop!(TokenType.CurlyClose))
			break;
		toks.expectPopThrow!(TokenType.Comma);
	}
	return ret;
}

private Node readTemplateStruct(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.TemplateStruct);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.Identifier),
		toks.read!(NodeType.TemplateParamList)
	];
	toks.expectPopThrow!(TokenType.CurlyOpen);
	while (true){
		ret.children ~= toks.read; // and hope its a declaration?
		if (toks.expectPop!(TokenType.CurlyClose))
			break;
	}
	return ret;
}

private Node readTemplateVar(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.TemplateVar);
	Node ret;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.DataType)
	];

	// now read ident paramlist optional( OpAssign Expr) [Comma or Semicolon]
	while (true){
		Node varNode = toks.read!(NodeType.Identifier);
		varNode.children = [
			toks.read!(NodeType.TemplateParamList)
		];
		if (toks.expectPop!(TokenType.OpAssign))
			varNode.children ~= toks.read!(NodeType.Identifier);

		if (toks.expectPop!(TokenType.Comma))
			continue;
		if (toks.expectPop!(TokenType.Semicolon))
			break;
	}
	return ret;
}

private Node readTemplateAlias(ref Tokenizer toks, NodeType context){
	toks.expectPopThrow!(TokenType.TemplateAlias);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.Identifier),
		toks.read!(NodeType.TemplateParamList),
		null // will replace it with what comes after opEquals
	];
	toks.expectPopThrow!(TokenType.OpAssign);
	ret.children[$ - 1] = toks.read; // read whatever
	toks.expectPopThrow!(TokenType.Semicolon); // expect semicolon at end
	return ret;
}

private Node readFn(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.Fn);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	try{
		auto branch = toks;
		ret.children = [
			branch.read!(NodeType.Identifier),
			branch.read!(NodeType.ParamList),
			branch.read!(NodeType.Statement)
		];
		toks = branch;
		return ret;
	}catch (CompileError){}

	ret.children = [
		toks.read!(NodeType.DataType),
		toks.read!(NodeType.Identifier),
		toks.read!(NodeType.ParamList),
		toks.read!(NodeType.Statement)
	];
	return ret;
}

private Node readVar(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.Var);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.DataType)
	];

	// now read ident optional( OpAssign Expr) [Comma or Semicolon]
	while (true){
		Node varNode = toks.read!(NodeType.Identifier);
		if (toks.expectPop!(TokenType.OpAssign))
			varNode.children = [toks.read!(NodeType.Expression)];
		ret.children ~= varNode;

		if (toks.expectPop!(TokenType.Comma))
			continue;
		if (toks.expectPop!(TokenType.Semicolon))
			break;
	}
	return ret;
}

private Node readStruct(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.Struct);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.Identifier),
	];
	toks.expectPopThrow!(TokenType.CurlyOpen);
	while (true){
		ret.children ~= toks.read; // and hope its a declaration?
		if (toks.expectPop!(TokenType.CurlyClose))
			break;
	}
	return ret;
}

private Node readEnum(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.Enum);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.DataType),
		toks.read!(NodeType.Identifier),
	];
	if (toks.expectPop!(TokenType.OpAssign)){
		// single OpAssign
		ret.children ~= toks.read!(NodeType.Expression);
		toks.expectPopThrow!(TokenType.Semicolon); // expect a semicolon
		return ret;
	}
	// multiple values
	toks.expectPopThrow!(TokenType.CurlyOpen);
	while (true){
		ret.children ~= toks.read!(NodeType.NamedValue);
		if (toks.expectPop!(TokenType.CurlyClose))
			break;
		toks.expectPopThrow!(TokenType.Comma);
	}
	return ret;
}

private Node readAlias(ref Tokenizer toks, NodeType context){
	toks.expectPopThrow!(TokenType.Alias);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [
		toks.read!(NodeType.Identifier),
		null // will replace it with what comes after opEquals
	];
	toks.expectPopThrow!(TokenType.OpAssign);
	ret.children[$ - 1] = toks.read; // read whatever
	// expect a semicolon
	toks.expectPopThrow!(TokenType.Semicolon);
	return ret;
}

private Node readDataType(ref Tokenizer toks, NodeType context){
	Node ret = new Node;
	// maybe its a ref?
	if (toks.expect!(TokenType.Ref)){
		// ref not allowed if context is already DataType, ref of ref is very bad
		if (context == NodeType.DataType)
			throw new CompileError(ErrorType.ExpectedAFoundB, toks.front, [
					"Data Type", "ref"
			]);
		ret.token = toks.front;
		toks.popFront;
		ret.children = [
			toks.read!(NodeType.DataType)
		];
		return ret;
	}

	if (toks.expect!(TokenType.Auto)){ // maybe its auto?
		ret.token = toks.front;
		toks.popFront;
		return ret; // auto cannot have [] at end, so just return here
	}else if (toks.expect!(TokenType.Fn)){ // maybe its a fn?
		ret.token = toks.front;
		toks.popFront;
		ret.children = [
			toks.read!(NodeType.DataType), // return type
			toks.read!(NodeType.ParamList)
		];
	}else if (toks.expect!(TokenType.Int) || // or a primitive type
			toks.expect!(TokenType.Float) ||
			toks.expect!(TokenType.Bool) ||
			toks.expect!(TokenType.String) ||
			toks.expect!(TokenType.Char)){
		ret.token = toks.front;
		toks.popFront;
	}else{ // fine! its an expression
		ret.token = toks.front; // just a dummy
		ret.children = [
			toks.read!(NodeType.Expression)
		];
	}

	// now maybe it has bunch of [] making it an array
	while (toks.expect!(TokenType.IndexOpen)){
		ret.children ~= toks.read!(NodeType.IndexBracketPair);
	}
	return ret;
}

private Node readIndexBracketPair(ref Tokenizer toks, NodeType context){
	Node ret = new Node;
	toks.expectThrow!(TokenType.IndexOpen);
	ret.token = toks.front;
	toks.popFront;
	toks.expectPopThrow!(TokenType.IndexClose);
	return ret;
}

private Node readTemplateParamList(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.BracketOpen);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	while (!toks.expectPop!(TokenType.BracketClose)){
		ret.children ~= toks.read!(NodeType.TemplateParam);
	}
	return ret;
}

private Node readTemplateParam(ref Tokenizer toks, NodeType context){
	// can be:
	// DataType Identifier
	// Identifier
	auto branch = toks;
	try{
		Node ret = branch.read!(NodeType.DataType);
		ret.children = [
			branch.read!(NodeType.Identifier)
		];
		if (!branch.expect!(TokenType.BracketClose))
			branch.expectPopThrow!(TokenType.Comma);
		toks = branch;
		return ret;
	}catch (CompileError){}

	branch = toks;
	try{
		Node ret = branch.read!(NodeType.Identifier);
		if (!branch.expect!(TokenType.BracketClose))
			branch.expectPopThrow!(TokenType.Comma);
		toks = branch;
		return ret;
	}catch (CompileError){}
	return null; // and cause read to throw CompileError
}

private Node readParamList(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.BracketOpen);
	Node ret = new Node;
	ret.token = toks.front;
	while (!toks.expectPop!(TokenType.BracketClose))
		ret.children ~= toks.read!(NodeType.Param);
	return ret;
}

private Node readParam(ref Tokenizer toks, NodeType context){
	// can be:
	// DataType Identifier
	// DataType
	auto branch = toks;
	try{
		Node ret = branch.read!(NodeType.DataType);
		ret.children = [
			branch.read!(NodeType.Identifier)
		];
		if (!branch.expect!(TokenType.BracketClose))
			branch.expectPopThrow!(TokenType.Comma);
		toks = branch;
		return ret;
	}catch (CompileError){}

	branch = toks;
	try{
		Node ret = branch.read!(NodeType.DataType);
		if (!branch.expect!(TokenType.BracketClose))
			branch.expectPopThrow!(TokenType.Comma);
		toks = branch;
		return ret;
	}catch (CompileError){}
	return null; // will cause calling read function to throw CompileError
}

/// reads `foo = bar`
private Node readNamedValue(ref Tokenizer toks, NodeType context){
	Node ret = new Node;
	Node name = toks.read!(NodeType.Identifier);
	toks.expectThrow!(TokenType.OpAssign);
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		name,
		toks.read!(NodeType.Expression)
	];
	return ret;
}

private Node readStatement(ref Tokenizer toks, NodeType context){
	// a statement can be a declaration, or some predefined statement,
	// or an expression
	Node ret = new Node;
	ret.token = toks.front;
	try{
		auto branch = toks; // branch out
		ret.children = [branch.read!(NodeType.Declaration)];
		toks = branch; // merge back in
		return ret;
	}catch (CompileError){}

	try{
		auto branch = toks;
		ret.children = [
			branch.read!([
				NodeType.IfStatement,
				NodeType.StaticIfStatement,
				NodeType.WhileStatement,
				NodeType.DoWhileStatement,
				NodeType.ForStatement,
				NodeType.StaticForStatement,
				NodeType.BreakStatement,
				NodeType.ContinueStatement,
				NodeType.Block,
			])
		];
		toks = branch;
		return ret;
	}catch (CompileError){}

	try{
		auto branch = toks;
		ret.children = [branch.read!(NodeType.Expression)];
		toks = branch;
		return ret;
	}catch (CompileError){}
	return null;
}

private Node readIfStatement(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.If);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		toks.read!(NodeType.Expression), // TODO maybe change to BracketExpr?
		toks.read!(NodeType.Statement)
	];
	if (toks.expectPop!(TokenType.Else))
		ret.children ~= toks.read!(NodeType.Statement);
	return ret;
}

private Node readStaticIfStatement(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.StaticIf);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		toks.read!(NodeType.Expression), // TODO maybe change to BracketExpr?
		toks.read!(NodeType.Statement)
	];
	if (toks.expectPop!(TokenType.Else))
		ret.children ~= toks.read!(NodeType.Statement);
	return ret;
}

private Node readWhileStatement(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.While);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		toks.read!(NodeType.Expression), // TODO maybe change to BracketExpr?
		toks.read!(NodeType.Statement)
	];
	return ret;
}

private Node readDoWhileStatement(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.Do);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		toks.read!(NodeType.Statement),
		null // fill later with condition expression
	];
	toks.expectPopThrow!(TokenType.While);
	ret.children[$ - 1] = toks.read!(NodeType.Expression); // TODO BracketExpr?
	toks.expectPopThrow!(TokenType.Semicolon); // expect a semicolon
	return ret;
}

private Node readForStatement(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.For);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	toks.expectPopThrow!(TokenType.BracketOpen);
	Node node = toks.read!(NodeType.Identifier);
	if (toks.expectPop!(TokenType.Comma)){
		ret.children ~= node; // iteration counter
		node = toks.read!(NodeType.Identifier);
	}
	ret.children ~= node; // iteration element

	toks.expectPopThrow!(TokenType.Semicolon);
	ret.children ~= toks.read!(NodeType.Expression); // range

	toks.expectPopThrow!(TokenType.BracketClose);
	ret.children ~= toks.read!(NodeType.Statement); // loop body
	return ret;
}

private Node readStaticForStatement(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.StaticFor);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	toks.expectPopThrow!(TokenType.BracketOpen);
	Node node = toks.read!(NodeType.Identifier);
	if (toks.expectPop!(TokenType.Comma)){
		ret.children ~= node; // iteration counter
		node = toks.read!(NodeType.Identifier);
	}
	ret.children ~= node; // iteration element

	toks.expectPopThrow!(TokenType.Semicolon);
	ret.children ~= toks.read!(NodeType.Expression); // range

	toks.expectPopThrow!(TokenType.BracketClose);
	ret.children ~= toks.read!(NodeType.Statement); // loop body
	return ret;
}

private Node readBreakStatement(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.Break);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	toks.expectPopThrow!(TokenType.Semicolon);
	return ret;
}

private Node readContinueStatement(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.Continue);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	toks.expectPopThrow!(TokenType.Semicolon);
	return ret;
}

private Node readBlock(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.CurlyOpen);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	while (true){
		if (toks.expectPop!(TokenType.CurlyClose))
			break;
		ret.children ~= toks.read!(NodeType.Statement);
	}
	return ret;
}

private Node readIdentifier(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.Identifier);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}

private Node readIntLiteral(ref Tokenizer toks, NodeType context){
	toks.expectThrow!([
		TokenType.LiteralInt,
		TokenType.LiteralBinary,
		TokenType.LiteralHexadecimal
	]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}

private Node readFloatLiteral(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.LiteralFloat);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}

private Node readStringLiteral(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.LiteralString);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}

private Node readCharLiteral(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.LiteralChar);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}

private Node readNullLiteral(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.Null);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}

private Node readBoolLiteral(ref Tokenizer toks, NodeType context){
	toks.expectThrow!([
			TokenType.True,
			TokenType.False
	]);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}

private Node readArgList(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.BracketOpen);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	if (toks.expectPop!(TokenType.BracketClose))
		return ret;

	while (true){
		ret.children ~= toks.read!(NodeType.Expression);
		if (toks.expectPop!(TokenType.BracketClose))
			break;
		toks.expectPopThrow!(TokenType.Comma);
	}
	return ret;
}

private Node readTrait(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.Trait);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		toks.read!(NodeType.ArgList)
	];
	return ret;
}

private Node readExpression(ref Tokenizer toks, NodeType context){
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret; // TODO implement readExpression
}

private Node readLoadExpr(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(TokenType.Load);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	toks.expectPopThrow!(TokenType.BracketOpen);
	while (true){
		ret.children ~= toks.read!(NodeType.Identifier);
		if (toks.expectPop!(TokenType.BracketClose))
			break;
		toks.expectPopThrow!(TokenType.OpDot);
	}
	return ret;
}
