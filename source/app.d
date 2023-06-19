module app;

import std.stdio,
			 std.file,
			 std.algorithm.iteration;

import utils.ds;

import qscript.ast,
			 qscript.tokens,
			 qscript.compiler;

version(unittest){}else
void main(){
	// tokenize file
	Flags!TokenType ignore;
	ignore |= TokenType.Whitespace;
	ignore |= TokenType.Comment;
	ignore |= TokenType.CommentMultiline;
	auto range = Tokenizer(cast(string)read("sample"), ignore);

	foreach (token; range)
		writeln(token);

	Node rootNode;
	rootNode = read(range);
	if (rootNode)
		writeln(rootNode.toJSON.toPrettyString);
	else
		writeln("root is null");
}
