module qscript.parser;

import std.json,
			 std.traits,
			 std.conv,
			 std.string,
			 std.stdio,
			 std.functional,
			 std.algorithm,
			 std.meta,
			 std.array;

import qscript.compiler,
			 qscript.tokens;

import utils.ds;

/// A Node
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
		foreach (child; children){
			if (child is null)
				sub ~= JSONValue(null);
			else
				sub ~= child.toJSON;
		}
		if (sub.length)
			ret["children"] = sub;
		return ret;
	}
}

/// Node builder function type
private alias BuilderFunc = Node function(ref Tokenizer, NodeType);

/// Node builder function type for Binary and Postfix unary operators
private alias OpPostBuilderFunc = Node function(ref Tokenizer, Node, NodeType);

/// Returns: Flags constructed from AliasSeq
private template FlagsFromAliasSeq(Vals...) if (
		Vals.length > 0 &&
		is(typeof(Vals[0]) == enum)){
	alias T = typeof(Vals[0]);
	enum FlagsFromAliasSeq = getFlags;
	Flags!T getFlags(){
		Flags!T ret;
		static foreach (val; Vals){
			static if (!is(typeof(val) == T))
				static assert(false, "Vals not all of same type: " ~
						typeof(val).stringof ~ " != " ~ T.stringof);
			ret |= val;
		}
		return ret;
	}
}

/// ditto
private Flags!TokenType flagsFromVals(TokenType[] vals){
	Flags!TokenType ret;
	foreach (val; vals)
		ret |= val;
	return ret;
}

/// stringof's all other template parameters, and joins with a string
private template JoinStringOf(string Jstr, Vals...){
	enum JoinStringOf = getJoinStringOf;
	private string getJoinStringOf(){
		string ret;
		static foreach (i, val; Vals){
			ret ~= val.to!string;
			static if (i + 1 < Vals.length)
				ret ~= Jstr;
		}
		return ret;
	}
}

/// Precedence (if none found, default is 0)
private template PrecedenceOf(alias type){
	enum PrecedenceOf = getPrecedenceOf();
	private uint getPrecedenceOf(){
		static if (hasUDA!(type, Precedence))
			return getUDAs!(type, Precedence)[0].precedence;
		else
			return 0;
	}
}

/// Returns: precedence of a NodeType, or 0
private uint precedenceOf(NodeType type){
	switch (type){
		static foreach(member; EnumMembers!NodeType){
			case member:
				return PrecedenceOf!member;
		}
		default: return 0;
	}
}

/// All precedences
private template Precedences(){
	alias Precedences = AliasSeq!();
	static foreach (member; EnumMembers!NodeType)
		Precedences = AliasSeq!(Precedences, member);
	Precedences = NoDuplicates!Precedences;
}

/// subset that have a precedence equal to or greater
private template HigherPreced(uint P, Ops...){
	alias HigherPreced = AliasSeq!();
	static foreach (node; Ops){
		static if (PrecedenceOf!node >= P)
			HigherPreced = AliasSeq!(HigherPreced, node);
	}
}

/// ditto
private NodeType[] higherPreced(uint p, NodeType[] ops){
	return ops.filter!(a => a.precedenceOf >= p).array;
}

/// AliasSeq of TokenType of Hooks for given NodeTypes AliasSeq
private template Hooks(Types...){
	alias Hooks = AliasSeq!();
	static foreach (node; Types){
		static foreach (tokType; getUDAs!(node, TokenType))
			Hooks = AliasSeq!(Hooks, tokType);
	}
}

/// Binary Operators NodeTypes with Precedence >= P
private template BinOps(uint P = 0){
	alias BinOps = AliasSeq!();
	static foreach (type; EnumMembers!NodeType){
		static if (hasUDA!(type, BinOp) && PrecedenceOf!type >= P)
			BinOps = AliasSeq!(BinOps, type);
	}
}

/// Unary Prefix Operators with Precedence >= P
private template PreOps(uint P = 0){
	alias PreOps = AliasSeq!();
	static foreach (type; EnumMembers!NodeType){
		static if (hasUDA!(type, PreOp) && PrecedenceOf!type >= P)
			PreOps = AliasSeq!(PreOps, type);
	}
}

/// Unary Prefix Operators with Precedence >= P
private template PostOps(uint P = 0){
	alias PostOps = AliasSeq!();
	static foreach (type; EnumMembers!NodeType){
		static if (hasUDA!(type, PostOp) && PrecedenceOf!type >= P)
			PostOps = AliasSeq!(PostOps, type);
	}
}

/// Checks if token at front is matching type.
///
/// Returns: true if matched
private bool expect(Types...)(ref Tokenizer toks){
	if (toks.empty)
		return false;
	enum Flags!TokenType match = FlagsFromAliasSeq!Types;
	return cast(bool)(match & toks.front.type);
}

/// Checks if token at front is matching type.
///
/// Throws: CompileError if not matching
private void expectThrow(Types...)(ref Tokenizer toks){
	if (toks.expect!Types)
		return;
	enum valsStr = JoinStringOf!(" or ", Types);
	throw new CompileError(ErrorType.Expected, toks.front, [valsStr]);
}

/// Checks if token at front is matching type. Pops it if matching
///
/// Returns: true if matched
private bool expectPop(Types...)(ref Tokenizer toks){
	if (toks.expect!Types){
		toks.popFront;
		return true;
	}
	return false;
}

/// Checks if token at front is matching type.
///
/// Throws: CompileError if not matching
private void expectPopThrow(Types...)(ref Tokenizer toks){
	if (toks.expectPop!Types)
		return;
	enum string valsStr = JoinStringOf!(" or ", Types);
	throw new CompileError(ErrorType.Expected, toks.front, [valsStr]);
}

/// current context (NodeType of calling function)
private NodeType _context = NodeType.Script;

/// Tries to read a specific type(s) of node from tokens.
/// Works for regular Nodes, and Prefix Unary Operators
///
/// Returns: Node
///
/// Throws: CompileError on error
private Node readType(alias type)(ref Tokenizer toks) if (
		is(typeof(type) == NodeType) &&
		hasUDA!(type, Builder) &&
		!getUDAs!(type, Builder)[0].isOpPost){
	if (toks.empty)
		throw new CompileError(ErrorType.UnexpectedEOF, toks.front);
	enum func = getUDAs!(type, Builder)[0].builder;
	static assert(func !is null, "No build function for " ~ type.to!string);

	NodeType prevContext = _context;
	_context = type;
	auto branch = toks;
	auto ret = func(branch, prevContext);
	_context = prevContext;
	if (ret is null)
		throw new CompileError(ErrorType.Expected, toks.front, [type.to!string]);
	ret.type = type;
	toks = branch;
	return ret;
}

/// ditto
private Node read(Types...)(ref Tokenizer toks){
	static if (Types.length == 1){
		return toks.readType!(Types);
	}else{
		if (toks.empty)
			throw new CompileError(ErrorType.UnexpectedEOF, toks.front);
		auto type = toks.front.type;
		static foreach (member; Types){
			static if (hasUDA!(member, Builder) &&
					!getUDAs!(member, Builder)[0].isOpPost){
				static foreach (tokType; getUDAs!(member, TokenType)){
					if (type.get!(tokType)){
						auto branch = toks;
						auto ret = branch.readType!member;
						if (ret !is null){
							toks = branch;
							return ret;
						}
					}
				}
			}
		}
		enum string valsStr = JoinStringOf!(" or ", Types);
		throw new CompileError(ErrorType.Expected, toks.front, [valsStr]);
	}
}

/// ditto
private Node readWithPrecedence(uint P, Types...)(ref Tokenizer toks){
	return toks.read!(HigherPreced!(P, Types));
}

/// ditto
private Node read(Types...)(ref Tokenizer toks, uint p){
	switch (p){
		static foreach (precedence; Precedences!()){
			case precedence:
				return toks.readWithPrecedence!(precedence, Types);
		}
		default:
			throw new CompileError(ErrorType.Expected, toks.front, [
					JoinStringOf!(" or ", Types)
			]);
	}
}

/// Tries to read a specific type of node from tokens.
/// Works for Binary and Postfix Unary Operators
///
/// Returns: Node
///
/// Throws: CompileError on error
private Node readType(alias type)(ref Tokenizer toks, Node a) if (
		is(typeof(type) == NodeType) &&
		hasUDA!(type, Builder) &&
		getUDAs!(type, Builder)[0].isOpPost){
	if (toks.empty)
		throw new CompileError(ErrorType.UnexpectedEOF, toks.front);
	enum func = getUDAs!(type, Builder)[0].opBuilder;
	static assert(func !is null, "No build function for " ~ type.to!string);

	NodeType prevContext = _context;
	_context = type;
	auto branch = toks;
	auto ret = func(branch, a, prevContext);
	_context = prevContext;
	if (ret is null)
		throw new CompileError(ErrorType.Expected, toks.front, [type.to!string]);
	ret.type = type;
	toks = branch;
	return ret;
}

/// ditto
private Node read(Types...)(ref Tokenizer toks, Node a){
	static if (Types.length == 1){
		return toks.readType!(Types)(a);
	}else{
		if (toks.empty)
			throw new CompileError(ErrorType.UnexpectedEOF, toks.front);
		auto type = toks.front.type;
		static foreach (member; Types){
			static if (hasUDA!(member, Builder) &&
					getUDAs!(member, Builder)[0].isOpPost){
				static foreach (tokType; getUDAs!(member, TokenType)){
					if (type.get!(tokType)){
						auto branch = toks;
						auto ret = branch.readType!member(a);
						if (ret !is null){
							toks = branch;
							return ret;
						}
					}
				}
			}
		}
		enum string valsStr = JoinStringOf!(" or ", Types);
		throw new CompileError(ErrorType.Expected, toks.front, [valsStr]);
	}
}

/// ditto
private Node readWithPrecedence(uint P, Types...)(ref Tokenizer toks, Node a){
	return toks.read!(HigherPreced!(P, Types))(a);
}

/// ditto
private Node read(Types...)(ref Tokenizer toks, Node a, uint p){
	switch (p){
		static foreach (precedence; Precedences!()){
			case precedence:
				return toks.readWithPrecedence!(precedence, Types)(a);
		}
		default:
			throw new CompileError(ErrorType.Expected, toks.front, [
					JoinStringOf!(" or ", Types)
			]);
	}
}

/// Tries to read token into node based off of token type hook
///
/// Returns: Node or null
private Node read(ref Tokenizer toks){
	if (toks.empty)
		throw new CompileError(ErrorType.UnexpectedEOF, toks.front);
	auto type = toks.front.type;
	auto branch = toks;
	static foreach (member; EnumMembers!NodeType){
		static if (hasUDA!(member, Builder) &&
				!getUDAs!(member, Builder)[0].isOpPost){
			static foreach (tokType; getUDAs!(member, TokenType)){
				if (type.get!(tokType)){
					auto ret = branch.readType!(member);
					if (ret !is null){
						toks = branch;
						return ret;
					}
				}
			}
		}
	}
	return null;
}

/// UDA for Builder function
private struct Builder{
	bool isOpPost;
	struct{
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
	@Builder(&readScript)							Script,
	@Builder(&readPub)
		@(TokenType.Pub)								Pub,

	@Builder(&readDeclaration)				Declaration,
	@Builder(&readTemplate)
		@(TokenType.Template)						Template,
	@Builder(&readTemplateFn)
		@(TokenType.TemplateFn)					TemplateFn,
	@Builder(&readTemplateEnum)
		@(TokenType.TemplateEnum)				TemplateEnum,
	@Builder(&readTemplateStruct)
		@(TokenType.TemplateStruct)			TemplateStruct,
	@Builder(&readTemplateVar)
		@(TokenType.TemplateVar)				TemplateVar,
	@Builder(&readTemplateAlias)
		@(TokenType.TemplateAlias)			TemplateAlias,
	@Builder(&readFn)
		@(TokenType.Fn)									Fn,
	@Builder(&readVar)
		@(TokenType.Var)								Var,
	@Builder(&readStruct)
		@(TokenType.Struct)							Struct,
	@Builder(&readEnum)
		@(TokenType.Enum)								Enum,
	@Builder(&readAlias)
		@(TokenType.Alias)							Alias,

	@Builder(&readDataType)						DataType,
	@Builder(&readIndexBracketPair)		IndexBracketPair,
	@Builder(&readTemplateParamList)	TemplateParamList,
	@Builder(&readTemplateParam)			TemplateParam,
	@Builder(&readParamList)					ParamList,
	@Builder(&readParam)							Param,
	@Builder(&readNamedValue)					NamedValue,

	@Builder(&readStatement)					Statement,
	@Builder(&readIfStatement)
		@(TokenType.If)									IfStatement,
	@Builder(&readStaticIfStatement)
		@(TokenType.StaticIf)						StaticIfStatement,
	@Builder(&readWhileStatement)
		@(TokenType.While)							WhileStatement,
	@Builder(&readDoWhileStatement)
		@(TokenType.Do)									DoWhileStatement,
	@Builder(&readForStatement)
		@(TokenType.For)								ForStatement,
	@Builder(&readStaticForStatement)
		@(TokenType.StaticFor)					StaticForStatement,
	@Builder(&readBreakStatement)
		@(TokenType.Break)							BreakStatement,
	@Builder(&readContinueStatement)
		@(TokenType.Continue)						ContinueStatement,
	@Builder(&readBlock)
		@(TokenType.CurlyOpen)					Block,

	@Builder(&readExprUnit)						ExprUnit,
	@Builder(&readIdentifier)
		@(TokenType.Identifier)					Identifier,
	@Builder(&readIntLiteral)
		@(TokenType.LiteralInt)
		@(TokenType.LiteralHexadecimal)
		@(TokenType.LiteralBinary)			IntLiteral,
	@Builder(&readFloatLiteral)
		@(TokenType.LiteralFloat)				FloatLiteral,
	@Builder(&readStringLiteral)
		@(TokenType.LiteralString)			StringLiteral,
	@Builder(&readCharLiteral)
		@(TokenType.LiteralChar)				CharLiteral,
	@Builder(&readNullLiteral)
		@(TokenType.Null)								NullLiteral,
	@Builder(&readBoolLiteral)
		@(TokenType.True)
		@(TokenType.False)							BoolLiteral,

	@Builder(&readArgList)						ArgList,

	@Builder(&readTrait)
		@(TokenType.Trait)							Trait,

	@Builder(&readExpression)
		@(TokenType.BracketOpen)				Expression,

	@Builder(&readLoadExpr)
		@Precedence(110)
		@PreOp
		@(TokenType.Load)								LoadExpr,

	@Builder(&readArrowFunc)
		@Precedence(100)
		@PreOp // just a hack, its a binary operator IRL
		@(TokenType.BracketOpen)				ArrowFunc,

	@Builder(&readBinOp)
		@Precedence(100)
		@BinOp
		@(TokenType.OpDot)							DotOp,
	@Builder(&readOpIndex)
		@Precedence(100)
		@BinOp
		@(TokenType.OpIndex)						OpIndex,
	@Builder(&readOpCall)
		@Precedence(100)
		@BinOp
		@(TokenType.OpFnCall)						OpCall,

	@Builder(&readPostOp)
		@Precedence(90)
		@PostOp
		@(TokenType.OpInc)							OpPostInc,
	@Builder(&readPostOp)
		@Precedence(80)
		@PostOp
		@(TokenType.OpDec)							OpPostDec,

	@Builder(&readPreOp)
		@Precedence(90)
		@PreOp
		@(TokenType.OpInc)							OpPreInc,
	@Builder(&readPreOp)
		@Precedence(80)
		@PreOp
		@(TokenType.OpDec)							OpPreDec,
	@Builder(&readPreOp)
		@Precedence(80)
		@PreOp
		@(TokenType.OpNot)							OpNot,

	@Builder(&readBinOp)
		@Precedence(70)
		@BinOp
		@(TokenType.OpMul)							OpMul,
	@Builder(&readBinOp)
		@Precedence(70)
		@BinOp
		@(TokenType.OpDiv)							OpDiv,
	@Builder(&readBinOp)
		@Precedence(70)
		@BinOp
		@(TokenType.OpMod)							OpMod,

	@Builder(&readBinOp)
		@Precedence(60)
		@BinOp
		@(TokenType.OpAdd)							OpAdd,
	@Builder(&readBinOp)
		@Precedence(60)
		@BinOp
		@(TokenType.OpSub)							OpSub,

	@Builder(&readBinOp)
		@Precedence(50)
		@BinOp
		@(TokenType.OpLShift)						OpLShift,
	@Builder(&readBinOp)
		@Precedence(50)
		@BinOp
		@(TokenType.OpRShift)						OpRShift,

	@Builder(&readBinOp)
		@Precedence(40)
		@BinOp
		@(TokenType.OpEquals)						OpEquals,
	@Builder(&readBinOp)
		@Precedence(40)
		@BinOp
		@(TokenType.OpNotEquals)				OpNotEquals,
	@Builder(&readBinOp)
		@Precedence(40)
		@BinOp
		@(TokenType.OpGreaterEquals)		OpGreaterEquals,
	@Builder(&readBinOp)
		@Precedence(40)
		@BinOp
		@(TokenType.OpLesserEquals)			OpLesserEquals,
	@Builder(&readBinOp)
		@Precedence(40)
		@BinOp
		@(TokenType.OpGreater)					OpGreater,
	@Builder(&readBinOp)
		@Precedence(40)
		@BinOp
		@(TokenType.OpLesser)						OpLesser,
	@Builder(&readBinOp)
		@Precedence(40)
		@BinOp
		@(TokenType.OpIs)								OpIs,
	@Builder(&readBinOp)
		@Precedence(40)
		@BinOp
		@(TokenType.OpNotIs)						OpNotIs,

	@Builder(&readBinOp)
		@Precedence(30)
		@BinOp
		@(TokenType.OpBinAnd)						OpBinAnd,
	@Builder(&readBinOp)
		@Precedence(30)
		@BinOp
		@(TokenType.OpBinOr)						OpBinOr,
	@Builder(&readBinOp)
		@Precedence(30)
		@BinOp
		@(TokenType.OpBinXor)						OpBinXor,

	@Builder(&readBinOp)
		@Precedence(20)
		@BinOp
		@(TokenType.OpBoolAnd)					OpBoolAnd,
	@Builder(&readBinOp)
		@Precedence(20)
		@BinOp
		@(TokenType.OpBoolOr)						OpBoolOr,

	@Builder(&readBinOp)
		@Precedence(10)
		@BinOp
		@(TokenType.OpAssign)						OpAssign,
	@Builder(&readBinOp)
		@Precedence(10)
		@BinOp
		@(TokenType.OpAddAssign)				OpAddAssign,
	@Builder(&readBinOp)
		@Precedence(10)
		@BinOp
		@(TokenType.OpSubAssign)				OpSubAssign,
	@Builder(&readBinOp)
		@Precedence(10)
		@BinOp
		@(TokenType.OpMulAssign)				OpMulAssign,
	@Builder(&readBinOp)
		@Precedence(10)
		@BinOp
		@(TokenType.OpDivAssign)				OpDivAssign,
	@Builder(&readBinOp)
		@Precedence(10)
		@BinOp
		@(TokenType.OpModAssign)				OpModAssign,
	@Builder(&readBinOp)
		@Precedence(10)
		@BinOp
		@(TokenType.OpSubAssign)				OpBinAndAssign,
	@Builder(&readBinOp)
		@Precedence(10)
		@BinOp
		@(TokenType.OpBinOrAssign)			OpBinOrAssign,
	@Builder(&readBinOp)
		@Precedence(10)
		@BinOp
		@(TokenType.OpBinXorAssign)			OpBinXorAssign,
}

public Node parseScript(ref Tokenizer toks){
	return readScript(toks, NodeType.init);
}

private Node readScript(ref Tokenizer toks, NodeType){
	Node ret = new Node;
	while (!toks.empty)
		ret.children ~= toks.read!(NodeType.Declaration);
	return ret;
}

private Node readPub(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.Pub);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	ret.children = [toks.read!(NodeType.Declaration)];
	return ret;
}

private Node readDeclaration(ref Tokenizer toks, NodeType){
	Node ret = new Node;
	ret.children = [
		toks.read!(
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
		)
	];
	return ret;
}

private Node readTemplate(ref Tokenizer toks, NodeType){
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

private Node readTemplateFn(ref Tokenizer toks, NodeType){
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

private Node readTemplateEnum(ref Tokenizer toks, NodeType){
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

private Node readTemplateStruct(ref Tokenizer toks, NodeType){
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

private Node readTemplateVar(ref Tokenizer toks, NodeType){
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

private Node readTemplateAlias(ref Tokenizer toks, NodeType){
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

private Node readFn(ref Tokenizer toks, NodeType){
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

private Node readVar(ref Tokenizer toks, NodeType){
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

private Node readStruct(ref Tokenizer toks, NodeType){
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

private Node readEnum(ref Tokenizer toks, NodeType){
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

private Node readAlias(ref Tokenizer toks, NodeType){
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

private Node readIndexBracketPair(ref Tokenizer toks, NodeType){
	Node ret = new Node;
	toks.expectThrow!(TokenType.IndexOpen);
	ret.token = toks.front;
	toks.popFront;
	toks.expectPopThrow!(TokenType.IndexClose);
	return ret;
}

private Node readTemplateParamList(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.BracketOpen);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	while (!toks.expectPop!(TokenType.BracketClose)){
		ret.children ~= toks.read!(NodeType.TemplateParam);
	}
	return ret;
}

private Node readTemplateParam(ref Tokenizer toks, NodeType){
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

private Node readParamList(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.BracketOpen);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	while (!toks.expectPop!(TokenType.BracketClose))
		ret.children ~= toks.read!(NodeType.Param);
	return ret;
}

private Node readParam(ref Tokenizer toks, NodeType){
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
private Node readNamedValue(ref Tokenizer toks, NodeType){
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
	auto branch = toks; // branch out
	try{
		ret.children = [branch.read!(NodeType.Declaration)];
		toks = branch; // merge back in
		return ret;
	}catch (CompileError){}
	branch = toks;
	try{
		ret.children = [
			branch.read!(
				NodeType.IfStatement,
				NodeType.StaticIfStatement,
				NodeType.WhileStatement,
				NodeType.DoWhileStatement,
				NodeType.ForStatement,
				NodeType.StaticForStatement,
				NodeType.BreakStatement,
				NodeType.ContinueStatement,
				NodeType.Block,
			)
		];
		toks = branch;
		return ret;
	}catch (CompileError){}

	branch = toks;
	try{
		ret.children = [branch.read!(NodeType.Expression)];
		toks = branch;
	}catch (CompileError){}
	if (!ret)
		return null;
	// expect semicolon
	toks.expectPopThrow!(TokenType.Semicolon);
	return ret;
}

private Node readIfStatement(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.If);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		toks.read!(NodeType.Expression),
		toks.read!(NodeType.Statement)
	];
	if (toks.expectPop!(TokenType.Else))
		ret.children ~= toks.read!(NodeType.Statement);
	return ret;
}

private Node readStaticIfStatement(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.StaticIf);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		toks.read!(NodeType.Expression),
		toks.read!(NodeType.Statement)
	];
	if (toks.expectPop!(TokenType.Else))
		ret.children ~= toks.read!(NodeType.Statement);
	return ret;
}

private Node readWhileStatement(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.While);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		toks.read!(NodeType.Expression),
		toks.read!(NodeType.Statement)
	];
	return ret;
}

private Node readDoWhileStatement(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.Do);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		toks.read!(NodeType.Statement),
		null // fill later with condition expression
	];
	toks.expectPopThrow!(TokenType.While);
	ret.children[$ - 1] = toks.read!(NodeType.Expression);
	toks.expectPopThrow!(TokenType.Semicolon); // expect a semicolon
	return ret;
}

private Node readForStatement(ref Tokenizer toks, NodeType){
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

private Node readStaticForStatement(ref Tokenizer toks, NodeType){
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

private Node readBreakStatement(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.Break);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	toks.expectPopThrow!(TokenType.Semicolon);
	return ret;
}

private Node readContinueStatement(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.Continue);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	toks.expectPopThrow!(TokenType.Semicolon);
	return ret;
}

private Node readBlock(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.CurlyOpen);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;

	while (!toks.expectPop!(TokenType.CurlyClose))
		ret.children ~= toks.read!(NodeType.Statement);
	return ret;
}

private Node readExprUnit(ref Tokenizer toks, NodeType){
	Node ret = new Node;
	ret.children = [
		toks.read!(
				NodeType.Identifier,
				NodeType.IntLiteral,
				NodeType.FloatLiteral,
				NodeType.StringLiteral,
				NodeType.CharLiteral,
				NodeType.NullLiteral,
				NodeType.BoolLiteral
				)
	];
	return ret;
}

private Node readIdentifier(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.Identifier);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}

private Node readIntLiteral(ref Tokenizer toks, NodeType){
	toks.expectThrow!(
		TokenType.LiteralInt,
		TokenType.LiteralBinary,
		TokenType.LiteralHexadecimal
	);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}

private Node readFloatLiteral(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.LiteralFloat);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}

private Node readStringLiteral(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.LiteralString);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}

private Node readCharLiteral(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.LiteralChar);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}

private Node readNullLiteral(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.Null);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}

private Node readBoolLiteral(ref Tokenizer toks, NodeType){
	toks.expectThrow!(
			TokenType.True,
			TokenType.False
	);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	return ret;
}

private Node readArgList(ref Tokenizer toks, NodeType){
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

private Node readTrait(ref Tokenizer toks, NodeType){
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
	if (toks.expect!(TokenType.BracketOpen, TokenType.IndexOpen)){
		Node ret = new Node;
		ret.token = toks.front;
		toks.popFront;
		// so we know which closing bracket to expect
		bool isIndexBracket = ret.token.type.get!(TokenType.IndexOpen);
		ret.children = [
			toks.read!(NodeType.Expression) // recurse, and forget precedence
		];
		// expect closing bracket
		if (isIndexBracket)
			toks.expectPopThrow!(TokenType.IndexClose);
		else
			toks.expectPopThrow!(TokenType.BracketClose);
		return ret;
	}

	const uint precedence = precedenceOf(context);
	auto branch = toks;
	Node expr;
	try{
		expr = branch.read!(PreOps!())(precedence);
		toks = branch;
	}catch (CompileError){}
	if (!expr)
		expr = toks.read!(NodeType.ExprUnit); // ok it's just an identifier

	// now keep feeding it into proceeding operators until precedence violated
	while (true){
		branch = toks;
		// maybe its a unary prefix operator?
		try{
			auto sub = branch.read!(PreOps!())(expr, precedence);
			expr = new Node;
			expr.children = [sub];
			toks = branch;
			continue;
		}catch (CompileError){}
		// maybe its a binary operator?
		try{
			auto sub = branch.read!(BinOps!())(expr, precedence);
			expr = new Node;
			expr.children = [sub];
			toks = branch;
			continue;
		}catch (CompileError){}
		break;
	}
	return expr;
}

private Node readLoadExpr(ref Tokenizer toks, NodeType){
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
	// if semicolon, eat it too
	toks.expectPop!(TokenType.Semicolon);
	return ret;
}

private Node readArrowFunc(ref Tokenizer toks, NodeType){
	toks.expectThrow!(TokenType.BracketOpen);
	Node ret = new Node;
	ret.children = [
		toks.read!(NodeType.ParamList)
	];
	// now the arrow
	toks.expectThrow!(TokenType.Arrow);
	ret.token = toks.front;
	toks.popFront;
	// now maybe a datatype?
	auto branch = toks;
	try{
		ret.children ~= branch.read!(NodeType.DataType);
		toks = branch;
	}catch (CompileError){}
	// and now the expression part, or a block
	branch = toks;
	try{
		ret.children ~= branch.read!(NodeType.Block);
		toks = branch;
	}catch (CompileError){
		ret.children ~= toks.read!(NodeType.Expression);
	}
	return ret;
}

private Node readOpCall(ref Tokenizer toks, Node a, NodeType context){
	toks.expectThrow!(TokenType.BracketOpen);
	Node ret = new Node;
	ret.token = toks.front;
	//toks.popFront;
	ret.children = [
		a,
		toks.read!(NodeType.ParamList)
	];
	return ret;
}

private Node readOpIndex(ref Tokenizer toks, Node a, NodeType context){
	toks.expectThrow!(TokenType.IndexOpen);
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		a,
		toks.read!(NodeType.Expression)
	];
	// the ending bracket should have been removed by reading NodeType.Expression
	// so just return
	return ret;
}

private Node readBinOp(ref Tokenizer toks, Node a, NodeType context){
	toks.expectThrow!(Hooks!(BinOps!())); // must be a binary operator
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		a,
		toks.read!(NodeType.Expression)
	];
	return ret;
}

private Node readPreOp(ref Tokenizer toks, NodeType context){
	toks.expectThrow!(Hooks!(PreOps!())); // must be a unary prefix operator
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		toks.read!(NodeType.Expression)
	];
	return ret;
}

private Node readPostOp(ref Tokenizer toks, Node a, NodeType context){
	toks.expectThrow!(Hooks!(PostOps!()));
	Node ret = new Node;
	ret.token = toks.front;
	toks.popFront;
	ret.children = [
		a
	];
	return ret;
}
