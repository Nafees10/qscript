module qscript.compiler.tokengen;

import utils.misc;
import utils.ds;

debug{import std.stdio;}

/// A token
package struct Token{
	/// line number and column number
	uint lineno, colno;
	/// token type.
	/// 
	/// `uint.max` is reserved for `invalid/unknown type`
	uint type = uint.max;
	/// token
	string token;
	alias token this;
	/// constructor
	this(uint lineno, uint colno, uint type, string token){
		this.lineno = lineno;
		this.colno = colno;
		this.type = type;
		this.token = token;
	}
	/// ditto
	this(uint type, string token){
		this.type = type;
		this.token = token;
	}
}

/// a fancy string exploder
///
/// this should probably be moved to my utils package, but it sits here for now
package class TokenGen{
private:
	/// For storing how to match against a token type
	struct TokenTypeMatch{
		enum Type : ubyte{
			ExactMatch,
			MatchFinderFunction,
		}
		private ubyte _type;
		private union{
			string _exactMatch;
			uint function (string) _findMatch;
		}
		/// constructor
		this (string match){
			_type = Type.ExactMatch;
			this._exactMatch = match;
		}
		/// constructor
		/// 
		/// the `matchFinder` function returns how many characters from start of string match as token, 0 if no match.
		this (uint function (string) matchFinder){
			_type = Type.MatchFinderFunction;
			this._findMatch = matchFinder;
		}
		/// tries to match with this type
		/// 
		/// Returns: number of initial characters that match, 0 if none, obviously
		uint matches(string s){
			if (_type == Type.ExactMatch)
				return (s.length >= _exactMatch.length && s[0 .. _exactMatch.length] == _exactMatch) * cast(uint)_exactMatch.length;
			return _findMatch(s);
		}
	}
	/// token matchers
	TokenTypeMatch[uint] _matchers;
	
	/// currently open source code
	string _source;
	/// the tokens
	Token[] _tokens;
	/// line number and column number of error(s)
	uint[2][] _errors;

	/// Returns: first matching token from a string. type will be `uint.max` in case of no match
	Token getToken(string str){
		Token r;
		uint maxLen = 0;
		uint maxType;
		foreach (type, matcher; _matchers){
			const uint len = matcher.matches(str);
			if (len <= maxLen)
				continue;
			maxLen = len;
			maxType = type;
		}
		if (maxLen){
			r.type = maxType;
			r.token = str[0 .. maxLen];
		}
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
	/// adds a token type
	/// 
	/// Returns: true if added
	bool addTokenType(uint type, string match, bool overwrite = false){
		if (type !in _matchers || overwrite){
			_matchers[type] = TokenTypeMatch(match);
			return true;
		}
		return false;
	}
	/// adds a token type
	/// 
	/// The `matchFinder` function should return the number of characters that match from start
	/// 
	/// Returns: true if added
	bool addTokenType(uint type, uint function (string) matchFinder, bool overwrite = false){
		if (type !in _matchers || overwrite){
			_matchers[type] = TokenTypeMatch(matchFinder);
			return true;
		}
		return false;
	}
	/// adds a token type, selecting a token type for it automatically
	/// 
	/// Returns: the selected token type
	uint addTokenType(string match){
		static uint freeIndex = uint.max - 1;
		while (freeIndex in _matchers && freeIndex != uint.max){
			freeIndex --;
		}
		if (freeIndex == uint.max || freeIndex in _matchers)
			return uint.max;
		addTokenType(freeIndex, match);
		return freeIndex;
	}
	/// Returns: tokens
	@property Token[] tokens(){
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
			Token token = getToken(_source[i .. $]);
			token.lineno = lineno + 1;
			token.colno = i - lastNewLineIndex;
			if (token.type == uint.max || !token.length){
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
	uint removeByType(uint type){
		uint count, i;
		while (i + count < _tokens.length){
			if (_tokens[i+count].type == type)
				count ++;
			else{
				_tokens[i] = _tokens[i+count];
				i ++;
			}
		}
		_tokens.length -= count;
		return count;
	}
	/// ditto
	uint removeByType(uint[] types){
		uint count, i;
		while (i + count < _tokens.length){
			if (types.hasElement(_tokens[i+count].type))
				count ++;
			else{
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
	uint replaceByType(uint type, uint typeTo){
		uint count = 0;
		foreach (i, tok; _tokens){
			if (tok.type == type){
				count ++;
				_tokens[i].type = typeTo;
			}
		}
		return count;
	}
	/// Replace tokens type by another type
	/// 
	/// Returns: number of tokens replaced
	uint replaceByType(uint type, uint typeTo, string token){
		uint count = 0;
		foreach (i, tok; _tokens){
			if (tok.type == type){
				count ++;
				_tokens[i].type = typeTo;
				_tokens[i].token = token;
			}
		}
		return count;
	}
}
///
unittest{
	TokenGen tkGen = new TokenGen();
	/// single line comment
	tkGen.addTokenType(0, function (string str){
		if (!str.length || str[0] != '#')
			return cast(uint)0;
		foreach (index, ch; str[1 .. $]){
			if (ch == '\n')
				return cast(uint)index + 1;
		}
		return cast(uint)(str.length);
	});
	// whitespace
	tkGen.addTokenType(1, function (string str){
		foreach (index, ch; str){
			if (ch != ' ' && ch != '\t' && ch != '\n')
				return cast(uint)index;
		}
		return cast(uint)(str.length);
	});
	// multi line comment
	tkGen.addTokenType(2, function (string str){
		if (str.length < 2 || str[0 .. 2] != "/*")
			return 0;
		for (uint i = 4; i <= str.length; i ++){
			if (str[i - 2 .. i] == "*/")
				return i;
		}
		return 0;
	});
	// string
	tkGen.addTokenType(3, function (string str){
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
	tkGen.addTokenType(4, "keyword");
	tkGen.source = 
"keyword # a single line coment fgdger4543terg h \"fsdfdsf\" \\\\gsdgfdv 
\t\t\"tabs > spaces\"/* multi
line
comment*/   
 \"another string\"";
	assert(tkGen.readTokens());
	Token[] tokens;
	string[] tkStrs;
	uint[] tkTypes;
	tokens = tkGen.tokens;
	tkTypes.length = tokens.length;
	tkStrs.length = tokens.length;
	foreach (i; 0 .. tkStrs.length){
		tkStrs[i] = tokens[i].token;
		tkTypes[i] = tokens[i].type;
	}
	assert(tkStrs == ["keyword"," ","# a single line coment fgdger4543terg h \"fsdfdsf\" \\\\gsdgfdv ",
		"\n\t\t","\"tabs > spaces\"","/* multi\nline\ncomment*/","   \n ", "\"another string\""]);
	assert(tkTypes == [4, 1, 0, 1, 3, 2, 1, 3]);
	tkGen.removeByType(1); // no whitespace
	tokens = tkGen.tokens;
	tkTypes.length = tokens.length;
	foreach (i; 0 .. tkTypes.length)
		tkTypes[i] = tokens[i].type;
	assert(tkTypes == [4, 0, 3, 2, 3]);
	tkGen.removeByType([0,2]); // no comments, or multi line comments
	tokens = tkGen.tokens;
	tkTypes.length = tokens.length;
	foreach (i; 0 .. tkTypes.length)
		tkTypes[i] = tokens[i].type;
	assert(tkTypes == [4, 3,3]);
	.destroy(tkGen);
}