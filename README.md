

<h2><a class="toc-backref" id="cdotddotedotcdotldotcolon-commonly-desired-edge-case-library" href="#cdotddotedotcdotldotcolon-commonly-desired-edge-case-library">C.D.E.C.L.: Commonly Desired Edge Case Library</a></h2><p>See full docs at <a class="reference external" href="https://elcritch.github.io/cdecl/">docs</a> or source on github at <a class="reference external" href="https://github.com/elcritch/cdecl">elcritch/cdecl</a>.</p>
<p>Small library for macros to handle various edge cases for Nim syntax. These are mostly edge case syntax handlers or tricky C Macro interfacings. The goal is to implement them as generically and well unit tested as possible.</p>
<p>Current macros includes:</p>
<ul class="simple"><li><a class="reference external" href="https://elcritch.github.io/cdecl/cdecl/cdecls.html">cdecls</a>: Macros to help using C macros that declare variables<ul class="simple"><li><tt class="docutils literal"><span class="pre"><span class="Identifier">cdeclmacro</span></span></tt></li>
</ul>
</li>
<li><a class="reference external" href="https://elcritch.github.io/cdecl/cdecl/applies.html">applies</a>: Macros that unpack arguments from various forms and calls functions<ul class="simple"><li><tt class="docutils literal"><span class="pre"><span class="Identifier">unpackObjectArgs</span></span></tt>: macro to <em>splat</em> an object to position arguments</li>
<li><tt class="docutils literal"><span class="pre"><span class="Identifier">unpackObjectArgFields</span></span></tt>: macro to <em>splat</em> an object to keyword arguments</li>
<li><tt class="docutils literal"><span class="pre"><span class="Identifier">unpackLabelsAsArgs</span></span></tt>: turn <em>labels</em> to named arguments</li>
</ul>
</li>
<li><a class="reference external" href="https://elcritch.github.io/cdecl/cdecl/bitfields.html">bitfields</a>: Macros for making bitfield style accessor<ul class="simple"><li><tt class="docutils literal"><span class="pre"><span class="Identifier">bitfields</span></span></tt>: create <em>bitfield</em> accessors for hardware registers using any int type</li>
</ul>
</li>
</ul>
<p>You can see various usages in the <a class="reference external" href="https://github.com/elcritch/cdecl/tree/main/tests">tests </a> folder.</p>

<h2><a class="toc-backref" id="macros" href="#macros">Macros</a></h2>
<h3><a class="toc-backref" id="macros-nimunpackobjectargs" href="#macros-nimunpackobjectargs"><tt class="docutils literal"><span class="pre"><span class="Identifier">unpackObjectArgs</span></span></tt></a></h3><p>Helper to apply all fields of an object as named paramters.</p>
<p><pre class="listing"><span class="Keyword">type</span> <span class="Identifier">AddObj</span> <span class="Operator">=</span> <span class="Keyword">object</span>
  <span class="Identifier">a</span><span class="Operator">*:</span> <span class="Identifier">int</span>
  <span class="Identifier">b</span><span class="Operator">*:</span> <span class="Identifier">int</span>

<span class="Keyword">proc</span> <span class="Identifier">add</span><span class="Punctuation">(</span><span class="Identifier">a</span><span class="Punctuation">,</span> <span class="Identifier">b</span><span class="Punctuation">:</span> <span class="Identifier">int</span><span class="Punctuation">)</span><span class="Punctuation">:</span> <span class="Identifier">int</span> <span class="Operator">=</span>
    <span class="Identifier">result</span> <span class="Operator">=</span> <span class="Identifier">a</span> <span class="Operator">+</span> <span class="Identifier">b</span>

<span class="Keyword">let</span> <span class="Identifier">args</span> <span class="Operator">=</span> <span class="Identifier">AddObj</span><span class="Punctuation">(</span><span class="Identifier">a</span><span class="Punctuation">:</span> <span class="DecNumber">1</span><span class="Punctuation">,</span> <span class="Identifier">b</span><span class="Punctuation">:</span> <span class="DecNumber">2</span><span class="Punctuation">)</span>
<span class="Keyword">let</span> <span class="Identifier">res</span> <span class="Operator">=</span> <span class="Identifier">unpackObjectArgs</span><span class="Punctuation">(</span><span class="Identifier">add</span><span class="Punctuation">,</span> <span class="Identifier">args</span><span class="Punctuation">)</span>
<span class="Identifier">assert</span> <span class="Identifier">res</span> <span class="Operator">==</span> <span class="DecNumber">3</span>
</pre></p>

<h3><a class="toc-backref" id="macros-nimunpacklabelsasargs" href="#macros-nimunpacklabelsasargs"><tt class="docutils literal"><span class="pre"><span class="Identifier">unpackLabelsAsArgs</span></span></tt></a></h3><p>Helper to transform <tt class="docutils literal"><span class="pre"><span class="Identifier">labels</span></span></tt> as named arguments to a function. <em>Labels</em> are regular Nim syntax for calling procs but are transformed to parameter names:</p>
<p><pre class="listing"><span class="Keyword">proc</span> <span class="Identifier">foo</span><span class="Punctuation">(</span><span class="Identifier">name</span><span class="Punctuation">:</span> <span class="Identifier">string</span> <span class="Operator">=</span> <span class="StringLit">&quot;buzz&quot;</span><span class="Punctuation">,</span> <span class="Identifier">a</span><span class="Punctuation">,</span> <span class="Identifier">b</span><span class="Punctuation">:</span> <span class="Identifier">int</span><span class="Punctuation">)</span> <span class="Operator">=</span>
  <span class="Identifier">echo</span> <span class="Identifier">name</span><span class="Punctuation">,</span> <span class="StringLit">&quot;:&quot;</span><span class="Punctuation">,</span> <span class="StringLit">&quot; a: &quot;</span><span class="Punctuation">,</span> <span class="Operator">$</span><span class="Identifier">a</span><span class="Punctuation">,</span> <span class="StringLit">&quot; b: &quot;</span><span class="Punctuation">,</span> <span class="Operator">$</span><span class="Identifier">b</span>

<span class="Keyword">template</span> <span class="Identifier">Foo</span><span class="Punctuation">(</span><span class="Identifier">blk</span><span class="Punctuation">:</span> <span class="Identifier">varargs</span><span class="Punctuation">[</span><span class="Identifier">untyped</span><span class="Punctuation">]</span><span class="Punctuation">)</span> <span class="Operator">=</span>
  <span class="Comment">## create a new template to act YAML like API</span>
  <span class="Identifier">unpackLabelsAsArgs</span><span class="Punctuation">(</span><span class="Identifier">foo</span><span class="Punctuation">,</span> <span class="Identifier">blk</span><span class="Punctuation">)</span>

<span class="Identifier">Foo</span><span class="Punctuation">:</span>
  <span class="Identifier">name</span><span class="Punctuation">:</span> <span class="StringLit">&quot;buzz&quot;</span>
  <span class="Identifier">a</span><span class="Punctuation">:</span> <span class="DecNumber">11</span>
  <span class="Identifier">b</span><span class="Punctuation">:</span> <span class="DecNumber">22</span>

</pre></p>
<p>Will call <tt class="docutils literal"><span class="pre"><span class="Identifier">foo</span><span class="Punctuation">(</span><span class="Identifier">name</span><span class="Operator">=</span><span class="StringLit">&quot;buzz&quot;</span><span class="Punctuation">,</span><span class="Identifier">a</span><span class="Operator">=</span><span class="DecNumber">11</span><span class="Punctuation">,</span><span class="Identifier">b</span><span class="Operator">=</span><span class="DecNumber">22</span><span class="Punctuation">)</span></span></tt> and print:</p>
<p><pre class="listing">
buzz: a: 11 b: 22
</pre></p>

<h3><a class="toc-backref" id="macros-nimcdeclmacro" href="#macros-nimcdeclmacro"><tt class="docutils literal"><span class="pre"><span class="Identifier">cdeclmacro</span></span></tt></a></h3><p>Macro helper for wrapping a C macro that declares a new C variable.</p>
<p>It handles emitting the appropriate C code for calling the macro. Additionally it defines a new Nim variable using importc which imports the declared variable.</p>

<h4><a class="toc-backref" id="nimcdeclmacro-basic-example" href="#nimcdeclmacro-basic-example">Basic Example</a></h4><p><pre class="listing"><span class="Keyword">import</span> <span class="Identifier">cdecl</span><span class="Operator">/</span><span class="Identifier">cdecls</span>
<span class="Keyword">import</span> <span class="Identifier">cdecl</span><span class="Operator">/</span><span class="Identifier">cdeclapi</span>
<span class="Keyword">export</span> <span class="Identifier">cdeclapi</span> <span class="Comment"># this is needed clients to use the declared apis</span>

<span class="Keyword">proc</span> <span class="Identifier">CDefineVar</span><span class="Operator">*</span><span class="Punctuation">(</span><span class="Identifier">name</span><span class="Punctuation">:</span> <span class="Identifier">CToken</span><span class="Punctuation">,</span> <span class="Identifier">size</span><span class="Punctuation">:</span> <span class="Keyword">static</span><span class="Punctuation">[</span><span class="Identifier">int</span><span class="Punctuation">]</span><span class="Punctuation">)</span> <span class="Punctuation">{</span><span class="Operator">.</span>
  <span class="Identifier">cdeclmacro</span><span class="Punctuation">:</span> <span class="StringLit">&quot;C_MACRO_VARIABLE_DECLARER&quot;</span><span class="Punctuation">,</span> <span class="Identifier">cdeclsVar</span><span class="Punctuation">(</span><span class="Identifier">name</span> <span class="Operator">-&gt;</span> <span class="Identifier">array</span><span class="Punctuation">[</span><span class="Identifier">size</span><span class="Punctuation">,</span> <span class="Identifier">int32</span><span class="Punctuation">]</span><span class="Punctuation">)</span><span class="Operator">.</span><span class="Punctuation">}</span>

<span class="Identifier">CMacroDeclare</span><span class="Punctuation">(</span><span class="Identifier">myVar</span><span class="Punctuation">,</span> <span class="DecNumber">128</span><span class="Punctuation">,</span> <span class="Identifier">someExternalCVariable</span><span class="Punctuation">)</span> <span class="Comment"># creates myVar</span>
</pre></p>
<p><pre class="listing"><span class="Keyword">macro</span> <span class="Identifier">cdeclmacro</span><span class="Punctuation">(</span><span class="Identifier">name</span><span class="Punctuation">:</span> <span class="Identifier">string</span><span class="Punctuation">;</span> <span class="Identifier">def</span><span class="Punctuation">:</span> <span class="Identifier">untyped</span><span class="Punctuation">)</span>
</pre></p>

<h4><a class="toc-backref" id="nimcdeclmacro-crawstr-example" href="#nimcdeclmacro-crawstr-example">CRawStr Example</a></h4><p><pre class="listing"><span class="Keyword">import</span> <span class="Identifier">macros</span>
<span class="Keyword">import</span> <span class="Identifier">cdecl</span>

<span class="Keyword">proc</span> <span class="Identifier">CDefineVarStackRaw</span><span class="Operator">*</span><span class="Punctuation">(</span><span class="Identifier">name</span><span class="Punctuation">:</span> <span class="Identifier">CToken</span><span class="Punctuation">,</span> <span class="Identifier">size</span><span class="Punctuation">:</span> <span class="Keyword">static</span><span class="Punctuation">[</span><span class="Identifier">int</span><span class="Punctuation">]</span><span class="Punctuation">,</span> <span class="Identifier">otherRaw</span><span class="Punctuation">:</span> <span class="Identifier">CRawStr</span><span class="Punctuation">)</span><span class="Punctuation">:</span> <span class="Identifier">array</span><span class="Punctuation">[</span><span class="Identifier">size</span><span class="Punctuation">,</span> <span class="Identifier">int32</span><span class="Punctuation">]</span> <span class="Punctuation">{</span><span class="Operator">.</span>
  <span class="Identifier">cdeclmacro</span><span class="Punctuation">:</span> <span class="StringLit">&quot;C_DEFINE_VAR_ADDITION&quot;</span><span class="Operator">.</span><span class="Punctuation">}</span>

<span class="Comment"># Pass a raw string to the C macro:</span>
<span class="Keyword">proc</span> <span class="Identifier">runCDefineVarStackRaw</span><span class="Punctuation">(</span><span class="Punctuation">)</span> <span class="Operator">=</span>
  <span class="Identifier">CDefineVarStackRaw</span><span class="Punctuation">(</span><span class="Identifier">myVarStackRaw</span><span class="Punctuation">,</span> <span class="DecNumber">5</span><span class="Punctuation">,</span> <span class="Identifier">CRawStr</span><span class="Punctuation">(</span><span class="StringLit">&quot;40+2&quot;</span><span class="Punctuation">)</span><span class="Punctuation">)</span>
  <span class="Identifier">assert</span> <span class="Identifier">myVarStackRaw</span><span class="Punctuation">[</span><span class="DecNumber">0</span><span class="Punctuation">]</span> <span class="Operator">==</span> <span class="DecNumber">42</span>
</pre> </p>
## **macro** cdeclmacro

<p>Macro helper for wrapping a C macro that declares a new C variable.</p>
<p>It handles emitting the appropriate C code for calling the macro.</p>
<p>It can define Nim variables using importc to wrap the generated variable. This is done using <tt class="docutils literal"><span class="pre"><span class="Identifier">varName</span><span class="Punctuation">:</span> <span class="Identifier">CToken</span></span></tt> in the argument list and adding a <tt class="docutils literal"><span class="pre"><span class="Identifier">cdeclsVar</span><span class="Punctuation">(</span><span class="Identifier">varName</span> <span class="Operator">-></span> <span class="Identifier">varType</span><span class="Punctuation">)</span></span></tt> pragma. The <tt class="docutils literal"><span class="pre"><span class="Identifier">cdeclsVar</span></span></tt> tells the macro which CToken argument to use and its type.</p>
<p>The macro will pass any extra pragmas to the variable. If the <tt class="docutils literal"><span class="pre"><span class="Identifier">global</span></span></tt> pragma is passed in the emitted C code will be put in the <tt class="docutils literal"><span class="pre"><span class="Operator">/*</span><span class="Identifier">VARSECTION</span><span class="Operator">*/</span></span></tt> section. </p>

```nim
macro cdeclmacro(name: string; def: untyped)
```

## **macro** cmacrowrapper

pragma for making a c macro wrapper

```nim
macro cmacrowrapper(name: string; def: untyped)
```
## **type** CRawStr

Represents a raw string that gets interpolated into generated C ouput

```nim
CRawStr = distinct string
```

## **type** CLabel

used to represent a C macro "label", an alias for CRawStr

```nim
CLabel = CRawStr
```

## **type** CRawToken

Represents a C token derived from a Nim expression

```nim
CRawToken = distinct static[CRawStr]
```

## **type** CToken

Represents a C token derived from a Nim expression

```nim
CToken = distinct static[CRawStr]
```

## **macro** symbolName

Get a string representation of a Nim symbol

```nim
macro symbolName(x: untyped): string
```

## **template** symbolVal

Turns a CRawStr into a normal string

```nim
template symbolVal(x: CRawStr): string
```

## **template** symbolVal

Turns a CRawStr into a normal string

```nim
template symbolVal(x: string): string
```
## **macro** unpackObjectArgs

<p>Calls <tt class="docutils literal"><span class="pre"><span class="Identifier">callee</span></span></tt> with fields form object <tt class="docutils literal"><span class="pre"><span class="Identifier">args</span></span></tt> unpacked as individual arguments.</p>
<p>This is similar to <tt class="docutils literal"><span class="pre"><span class="Identifier">unpackVarargs</span></span></tt> in <tt class="docutils literal"><span class="pre"><span class="Identifier">std</span><span class="Operator">/</span><span class="Identifier">macros</span></span></tt> but for call a function using the values from an object</p>

```nim
macro unpackObjectArgs(callee: untyped; arg: typed; extras: varargs[untyped]): untyped
```

## **macro** unpackObjectArgFields

Similar to <tt class="docutils literal"><span class="pre"><span class="Identifier">unpackObjectArgs</span></span></tt> but with named parameters based on field names.

```nim
macro unpackObjectArgFields(callee: untyped; arg: typed;
 extras: varargs[untyped]): untyped
```

## **macro** unpackLabelsAsArgs

unpacks labels as named arguments.

```nim
macro unpackLabelsAsArgs(callee: typed; args: varargs[untyped]): untyped
```
## **macro** bitfields

Create a new distinct integer type with accessors for <tt class="docutils literal"><span class="pre"><span class="Identifier">bitfields</span></span></tt> that set and get bits for each field. This is more stable than C-style bitfields (see below).<dl class="docutils"><dt>The basic syntax for a <tt class="docutils literal"><span class="pre"><span class="Identifier">bitfield</span></span></tt> declarations is:</dt>
<dd><tt class="docutils literal"><span class="pre"><span class="Identifier">fieldname</span><span class="Punctuation">:</span> <span class="Identifier">uint8</span><span class="Punctuation">[</span><span class="FloatNumber">4.</span><span class="Operator">.</span><span class="DecNumber">5</span><span class="Punctuation">]</span></span></tt></dd>
<dt>- <tt class="docutils literal"><span class="pre"><span class="Identifier">fieldName</span></span></tt> is the name of the accessors and produces both</dt>
<dd>a getter (<tt class="docutils literal"><span class="pre"><span class="Identifier">fieldName</span></span></tt>) and setter (<tt class="docutils literal"><span class="pre"><span class="Identifier">fieldName</span><span class="Operator">=</span></span></tt>)</dd>
<dt>- the range <tt class="docutils literal"><span class="pre"><span class="FloatNumber">4.</span><span class="Operator">.</span><span class="DecNumber">5</span></span></tt> is the target bit indexes. The ranges are</dt>
<dd>inclusive meaning <tt class="docutils literal"><span class="pre"><span class="DecNumber">6</span> <span class="Operator">...</span> <span class="DecNumber">6</span></span></tt> is 1 bit. Ranges are sorted so you can also use <tt class="docutils literal"><span class="pre"><span class="DecNumber">5</span> <span class="Operator">..</span> <span class="DecNumber">4</span></span></tt> to match hardware documentation.</dd>
</dl>

 * The type <tt class="docutils literal"><span class="pre"><span class="Identifier">uint8</span></span></tt> is the type that the bits are converted to/from.

<p>Signed types like <tt class="docutils literal"><span class="pre"><span class="Identifier">int8</span></span></tt> are supported and do signed shifts to</p>
<dl class="docutils"><dt>properly extend the sign. For example:</dt>
<dd><tt class="docutils literal"><span class="pre"><span class="Identifier">speed</span><span class="Punctuation">:</span> <span class="Identifier">int8</span><span class="Punctuation">[</span><span class="FloatNumber">7.</span><span class="Operator">.</span><span class="DecNumber">4</span><span class="Punctuation">]</span></span></tt></dd>
</dl>
<p>The accessors generated are very simple and what you would generally produce by hand. For example:</p>
<blockquote><p><pre class="listing"><span class="Identifier">bitfields</span> <span class="Identifier">RegConfig</span><span class="Punctuation">(</span><span class="Identifier">uint16</span><span class="Punctuation">)</span><span class="Punctuation">:</span>
    <span class="Identifier">speed</span><span class="Punctuation">:</span> <span class="Identifier">int8</span><span class="Punctuation">[</span><span class="FloatNumber">4.</span><span class="Operator">.</span><span class="DecNumber">2</span><span class="Punctuation">]</span>
  </pre></p></blockquote>
<dl class="docutils"><dt>Generates code similar too:</dt>
<dd><pre class="listing"><span class="Keyword">type</span>
    <span class="Identifier">RegChannel</span> <span class="Operator">=</span> <span class="Keyword">distinct</span> <span class="Identifier">uint16</span>
  
  <span class="Keyword">proc</span> <span class="Identifier">speed</span><span class="Operator">*</span><span class="Punctuation">(</span><span class="Identifier">reg</span><span class="Punctuation">:</span> <span class="Identifier">RegChannel</span><span class="Punctuation">)</span><span class="Punctuation">:</span> <span class="Identifier">uint8</span> <span class="Operator">=</span>
      <span class="Identifier">result</span> <span class="Operator">=</span> <span class="Identifier">uint8</span><span class="Punctuation">(</span><span class="Identifier">bitsliced</span><span class="Punctuation">(</span><span class="Identifier">uint16</span><span class="Punctuation">(</span><span class="Identifier">reg</span><span class="Punctuation">)</span><span class="Punctuation">,</span> <span class="DecNumber">4</span> <span class="Operator">..</span> <span class="DecNumber">9</span><span class="Punctuation">)</span><span class="Punctuation">)</span>
  <span class="Keyword">proc</span> <span class="Identifier">speed</span><span class="Operator">=*</span><span class="Punctuation">(</span><span class="Identifier">reg</span><span class="Punctuation">:</span> <span class="Keyword">var</span> <span class="Identifier">RegChannel</span><span class="Punctuation">;</span> <span class="Identifier">x</span><span class="Punctuation">:</span> <span class="Identifier">uint8</span><span class="Punctuation">)</span> <span class="Operator">=</span>
      <span class="Identifier">setBitsSlice</span><span class="Punctuation">(</span><span class="Identifier">uint16</span><span class="Punctuation">(</span><span class="Identifier">reg</span><span class="Punctuation">)</span><span class="Punctuation">,</span> <span class="DecNumber">4</span> <span class="Operator">..</span> <span class="DecNumber">9</span><span class="Punctuation">,</span> <span class="Identifier">x</span><span class="Punctuation">)</span>
  </pre></dd>
</dl>
<p>This is often preferable to C-style bitfields which Nim does support. C-style bitfields are compiler and architecture dependent and prone to breaking on field alignement, endiannes, and other issues. See <a class="reference external" href="https://lwn.net/Articles/478657/">https://lwn.net/Articles/478657/</a> </p>

```nim
macro bitfields(name, def: untyped)
```
