

<div class="document" id="documentId">
  <div class="container">
    <h1 class="title">src/cdecl</h1>
    <div class="row">
  <div class="three columns">
  <div class="theme-switch-wrapper">
    <label class="theme-switch" for="checkbox">
      <input type="checkbox" id="checkbox" />
      <div class="slider round"></div>
    </label>
    &nbsp;&nbsp;&nbsp; <em>Dark Mode</em>
  </div>
  <div id="global-links">
    <ul class="simple">
    <li>
      <a href="theindex.html">Index</a>
    </li>
    </ul>
  </div>
  <div id="searchInputDiv">
    Search: <input type="text" id="searchInput"
      onkeyup="search()" />
  </div>
  <div>
    Group by:
    <select onchange="groupBy(this.value)">
      <option value="section">Section</option>
      <option value="type">Type</option>
    </select>
  </div>
  <ul class="simple simple-toc" id="toc-list">
<li>
  <a class="reference reference-toplevel" href="#7" id="57">Types</a>
  <ul class="simple simple-toc-section">
      <li><a class="reference" href="#CToken"
    title="CToken = static[string]">CToken</a></li>

  </ul>
</li>
<li>
  <a class="reference reference-toplevel" href="#17" id="67">Macros</a>
  <ul class="simple simple-toc-section">
      <ul class="simple nested-toc-section">cdeclmacro
      <li><a class="reference" href="#cdeclmacro.m%2Cstring%2Cuntyped"
    title="cdeclmacro(name: string; def: untyped)">cdeclmacro(name: string; def: untyped)</a></li>

  </ul>
  <ul class="simple nested-toc-section">symbolName
      <li><a class="reference" href="#symbolName.m%2Ctyped"
    title="symbolName(x: typed): string">symbolName(x: typed): string</a></li>

  </ul>

  </ul>
</li>
<li>
  <a class="reference reference-toplevel" href="#18" id="68">Templates</a>
  <ul class="simple simple-toc-section">
      <ul class="simple nested-toc-section">cname
      <li><a class="reference" href="#cname.t%2Cuntyped"
    title="cname(name: untyped): CToken">cname(name: untyped): CToken</a></li>

  </ul>

  </ul>
</li>

</ul>

  </div>
  
  <div class="nine columns" id="content">
  <div id="tocRoot"></div>
  
  <p class="module-desc"></p>
  <div class="section" id="7">
<h1><a class="toc-backref" href="#7">Types</a></h1>
<dl class="item">
<div id="CToken">
<dt><pre><a href="cdecl.html#CToken"><span class="Identifier">CToken</span></a> <span class="Other">=</span> <span class="Identifier">static</span><span class="Other">[</span><span class="Identifier">string</span><span class="Other">]</span></pre></dt>
<dd>



</dd>
</div>

</dl></div>
<div class="section" id="17">
<h1><a class="toc-backref" href="#17">Macros</a></h1>
<dl class="item">
<div id="cdeclmacro.m,string,untyped">
<dt><pre><span class="Keyword">macro</span> <a href="#cdeclmacro.m%2Cstring%2Cuntyped"><span class="Identifier">cdeclmacro</span></a><span class="Other">(</span><span class="Identifier">name</span><span class="Other">:</span> <span class="Identifier">string</span><span class="Other">;</span> <span class="Identifier">def</span><span class="Other">:</span> <span class="Identifier">untyped</span><span class="Other">)</span></pre></dt>
<dd>

Macro helper for wrapping a C macro that declares a new C variable. It handles emitting the appropriate C code for calling the macro. Additionally it defines a new Nim variable using importc which imports the declared variable.   
<p><strong class="examples_text">Example:</strong></p>
<pre class="listing"><span class="Punctuation">{</span><span class="Operator">.</span><span class="Identifier">emit</span><span class="Punctuation">:</span> <span class="LongStringLit">&quot;&quot;&quot;/*TYPESECTION*/
    /* define example C Macro for testing */
    #define C_DEFINE_VAR(NM, SZ) int NM[SZ]
    #define C_DEFINE_VAR_DUO(NM, SZ, NM2) int NM[SZ]
    &quot;&quot;&quot;</span><span class="Operator">.</span><span class="Punctuation">}</span>

<span class="Keyword">proc</span> <span class="Identifier">CDefineVar</span><span class="Operator">*</span><span class="Punctuation">(</span><span class="Identifier">name</span><span class="Punctuation">:</span> <span class="Identifier">CToken</span><span class="Punctuation">,</span> <span class="Identifier">size</span><span class="Punctuation">:</span> <span class="Keyword">static</span><span class="Punctuation">[</span><span class="Identifier">int</span><span class="Punctuation">]</span><span class="Punctuation">)</span><span class="Punctuation">:</span> <span class="Identifier">array</span><span class="Punctuation">[</span><span class="Identifier">size</span><span class="Punctuation">,</span> <span class="Identifier">int</span><span class="Punctuation">]</span> <span class="Punctuation">{</span><span class="Operator">.</span>
  <span class="Identifier">cdeclmacro</span><span class="Punctuation">:</span> <span class="StringLit">&quot;C_DEFINE_VAR&quot;</span><span class="Operator">.</span><span class="Punctuation">}</span></pre>

</dd>
</div>
<div id="symbolName.m,typed">
<dt><pre><span class="Keyword">macro</span> <a href="#symbolName.m%2Ctyped"><span class="Identifier">symbolName</span></a><span class="Other">(</span><span class="Identifier">x</span><span class="Other">:</span> <span class="Identifier">typed</span><span class="Other">)</span><span class="Other">:</span> <span class="Identifier">string</span></pre></dt>
<dd>



</dd>
</div>

</dl></div>
<div class="section" id="18">
<h1><a class="toc-backref" href="#18">Templates</a></h1>
<dl class="item">
<div id="cname.t,untyped">
<dt><pre><span class="Keyword">template</span> <a href="#cname.t%2Cuntyped"><span class="Identifier">cname</span></a><span class="Other">(</span><span class="Identifier">name</span><span class="Other">:</span> <span class="Identifier">untyped</span><span class="Other">)</span><span class="Other">:</span> <a href="cdecl.html#CToken"><span class="Identifier">CToken</span></a></pre></dt>
<dd>



</dd>
</div>

</dl></div>

  </div>
</div>

    <div class="row">
      <div class="twelve-columns footer">
        <span class="nim-sprite"></span>
        <br/>
        <small style="color: var(--hint);">Made with Nim. Generated: 2022-06-05 21:57:49 UTC</small>
      </div>
    </div>
  </div>
</div>

