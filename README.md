QScript is a fast, and simple scripting language.<br>
QScript has been designed and tested on only Linux, and I have no plans to add support for Windows.
<br>
<h3>How to build</h3><br>
<ol>
	<li>Download/clone this repo</li>
	<li><code>cd</code> into %CLONE DIR%/qscript</li>
	<li>Build using:<code>dmd -m32 -shared -fPIC "lists.d" "main.d" "misc.d" "qcompiler.d" "qscript.d"</code></li>
</ol><br>
<h3>Usage</h3>
The file <code>qloader.d</code> and <code>main.d</code> in <code>/test</code> demonstrate how to use QScript.
