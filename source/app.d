module app;

import std.stdio,
			 std.file,
			 std.algorithm.iteration;

import qscript.ast,
			 qscript.tokens,
			 qscript.compiler;

version(unittest){}else
void main(){
	Token[] tokens;
	write("tokens: ");

	// tokenize file
	foreach (token; Tokenizer(cast(string)read("sample.txt")).filter!(
				a => !a.type.get!(TokenType.Whitespace) &&
				!a.type.get!(TokenType.Comment) &&
				!a.type.get!(TokenType.CommentMultiline)))
		tokens ~= token;

	Node rootNode;
	uint i;
	rootNode = read(tokens, i);
	if (rootNode)
		writeln(rootNode.toJSON.toPrettyString);
	else
		writeln("root is null");
}
