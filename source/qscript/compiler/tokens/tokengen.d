module qscript.compiler.tokens.tokengen;

import utils.misc;
import utils.ds;

import std.functional : toDelegate;
import std.algorithm : canFind;
import std.traits : EnumMembers;

debug import std.stdio;

/// A token
public struct Token(T) if (is (T == enum)){
	/// line number and column number
	uint lineno, colno;
	/// token type(s)
	Flags!T type;
	/// token
	string token;
	alias token this;
	/// [line number, colno]
	@property uint[2] where() const{
		return [lineno, colno];
	}
	/// constructor
	this(uint lineno, uint colno, Flags!T type, string token){
		this.lineno = lineno;
		this.colno = colno;
		this.type = type;
		this.token = token;
	}
	/// ditto
	this(uint lineno, uint colno, T type, string token){
		this.lineno = lineno;
		this.colno = colno;
		this.type.set(type);
		this.token = token;
	}
	/// ditto
	this(Flags!T type, string token){
		this.type = type;
		this.token = token;
	}
	/// ditto
	this(T type, string token){
		this.type.set(type);
		this.token = token;
	}
	/// == operator
	bool opBinary(string op : "==")(const Token rhs) const{
		return type == rhs.type && token == rhs.token;
	}
	/// ditto
	bool opBinary(string op : "==")(const T rhs) const{
		return type.get(rhs);
	}
	/// ditto
	bool opBinary(string op : "==")(const string rhs) const{
		return token == rhs;
	}
	/// != operator
	bool opBinary(string op : "!=")(const Token rhs) const{
		return type != rhs.type || token != rhs.token;
	}
	/// ditto
	bool opBinary(string op : "!=")(const T rhs) const{
		return !type.get(rhs);
	}
	/// ditto
	bool opBinary(string op : "!=")(const string rhs) const{
		return token != rhs;
	}
}

/// Matching method
public struct TokenMatcher(T) if (is(T == enum)){
	/// token type for this match
	T type;
	/// whether to use exact match, will call delegate otherwise
	bool isExactMatch;
	union{
		/// exact matching string
		string exactMatch;
		/// delegate for matching. This should return the first number of chars
		/// that match. 0 if none
		uint delegate(string) funcMatch;
	}
	/// pre-requisite. Only attempt this match these matched.
	/// if this exists, it will only try to match with what has already been
	/// token-ified
	Flags!T prereq;
	/// constructor
	this (T type, string exactMatch){
		isExactMatch = true;
		this.type = type;
		this.exactMatch = exactMatch;
	}
	/// ditto
	this (T type, uint delegate(string) funcMatch){
		isExactMatch = false;
		this.type = type;
		this.funcMatch = funcMatch;
	}
	/// attempt to match
	///
	/// Returns: number of characters matching, starting from index 0
	uint match(string s){
		if (prereq.count)
			return 0; // cannot match, this has not been token-ified
		if (isExactMatch){
			if (s.length < exactMatch.length)
				return 0;
			return cast(uint)
				(exactMatch.length * (s[0 .. exactMatch.length] == exactMatch));
		}
		return funcMatch(s);
	}
	/// ditto
	uint match(Token!T t){
		foreach (tp; EnumMembers!T){
			if (!prereq[tp])
				continue;
			if (t.type.get(tp)){
				if (isExactMatch)
					return cast(uint)
						((t.token == exactMatch) * t.token.length);
				return cast(uint)
					((funcMatch(t.token) == t.token.length) * t.token.length);
			}
		}
		return 0;
	}
}

/// a fancy string exploder
///
/// this should probably be moved to my utils package, but it sits here for now
public class TokenGen(T) if (is (T == enum)){
private:
	/// token matchers
	TokenMatcher!T[] _matchers;

	/// currently open source code
	string _source;
	/// the tokens
	Token!T[] _tokens;
	/// line number and column number of error(s)
	uint[2][] _errors;

	/// Returns: first matching token from a string. type will be `uint.max` in case of no match
	Token!T _getToken(string str){
		Token!T r;
		uint maxLen = 0;
		uint maxInd;
		foreach (i, matcher; _matchers){
			immutable newLen = matcher.match(str);
			if (newLen > maxLen){
				maxLen = newLen;
				maxInd = cast(uint)i;
			}
		}
		if (!maxLen)
			return r;
		r.type += _matchers[maxInd].type;
		r.token = str[0 .. maxLen];
		bool modified = false;
		// now add those types that match this str[0 .. maxLen] as well
		do{
			foreach (i, matcher; _matchers){
				if (r.type & matcher.type)
					continue;
				modified = matcher.match(r) == r.token.length;
				if (modified){
					r.type += matcher.type;
					break;
				}
			}
		}while (modified);
		return r;
	}

public:
	this(){
	}
	~this(){
	}

	/// the source code
	@property string source(){
		return _source;
	}
	/// ditto
	@property string source(string newVal){
		return _source = newVal;
	}

	/// Returns: line number and column number where unidentified token found
	@property uint[2][] errors(){
		uint[2][] r = _errors;
		_errors.length = 0;
		return r;
	}
	/// Returns: true if there are any errors
	@property bool error(){
		return _errors.length > 0;
	}

	/// adds a token type. Exact matches are checked for first
	void addTokenType(T type, string match,
			Flags!T prereq = Flags!T.init){
		TokenMatcher!T matcher = TokenMatcher!T(type, match);
		matcher.prereq = prereq;
		_matchers ~= matcher;
	}

	/// adds a token type. Token types added this way are checked for after no
	/// exact match is found
	///
	/// The `matchFinder` function should return the number of characters that
	/// match from start
	void addTokenType(T type, uint delegate (string) matchFinder,
			Flags!T prereq = Flags!T.init){
		TokenMatcher!T matcher = TokenMatcher!T(type, matchFinder);
		matcher.prereq = prereq;
		_matchers ~= matcher;
	}

	/// ditto
	void addTokenType(T type, uint function(string) matchFinder,
			Flags!T prereq = Flags!T.init){
		this.addTokenType(type, toDelegate(matchFinder), prereq);
	}

	/// Returns: tokens
	@property Token!T[] tokens(){
		return _tokens;
	}
	/// clears tokens
	void clear(){
		_tokens.length = 0;
	}

	/// reads source into tokens. Any existing tokens will be cleared.
	///
	/// This will try to match regex expressions, and use the first one that matches.
	///
	/// Returns: true if done without errors, false if there was error
	bool readTokens(){
		this.clear();
		uint lineno;
		uint lastNewLineIndex;
		for (uint i = 0; i < _source.length; ){
			Token!T token = _getToken(_source[i .. $]);
			token.lineno = lineno + 1;
			token.colno = i - lastNewLineIndex;
			if (!token){
				_errors ~= [token.lineno, token.colno];
				return false;
			}
			_tokens ~= token;
			foreach (j, c; _source[i .. i + token.length]){
				if (c == '\n'){
					lastNewLineIndex = cast(uint)j + i;
					lineno ++;
				}
			}
			i += token.length;
		}
		return true;
	}

	/// Removes tokens that match type
	///
	/// Returns: number of tokens removed
	uint removeByType(T type){
		uint count, i;
		while (i + count < _tokens.length){
			if (_tokens[i + count].type[type]){
				count ++;
			}else{
				_tokens[i] = _tokens[i + count];
				i ++;
			}
		}
		_tokens.length -= count;
		return count;
	}

	/// ditto
	uint removeByType(Flags!T types){
		uint count, i;
		while (i + count < _tokens.length){
			if (_tokens[i + count].type & types){
				count ++;
			}else{
				_tokens[i] = _tokens[i+count];
				i ++;
			}
		}
		_tokens.length -= count;
		return count;
	}

	/// Replace tokens type by another type
	///
	/// Returns: number of tokens replaced
	uint replaceByType(T type, T typeTo){
		uint count = 0;
		foreach (i, tok; _tokens){
			if (tok.type[type]){
				count ++;
				_tokens[i].type -= type;
				_tokens[i].type += typeTo;
			}
		}
		return count;
	}

	/// Replace tokens type by another type
	///
	/// Returns: number of tokens replaced
	uint replaceByType(T type, T typeTo, string token){
		uint count = 0;
		foreach (i, tok; _tokens){
			if (tok.type[type]){
				count ++;
				_tokens[i].type -= type;
				_tokens[i].type += typeTo;
				_tokens[i].token = token;
			}
		}
		return count;
	}
}

///
unittest{
	enum Type{
		CommentLine,
		CommentMultiLine,
		Whitespace,
		String,
		Keyword
	}
	TokenGen!Type tkGen = new TokenGen!Type();
	/// single line comment
	tkGen.addTokenType(Type.CommentLine, function (string str){
		if (!str.length || str[0] != '#')
			return cast(uint)0;
		foreach (index, ch; str[1 .. $]){
			if (ch == '\n')
				return cast(uint)index + 1;
		}
		return cast(uint)(str.length);
	});

	// whitespace
	tkGen.addTokenType(Type.Whitespace, function (string str){
		foreach (index, ch; str){
			if (ch != ' ' && ch != '\t' && ch != '\n')
				return cast(uint)index;
		}
		return cast(uint)(str.length);
	});

	// multi line comment
	tkGen.addTokenType(Type.CommentMultiLine, function (string str){
		if (str.length < 2 || str[0 .. 2] != "/*")
			return 0;
		for (uint i = 4; i <= str.length; i ++){
			if (str[i - 2 .. i] == "*/")
				return i;
		}
		return 0;
	});

	// string
	tkGen.addTokenType(Type.String, function (string str){
		if (str.length < 2 || str[0] != '"')
			return 0;
		for (uint i = 1; i < str.length; i ++){
			if (str[i] == '\\'){
				i ++;
				continue;
			}
			if (str[i] == '"')
				return i + 1;
		}
		return 0;
	});

	// keyword
	tkGen.addTokenType(Type.Keyword, "keyword");
	tkGen.source =
"keyword # a single line coment fgdger4543terg h \"fsdfdsf\" \\\\gsdgfdv
\t\t\"tabs > spaces\"/* multi
line
comment*/
 \"another string\"";
	assert(tkGen.readTokens());
	Token!Type[] tokens;
	tokens = tkGen.tokens;
	string[] expectedTokenStrs =  [
		"keyword"," ",
		"# a single line coment fgdger4543terg h \"fsdfdsf\" \\\\gsdgfdv",
		"\n\t\t","\"tabs > spaces\"","/* multi\nline\ncomment*/","\n ",
		"\"another string\""
	];
	Type[] expectedTokenTypes = [
		Type.Keyword, Type.Whitespace,
		Type.CommentLine,
		Type.Whitespace, Type.String, Type.CommentMultiLine, Type.Whitespace,
		Type.String
		];
	foreach (i, token; tokens){
		assert (token.token == expectedTokenStrs[i]);
		assert (token.type[expectedTokenTypes[i]]);
	}
}
