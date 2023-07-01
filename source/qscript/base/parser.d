module qscript.base.parser;

import qscript.base.tokens;

import std.traits;
import std.json;
import std.string;
import std.array;
import std.algorithm;
import std.uni : isWhite;
import std.stdio;
import std.conv : to;

/// an AST Node
// initialise with T = Token Type enum, M = Match Type enum
public class Node(T, M) if (is(T == enum) && is(M == enum)){
public:
	Token!T token;
	Node[] childNodes;
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

/// parses tokens using a M match type enum.
///
/// Returns: Node, or null
public Node!T match(T, M)(ref Token!T[] tokens) if (
		is(T == enum) && is(M == enum)){
	Node!T ret;

	return ret;
}

/// MatchExp[] associated with an enum M
private template Matchers(T, M) if (is(M == enum) && is(T == enum)){
	enum auto Matchers = readMatchers();
	private MatchExp!(T, M)[] readMatchers() pure {
		MatchExp!(T, M)[] ret;
		static foreach (sym; getSymbolsByUDA!(M, string)){
			static foreach (match; getUDAs!(sym, string)){
				ret ~= parseMatchExp!(T, M, sym, match);
				static if (hasUDA!(sym, KeyMatch))
					ret[$ - 1].isKey = true;
			}
		}
		return ret;
	}
}

/// MatchExp[] associated with a specific member in enum M
private template Matchers(T, M, M sym) if (is(M == enum) && is(T == enum)){
	enum auto Matchers = readMatchers();
	private MatchExp!(T, M)[] readMatchers() pure {
		MatchExp!(T, M)[] ret;
		static foreach (matcher; Matchers!(T, M)){
			static if (matcher.type == sym){
				ret ~= matcher;
				static if (hasUDA!(sym, KeyMatch))
					ret[$ - 1].isKey = true;
			}
		}
		return ret;
	}
}

/// Matching expression for a single match type
private struct MatchExp(T, M){
	struct Unit{
		bool terminal = false;
		bool loop = false;
		bool or = false;
		union{
			T tok;
			M mat;
			Unit[] units;
		}

		this(M mat){
			this.terminal = this.loop = this.or = false;
			this.mat = mat;
		}
		this(T tok){
			this.terminal = this.loop = this.or = false;
			this.tok = tok;
		}
		this(Unit[] units, bool isLoop = true){
			this.loop = isLoop;
			this.or = !isLoop;
			this.units = units;
		}
		string toString() const {
			return isTok ? tok.to!string : '/' ~ mat.to!string;
		}
	}

	Unit[] units;
	M type;

	this(Unit[] units, M type){
		this.units = units;
		this.type = type;
	}

	string toString() const {
		string ret = (isKey ? "#/" : "/") ~ type.to!string ~ " ->";
		foreach (i, unit; units)
			ret ~= " " ~ unit.toString;
		return ret;
	}
}

/// parses string into MatchExp[]
private MatchExp!(T, M) parseMatchExp(T, M, M type, string str)(){
	struct Unit{
		string name;
		bool terminal = true;
		bool ignore = false;
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
	alias Unit = MatchExp!(T, M).Unit;

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
	return MatchExp!(T, M)(units, type, root);
}
