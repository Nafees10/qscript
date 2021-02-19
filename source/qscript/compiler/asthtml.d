/++
Used for debugging compiler
Generates a HTML page that represents a readable representation of AST nodes
Only available in `qsCompiler` configuration (`dub -c=qsCompiler`)
+/
module qscript.compiler.asthtml;

import qscript.compiler.ast;

import utils.misc;
import utils.lists;

import std.conv : to;

version (compiler){
	/// stores the style sheet for the page
	private enum STYLESHEET = "<style>*{font-family:monospace;border:1px solid #cccccc;border-collapse:collapse;}</style>";
	/// some commonly used html codes
	private enum HTML : string{
		TABLE_HEADING_START = "<table><tr><th>",
		TABLE_HEADING_END = "</th></tr>",
		TABLE_END = "</table>",
		ROW_START = "<tr>",
		ROW_END = "</tr>",
		DATA_START = "<td>",
		DATA_END = "</td>",
		BOLD_START = "<b>",
		BOLD_END = "</b>",
	}
	/// to generate an html page representing AST nodes
	class ASTHtml{
	private:
		/// stores the html page while it's being generated
		List!string _html;
		/// replaces non alpabet, non numeric chars with html codes
		static string htmlEncode(string str){
			if (str.isAlphabet || str.isNum)
				return str;
			char[] r;
			foreach (c; str){
				if ((cast(string)[c]).isAlphabet || (cast(string)[c]).isNum)
					r ~= c;
				else
					r ~= "&#"~((cast(int)c).to!string)~';';
			}
			return cast(string)r;
		}
		/// appends a new table with a heading
		void tableNew(string heading, bool asRow = false){
			if (asRow)
				_html.append(HTML.ROW_START);
			_html.append(HTML.TABLE_HEADING_START~htmlEncode(heading)~HTML.TABLE_HEADING_END);
			if (asRow)
				_html.append(HTML.ROW_END);
		}
		/// appends a table end tag
		void tableEnd(){
			_html.append(HTML.TABLE_END);
		}
		/// appends a row to table
		void tableRow(string[] values, bool bold=false){
			_html.append(HTML.ROW_START);
			if (bold)
				_html.append(HTML.BOLD_START);
			foreach (val; values)
				_html.append(HTML.DATA_START~htmlEncode(val)~HTML.DATA_END);
			if (bold)
				_html.append(HTML.BOLD_END);
			_html.append(HTML.ROW_END);
		}

		/// generate html for EnumNodes
		void generateHtml(EnumNode[] nodes){
			tableNew("enums");
			tableRow(["id", "name", "visibility", "members"], true);
			foreach (i, node; nodes)
				tableRow([i.to!string, node.name, node.visibility.to!string, node.members.to!string]);
			tableEnd();
		}
		/// generates html for StructNodes
		void generateHtml(StructNode[] nodes){
			tableNew("structs");
			foreach (i, node; nodes){
				tableNew(node.name, true);
				tableRow(["id", i.to!string]);
				tableRow(["visibility", node.visibility.to!string]);
				tableRow(["containsRef", node.containsRef.to!string]);
				tableRow(["members:"], true);
				foreach (memberId; 0 .. node.membersName.length)
					tableRow([node.membersDataType[memberId].name, node.membersName[i]]);
				tableEnd();
			}
			tableEnd();
		}
		/// generates html for global variables
		void generateHtml(VarDeclareNode[] nodes){
			tableNew("global variables");
			foreach (i, node; nodes){

			}
			tableEnd();
		}
		/// generates html for VarDeclareNode
		void generateHtml(VarDeclareNode node, bool asRow = false){
			if (asRow){
				// id, data type, name, value
				//foreach (node.) TODO
			}
		}
	public:
		/// constructor
		this(){
			_html = new List!string;
		}
		~this(){
			.destroy(_html);
		}
		/// generates html page for ScriptNode
		void generateHtml(ScriptNode node){
			// throw stylesheet first
			_html.append(STYLESHEET);
			if (node.imports.length){
				tableNew("imports");
				foreach (i, importName; node.imports)
					tableRow([to!string(i), importName]);
				tableEnd();
			}
			if (node.enums.length){
				generateHtml(node.enums);
			}
			if (node.structs.length){
				tableNew("structs");
				/*foreach (structNode; node.structs)
					this.generateHtml(structNode);
				tableEnd();
			}
			if (node.variables.length){
				tableNew("global variables");
				foreach(var; node.variables)
					generateHtml(var);
				tableEnd();
			}
			if (node.functions.length){
				tableNew("functions");
				foreach (func; node.functions)
					generateHtml(func);
				tableEnd();*/
			}
		}
		/// Returns: generated page as a string[] where each string is a separate line. does **not** include endl characters
		@property string[] html(){
			return _html.toArray;
		}
	}
}
