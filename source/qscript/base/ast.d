module qscript.base.ast;

import qscript.base.tokens;

import std.traits;
import std.json;
import std.string;
import std.array;
import std.uni : isWhite;
import std.stdio;
import std.conv : to;

/// an AST Node
// initialise with T = Token Type enum, M = Match Type enum
public class ASTNode(T, M) if (is(T == enum) && is(M == enum)){
public:
	Token!T token;
	ASTNode[] childNodes;
	M match;

	JSONValue toJSON(){
		JSONValue ret;
		ret["token"] = token.token;
		ret["match"] = match.to!string;
		string type;
		foreach (member; EnumMembers!T){
			if (!token.type[member])
				continue;
			type ~= member.to!string ~ ", ";
		}
		if (type.length)
			ret["type"] = type.chomp(", ");
		JSONValue[] sub;
		foreach (child; childNodes)
			sub ~= child.toJSON;
		if (sub.length)
			ret["childNodes"] = sub;
		return ret;
	}
}

/// Tag a match type as being a key match (not to backtrack before it)
/// this should usually be terminators, like semicolon, comma, bracket ends etc
enum KeyMatch;

/// parses tokens using a M match type enum.
///
/// Returns: ASTNode, or null
public ASTNode!T match(T, M)(ref Token!T[] tokens) if (
		is(T == enum) && is(M == enum)){
	ASTNode!T ret;

	return ret;
}

/// Tries to match tokens with a specific matching expression
///
/// Returns: ASTNode if done, false if not
public ASTNode!T match(T, M, alias matcher)(ref Token!T[] tokens)
		if (is(T == enum) && is(M == enum) && typeof(matcher) == ASTMatch!(T, M)){
	return null;
}

/// ASTMatch[] associated with an enum M TODO make it private
public template Matchers(T, M) if (is(M == enum) && is(T == enum)){
	enum auto Matchers = readMatchers();
	private ASTMatch!(T, M)[] readMatchers() pure {
		ASTMatch!(T, M)[] ret;
		static foreach (sym; getSymbolsByUDA!(M, string)){
			static foreach (match; getUDAs!(sym, string)){
				ret ~= parseASTMatch!(T, M, sym, match);
				static if (hasUDA!(sym, KeyMatch))
					ret[$ - 1].isKey = true;
			}
		}
		return ret;
	}
}

/// Matching expression for a single match type
private struct ASTMatch(T, M){
	struct Unit{
		bool isTok = false;
		union{
			T tok;
			M mat;
		}

		this(M mat){
			this.isTok = false;
			this.mat = mat;
		}
		this(T tok){
			this.isTok = true;
			this.tok = tok;
		}

		string toString() const {
			return isTok
				? tok.to!string
				: '/' ~ mat.to!string;
		}
	}

	uint rootInd;
	Unit[] units;
	M type;
	bool isKey = false;

	this(Unit[] units, M type, uint rootInd = 0, bool isKey = false){
		this.units = units;
		this.type = type;
		this.rootInd = rootInd;
		this.isKey = isKey;
	}

	string toString() const {
		string ret = (isKey ? "#/" : "/") ~ type.to!string ~ " - > ";
		if (units.length)
			ret ~= (rootInd == 0 ? "-" : null) ~ units[0].toString;
		foreach (i, unit; units[1 .. $])
			ret ~= (rootInd == i + 1 ? " -" : " ") ~ unit.toString();
		return ret;
	}
}

/// parses string into ASTMatch[]
private ASTMatch!(T, M) parseASTMatch(T, M, M type, string str)(){
	struct Matcher{
		string name;
		bool isMatched = false;
		bool isRoot = false;
	}
	static Matcher parseIndividual(string str){
		Matcher ret;
		if (str.length && str[0] == '-'){
			ret.isRoot = true;
			str = str[1 .. $];
		}
		if (str.length && str[0] == '/'){
			ret.isMatched = true;
			str = str[1 .. $];
		}
		ret.name = str;
		return ret;
	}
	alias Unit = ASTMatch!(T, M).Unit;

	Unit[] units;
	uint root;
	static foreach (i, str; str.split!isWhite){{
		enum auto matcher = parseIndividual(str);
		static if (matcher.isRoot)
			root = i;
		static if (matcher.isMatched){
			static assert(__traits(hasMember, M, matcher.name),
					matcher.name ~ " not found in " ~ M.stringof);
			units ~= Unit(__traits(getMember, M, matcher.name));
		}else{
			static assert(__traits(hasMember, T, matcher.name),
					matcher.name ~ " not found in " ~ T.stringof);
			units ~= Unit(__traits(getMember, T, matcher.name));
		}
	}}
	return ASTMatch!(T, M)(units, type, root);
}
