module app;

import std.stdio,
			 std.file;

import qscript.ast,
			 qscript.tokens,
			 qscript.compiler;

version(unittest){}else
void main(){
	Tokenizer tokMaker = new Tokenizer(cast(string)read("sample"));
	Token[] tokens;
	write("tokens: ");
	while (!tokMaker.end){
		try{
			tokens ~= tokMaker.next;
		}catch (Exception e){
			writeln(tokens);
			writefln!"\n%s"(e.msg);
			return;
		}
	}
	whitespaceRemove(tokens);
	writeln(tokens);

	Node rootNode;
	rootNode = read(tokens);
	writeln(rootNode.toJSON.toPrettyString);
}
